-- Adjust package.path to include the current directory
local token = require("token")
local constants = require("constants")
local ARDRIVEEvent = require("ardrive_event")

Name = Name or "Testnet ARDRIVE"
Ticker = Ticker or "tARDRIVE"
Logo = Logo or "qUjrTmHdVjXX4D6rU6Fik02bUOzWkOR6oOqUg39g4-s"
Denomination = 6
Owner = Owner or ao.env.Process.Owner
Balances = Balances or {}
if not Balances[Owner] then -- initialize the balance for the process id
	Balances = {
		[Owner] = constants.totalTokenSupply, -- 10M ARDRIVE
	}
end
LastKnownMessageTimestamp = LastKnownMessageTimestamp or 0
LastKnownMessageId = LastKnownMessageId or ""

local utils = require("utils")
local json = require("json")
local ao = ao or require("ao")
local balances = require("balances")

-- handlers that are critical should discard the memory on error (see prune for an example)
local CRITICAL = true

local ActionMap = {
	Info = "Info",
	TotalSupply = "Total-Supply",
	Transfer = "Transfer",
	Balance = "Balance",
	Balances = "Balances",
	PaginatedBalances = "Paginated-Balances",
	Mint = "Mint",
	Burn = "Burn",
}

--- @param msg ParsedMessage
--- @param response any
local function Send(msg, response)
	if msg.reply then
		--- Reference: https://github.com/permaweb/aos/blob/main/blueprints/patch-legacy-reply.lua
		msg.reply(response)
	else
		ao.send(response)
	end
end

local function eventingPcall(ioEvent, onError, fnToCall, ...)
	local status, result = pcall(fnToCall, ...)
	if not status then
		onError(result)
		ioEvent:addField("Error", result)
		return status, result
	end
	return status, result
end

-- Sanitize inputs before every interaction
local function assertAndSanitizeInputs(msg)
	assert(
		-- TODO: replace this with LastKnownMessageTimestamp after node release 23.0.0
		msg.Timestamp and tonumber(msg.Timestamp) >= 0,
		"Timestamp must be greater than or equal to the last known message timestamp of "
			.. LastKnownMessageTimestamp
			.. " but was "
			.. msg.Timestamp
	)
	assert(msg.From, "From is required")
	assert(msg.Tags and type(msg.Tags) == "table", "Tags are required")

	msg.Tags = utils.validateAndSanitizeInputs(msg.Tags)
	msg.From = utils.formatAddress(msg.From)
	msg.Timestamp = msg.Timestamp and tonumber(msg.Timestamp) -- Timestamp should always be provided by the CU
end

local function updateLastKnownMessage(msg)
	if msg.Timestamp >= LastKnownMessageTimestamp then
		LastKnownMessageTimestamp = msg.Timestamp
		LastKnownMessageId = msg.Id
	end
end

--- @class ParsedMessage
--- @field Id string
--- @field Action string
--- @field From string
--- @field Timestamp Timestamp
--- @field Tags table<string, any>
--- @field ioEvent ARDRIVEEvent
--- @field Cast boolean?
--- @field reply? fun(response: any)

--- @param handlerName string
--- @param pattern fun(msg: ParsedMessage):'continue'|boolean
--- @param handleFn fun(msg: ParsedMessage)
--- @param critical boolean?
--- @param printEvent boolean?
local function addEventingHandler(handlerName, pattern, handleFn, critical, printEvent)
	critical = critical or false
	printEvent = printEvent == nil and true or printEvent
	Handlers.add(handlerName, pattern, function(msg)
		-- add an ARDRIVEEvent to the message if it doesn't exist
		msg.ioEvent = msg.ioEvent or ARDRIVEEvent(msg)
		-- global handler for all eventing errors, so we can log them and send a notice to the sender for non critical errors and discard the memory on critical errors
		local status, resultOrError = eventingPcall(msg.ioEvent, function(error)
			--- non critical errors will send an invalid notice back to the caller with the error information, memory is not discarded
			Send(msg, {
				Target = msg.From,
				Action = "Invalid-" .. utils.toTrainCase(handlerName) .. "-Notice",
				Error = tostring(error),
				Data = tostring(error),
			})
		end, handleFn, msg)
		if not status and critical then
			local errorEvent = ARDRIVEEvent(msg)
			-- For critical handlers we want to make sure the event data gets sent to the CU for processing, but that the memory is discarded on failures
			-- These handlers (distribute, prune) severely modify global state, and partial updates are dangerous.
			-- So we json encode the error and the event data and then throw, so the CU will discard the memory and still process the event data.
			-- An alternative approach is to modify the implementation of ao.result - to also return the Output on error.
			-- Reference: https://github.com/permaweb/ao/blob/76a618722b201430a372894b3e2753ac01e63d3d/dev-cli/src/starters/lua/ao.lua#L284-L287
			local errorWithEvent = tostring(resultOrError) .. "\n" .. errorEvent:toJSON()
			error(errorWithEvent, 0) -- 0 ensures not to include this line number in the error message
		end
		if printEvent then
			msg.ioEvent:printEvent()
		end
	end)
