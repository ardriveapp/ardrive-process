-- balances.lua
Balances = Balances or {}

-- Utility functions that modify global Balance object
local balances = {}
local utils = require("utils")

--- @alias mARDRIVE number

--- Transfers tokens from one address to another
---@param recipient string The address to receive tokens
---@param from string The address sending tokens
---@param qty number The amount of tokens to transfer (must be integer)
---@param allowUnsafeAddresses boolean Whether to allow unsafe addresses
---@return table Updated balances for sender and recipient addresses
function balances.transfer(recipient, from, qty, allowUnsafeAddresses)
	assert(type(recipient) == "string", "Recipient is required!")
	assert(type(from) == "string", "From is required!")
	assert(from ~= recipient, "Cannot transfer to self")
	assert(utils.isValidAddress(recipient, allowUnsafeAddresses), "Invalid recipient")
	assert(type(qty) == "number", "Quantity is required and must be a number!")
	assert(recipient ~= from, "Cannot transfer to self")
	assert(utils.isInteger(qty), "Quantity must be an integer: " .. qty)
	assert(qty > 0, "Quantity must be greater than 0")

	balances.reduceBalance(from, qty)
	balances.increaseBalance(recipient, qty)

	return {
		[from] = Balances[from],
		[recipient] = Balances[recipient],
	}
end

--- Mints tokens to an address
---@param recipient string The address to receive tokens
---@param qty number The amount of tokens to transfer (must be integer)
---@param allowUnsafeAddresses boolean Whether to allow unsafe addresses
---@return table Updated balance for recipient
function balances.mint(recipient, qty, allowUnsafeAddresses)
	assert(type(recipient) == "string", "Recipient is required!")
	assert(utils.isValidAddress(recipient, allowUnsafeAddresses), "Invalid recipient")
	assert(type(qty) == "number", "Quantity is required and must be a number!")
	assert(utils.isInteger(qty), "Quantity must be an integer: " .. qty)
	assert(qty > 0, "Quantity must be greater than 0")

	balances.increaseBalance(recipient, qty)

	return {
		[recipient] = Balances[recipient],
	}
end

--- Burns tokens from an address
---@param from string The address sending tokens
---@param qty number The amount of tokens to transfer (must be integer)
---@return table Updated balances for sender and recipient addresses
function balances.burn(from, qty)
	assert(type(from) == "string", "From is required!")
	assert(type(qty) == "number", "Quantity is required and must be a number!")
	assert(utils.isInteger(qty), "Quantity must be an integer: " .. qty)
	assert(qty > 0, "Quantity must be greater than 0")

	balances.reduceBalance(from, qty)

	return {
		[from] = Balances[from],
	}
end

--- Gets the balance for a specific address
---@param target string The address to get balance for
---@return number The balance amount (0 if address has no balance)
function balances.getBalance(target)
	return Balances[target] or 0
end

--- Gets all balances in the system
---@return table All address:balance pairs
function balances.getBalances()
	return utils.deepCopy(Balances) or {}
end

--- Reduces the balance of an address
---@param target string The address to reduce balance for
---@param qty number The amount to reduce by (must be integer)
---@throws error If target has insufficient balance
function balances.reduceBalance(target, qty)
	assert(balances.walletHasSufficientBalance(target, qty), "Insufficient balance")
	assert(qty > 0, "Quantity must be greater than 0")

	local prevBalance = balances.getBalance(target)
	Balances[target] = prevBalance - qty
end

--- Increases the balance of an address
--- @param target string The address to increase balance for
--- @param qty number The amount to increase by (must be integer)
function balances.increaseBalance(target, qty)
	assert(utils.isInteger(qty), "Quantity must be an integer: " .. qty)
	local prevBalance = balances.getBalance(target) or 0
	Balances[target] = prevBalance + qty
end

--- Gets paginated list of all balances
--- @param cursor string|nil The address to start from
--- @param limit number Max number of results to return
--- @param sortBy string|nil Field to sort by
--- @param sortOrder string "asc" or "desc" sort direction
--- @return table Array of {address, balance} objects
function balances.getPaginatedBalances(cursor, limit, sortBy, sortOrder)
	local allBalances = balances.getBalances()
	local balancesArray = {}
	local cursorField = "address" -- the cursor will be the wallet address
	for address, balance in pairs(allBalances) do
		table.insert(balancesArray, {
			address = address,
			balance = balance,
		})
	end

	return utils.paginateTableWithCursor(balancesArray, cursor, cursorField, limit, sortBy, sortOrder)
end

--- Checks if a wallet has a sufficient balance
--- @param wallet string The address of the wallet
--- @param quantity number The amount to check against the balance
--- @return boolean True if the wallet has a sufficient balance, false otherwise
function balances.walletHasSufficientBalance(wallet, quantity)
	return Balances[wallet] ~= nil and Balances[wallet] >= quantity
end

return balances
