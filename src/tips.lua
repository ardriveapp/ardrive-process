local tips = {}
local constants = require("constants")
local utils = require("utils")
local balances = require("balances")
local crypto = require("crypto.init")

--- Calculate stake weight for an address including vaulted tokens with duration multiplier
--- @param address string The address to calculate weight for
--- @param currentTimestamp number The current timestamp
--- @return number The total stake weight
function tips.calculateStakeWeight(address, currentTimestamp)
	local weight = Balances[address] or 0
	
	if Vaults[address] then
		for _, vault in pairs(Vaults[address]) do
			-- Only count active vaults (not expired)
			if vault.endTimestamp > currentTimestamp then
				local vaultDuration = vault.endTimestamp - vault.startTimestamp
				local daysLocked = vaultDuration / (24 * 60 * 60 * 1000)
				
				-- Linear scaling: 1.0x at 14 days → 3.0x at 365+ days
				-- Formula: multiplier = 1.0 + ((days - 14) / 351) * 2.0
				-- Capped at 3.0x
				local multiplier = math.min(3.0, 1.0 + ((daysLocked - 14) / 351) * 2.0)
				weight = weight + math.floor(vault.balance * multiplier)
			end
		end
	end
	
	return weight
end

--- Get total stake weight of the network excluding a specific address
--- @param excludeAddress string|nil The address to exclude from calculation
--- @param currentTimestamp number The current timestamp
--- @return number The total network stake weight
function tips.getTotalStakeWeight(excludeAddress, currentTimestamp)
	local totalWeight = 0
	
	-- Calculate weight for all balance holders
	for address, _ in pairs(Balances) do
		if address ~= excludeAddress then
			totalWeight = totalWeight + tips.calculateStakeWeight(address, currentTimestamp)
		end
	end
	
	-- Also check vaults for addresses that might not have liquid balance
	for address, _ in pairs(Vaults or {}) do
		if address ~= excludeAddress and not Balances[address] then
			totalWeight = totalWeight + tips.calculateStakeWeight(address, currentTimestamp)
		end
	end
	
	return totalWeight
end

--- Calculate suggested tip amount (15% of transfer)
--- @param transferAmount number The base transfer amount
--- @return number The suggested tip amount
function tips.calculateSuggestedTip(transferAmount)
	return math.floor(transferAmount * 0.15)
end

--- Select a weighted random recipient for the tip
--- @param excludeAddress string The address to exclude (sender)
--- @param currentTimestamp number The current timestamp
--- @param msgId string The message ID for deterministic randomness
--- @return string The selected recipient address
function tips.selectWeightedRecipient(excludeAddress, currentTimestamp, msgId)
	local eligibleHolders = {}
	local totalWeight = 0
	
	-- Build weight table for all holders except sender
	for address, _ in pairs(Balances) do
		if address ~= excludeAddress then
			local weight = tips.calculateStakeWeight(address, currentTimestamp)
			if weight > 0 then
				table.insert(eligibleHolders, {address = address, weight = weight})
				totalWeight = totalWeight + weight
			end
		end
	end
	
	-- Check vaults for addresses without liquid balance
	for address, _ in pairs(Vaults or {}) do
		if address ~= excludeAddress and not Balances[address] then
			local weight = tips.calculateStakeWeight(address, currentTimestamp)
			if weight > 0 then
				table.insert(eligibleHolders, {address = address, weight = weight})
				totalWeight = totalWeight + weight
			end
		end
	end
	
	-- No eligible recipients
	if totalWeight == 0 then
		error("No eligible tip recipients. Network requires active stakeholders.")
	end
	
	-- Deterministic random using msgId as seed with ISAAC RNG
	-- Following the same pattern as epochs.lua for prescribed observers
	local msgIdHash = utils.getHashFromBase64URL(msgId)
	local hashString = crypto.utils.array.toString(msgIdHash)
	local randomValue = crypto.random(nil, nil, hashString) % totalWeight
	
	-- Select recipient based on weighted probability
	local cumulative = 0
	for _, holder in ipairs(eligibleHolders) do
		cumulative = cumulative + holder.weight
		if randomValue < cumulative then
			return holder.address
		end
	end
	
	-- Fallback (should never reach here)
	return eligibleHolders[#eligibleHolders].address
end

--- Validate transfer with tip parameters
--- @param transferAmount number The base transfer amount
--- @param tipAmount number The tip amount
function tips.validateTransferWithTip(transferAmount, tipAmount)
	local minTransfer = constants.ARDRIVEToMARDRIVE(100) -- 100 ARDRIVE minimum
	
	if transferAmount < minTransfer then
		error("Transfer amount must be at least 100 ARDRIVE")
	end
	
	if tipAmount <= 0 then
		error("Tip amount must be positive")
	end
end

--- Process a transfer with tip transaction
--- @param params table Transaction parameters
--- @return table Result with transfer details
function tips.processTransferWithTip(params)
	local from = params.from
	local recipient = params.recipient
	local quantity = params.quantity
	local tipAmount = params.tipAmount or tips.calculateSuggestedTip(quantity)
	local currentTimestamp = params.currentTimestamp
	local msgId = params.msgId
	
	-- Validate inputs
	assert(from ~= recipient, "Cannot transfer to self")
	tips.validateTransferWithTip(quantity, tipAmount)
	
	-- Check sufficient balance for transfer + tip
	local totalRequired = quantity + tipAmount
	if not balances.walletHasSufficientBalance(from, totalRequired) then
		error("Insufficient balance for transfer and tip")
	end
	
	-- Select tip recipient
	local tipRecipient = tips.selectWeightedRecipient(from, currentTimestamp, msgId)
	local tipWeight = tips.calculateStakeWeight(tipRecipient, currentTimestamp)
	local totalNetworkWeight = tips.getTotalStakeWeight(from, currentTimestamp)
	
	-- Execute transfers atomically
	-- First the main transfer
	balances.transfer(recipient, from, quantity, false)
	
	-- Then the tip
	balances.transfer(tipRecipient, from, tipAmount, false)
	
	return {
		from = from,
		recipient = recipient,
		transferAmount = quantity,
		tipAmount = tipAmount,
		tipRecipient = tipRecipient,
		tipWeight = tipWeight,
		totalNetworkWeight = totalNetworkWeight,
	}
end

return tips