end

addEventingHandler("sanitize", function()
	return "continue"
end, function(msg)
	assertAndSanitizeInputs(msg)
	updateLastKnownMessage(msg)
end, CRITICAL, false)

addEventingHandler(ActionMap.Transfer, utils.hasMatchingTag("Action", ActionMap.Transfer), function(msg)
	-- assert recipient is a valid arweave address
	local recipient = msg.Tags.Recipient
	local quantity = msg.Tags.Quantity
	local allowUnsafeAddresses = msg.Tags["Allow-Unsafe-Addresses"] or false
	assert(utils.isValidAddress(recipient, allowUnsafeAddresses), "Invalid recipient")
	assert(quantity > 0 and utils.isInteger(quantity), "Invalid quantity. Must be integer greater than 0")
	assert(recipient ~= msg.From, "Cannot transfer to self")

	msg.ioEvent:addField("RecipientFormatted", recipient)

	local result = balances.transfer(recipient, msg.From, quantity, allowUnsafeAddresses)
	if result ~= nil then
		local senderNewBalance = result[msg.From]
		local recipientNewBalance = result[recipient]
		msg.ioEvent:addField("Sender-Previous-Balance", senderNewBalance + quantity)
		msg.ioEvent:addField("Sender-New-Balance", senderNewBalance)
		msg.ioEvent:addField("Recipient-Previous-Balance", recipientNewBalance - quantity)
		msg.ioEvent:addField("Recipient-New-Balance", recipientNewBalance)
	end

	-- Casting implies that the sender does not want a response - Reference: https://elixirforum.com/t/what-is-the-etymology-of-genserver-cast/33610/3
	if not msg.Cast then
		-- Debit-Notice message template, that is sent to the Sender of the transfer
		local debitNotice = {
			Target = msg.From,
			Action = "Debit-Notice",
			Recipient = recipient,
			Quantity = tostring(quantity),
			["Allow-Unsafe-Addresses"] = tostring(allowUnsafeAddresses),
			Data = "You transferred " .. msg.Tags.Quantity .. " to " .. recipient,
		}
		-- Credit-Notice message template, that is sent to the Recipient of the transfer
		local creditNotice = {
			Target = recipient,
			Action = "Credit-Notice",
			Sender = msg.From,
			Quantity = tostring(quantity),
			["Allow-Unsafe-Addresses"] = tostring(allowUnsafeAddresses),
			Data = "You received " .. msg.Tags.Quantity .. " from " .. msg.From,
		}

		-- Add forwarded tags to the credit and debit notice messages
		local didForwardTags = false
		for tagName, tagValue in pairs(msg) do
			-- Tags beginning with "X-" are forwarded
			if string.sub(tagName, 1, 2) == "X-" then
				debitNotice[tagName] = tagValue
				creditNotice[tagName] = tagValue
				didForwardTags = true
				msg.ioEvent:addField(tagName, tagValue)
			end
		end
		if didForwardTags then
			msg.ioEvent:addField("ForwardedTags", "true")
		end

		-- Send Debit-Notice and Credit-Notice
		Send(msg, debitNotice)
		Send(msg, creditNotice)
	end
end)

addEventingHandler(ActionMap.Mint, utils.hasMatchingTag("Action", ActionMap.Mint), function(msg)
	local recipient = msg.Tags.Recipient
	local quantity = msg.Tags.Quantity
	local allowUnsafeAddresses = msg.Tags["Allow-Unsafe-Addresses"] or false
	assert(utils.isValidAddress(recipient, allowUnsafeAddresses), "Invalid recipient")
	assert(quantity > 0 and utils.isInteger(quantity), "Invalid quantity. Must be integer greater than 0")
	assert(msg.From == ao.id or msg.From == Owner, "Only this process or Owner can mint.")

	msg.ioEvent:addField("RecipientFormatted", recipient)

	local result = balances.mint(recipient, quantity, allowUnsafeAddresses)
	if result ~= nil then
		local recipientNewBalance = result[recipient]
		msg.ioEvent:addField("Mint-Recipient-Previous-Balance", recipientNewBalance - quantity)
		msg.ioEvent:addField("Mint-Recipient-New-Balance", recipientNewBalance)
		local totalSupplyDetails = token.computeTotalSupply()
		msg.ioEvent:addField("Last-Known-Total-Token-Supply", totalSupplyDetails.totalSupply)
	end

	-- Credit-Notice message template, that is sent to the Recipient of the transfer
	local creditNotice = {
		Target = recipient,
		Action = "Credit-Notice",
		Sender = msg.From,
		Quantity = tostring(quantity),
		["Allow-Unsafe-Addresses"] = tostring(allowUnsafeAddresses),
		Data = "You received " .. msg.Tags.Quantity .. " minted by " .. msg.From,
	}

	local didForwardTags = false
	for tagName, tagValue in pairs(msg) do
		-- Tags beginning with "X-" are forwarded
		if string.sub(tagName, 1, 2) == "X-" then
			creditNotice[tagName] = tagValue
			didForwardTags = true
			msg.ioEvent:addField(tagName, tagValue)
		end
	end
	if didForwardTags then
		msg.ioEvent:addField("ForwardedTags", "true")
	end

	Send(msg, creditNotice)
end)

addEventingHandler(ActionMap.Burn, utils.hasMatchingTag("Action", ActionMap.Burn), function(msg)
	local quantity = msg.Tags.Quantity
	assert(quantity > 0 and utils.isInteger(quantity), "Invalid quantity. Must be integer greater than 0")

	local result = balances.burn(msg.From, quantity)
	if result ~= nil then
		local burnerNewBalance = result[msg.From]
		msg.ioEvent:addField("Burner-Previous-Balance", burnerNewBalance - quantity)
		msg.ioEvent:addField("Burner-New-Balance", burnerNewBalance)
		local totalSupplyDetails = token.computeTotalSupply()
		msg.ioEvent:addField("Last-Known-Total-Token-Supply", totalSupplyDetails.totalSupply)
	end

	local burnNotice = {
		Target = msg.From,
		Action = "Burn-Notice",
		Quantity = tostring(quantity),
		Data = "Successfully burned " .. msg.Tags.Quantity,
	}

	local didForwardTags = false
	for tagName, tagValue in pairs(msg) do
		-- Tags beginning with "X-" are forwarded
		if string.sub(tagName, 1, 2) == "X-" then
			burnNotice[tagName] = tagValue
			didForwardTags = true
			msg.ioEvent:addField(tagName, tagValue)
		end
	end
	if didForwardTags then
		msg.ioEvent:addField("ForwardedTags", "true")
	end

	Send(msg, burnNotice)
end)

addEventingHandler("totalSupply", utils.hasMatchingTag("Action", ActionMap.TotalSupply), function(msg)
	local totalSupplyDetails = token.computeTotalSupply()
	msg.ioEvent:addField("Last-Known-Total-Token-Supply", totalSupplyDetails.totalSupply)
	Send(msg, {
		Action = "Total-Supply",
		Data = tostring(totalSupplyDetails.totalSupply),
		Ticker = Ticker,
	})
end)

addEventingHandler(ActionMap.Info, utils.hasMatchingTag("Action", ActionMap.Info), function(msg)
	local handlers = Handlers.list
	local handlerNames = {}

	for _, handler in ipairs(handlers) do
		table.insert(handlerNames, handler.name)
	end

	Send(msg, {
		Target = msg.From,
		Action = "Info-Notice",
		Tags = {
			Name = Name,
			Ticker = Ticker,
			Logo = Logo,
			Owner = Owner,
			Denomination = tostring(Denomination),
			Handlers = json.encode(handlerNames),
		},
		Data = json.encode({
			Name = Name,
			Ticker = Ticker,
			Logo = Logo,
			Owner = Owner,
			Denomination = Denomination,
			Handlers = handlerNames,
		}),
	})
end)

addEventingHandler(ActionMap.Balance, utils.hasMatchingTag("Action", ActionMap.Balance), function(msg)
	local target = msg.Tags.Target or msg.Tags.Address or msg.Tags.Recipient or msg.From
	local balance = balances.getBalance(target)

	Send(msg, {
		Target = msg.From,
		Action = "Balance-Notice",
		Account = target,
		Data = tostring(balance),
		Balance = tostring(balance),
		Ticker = Ticker,
	})
end)

addEventingHandler(ActionMap.Balances, utils.hasMatchingTag("Action", ActionMap.Balances), function(msg)
	Send(msg, {
		Target = msg.From,
		Action = "Balances-Notice",
		Data = json.encode(Balances),
	})
end)

addEventingHandler("paginatedBalances", utils.hasMatchingTag("Action", "Paginated-Balances"), function(msg)
	local page = utils.parsePaginationTags(msg)
	local walletBalances =
		balances.getPaginatedBalances(page.cursor, page.limit, page.sortBy or "balance", page.sortOrder)
	Send(msg, { Target = msg.From, Action = "Balances-Notice", Data = json.encode(walletBalances) })
end)

Handlers.add("test", function()
	return "continue", function(msg)
		print(msg)
		msg.reply({
			Data = "Hello World",
		})
	end
end)
