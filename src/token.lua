local token = {}
local constants = require("constants")
local balances = require("balances")

TotalSupply = TotalSupply or constants.totalTokenSupply
LastKnownCirculatingSupply = LastKnownCirculatingSupply or 0 -- total circulating supply (e.g. balances - protocol balance)

--- @return mARDRIVE # returns the last computed total supply, this is to avoid recomputing the total supply every time, and only when requested
function token.lastKnownTotalTokenSupply()
	return LastKnownCirculatingSupply
end

--- @class TotalSupplyDetails
--- @field totalSupply number
--- @field circulatingSupply number

--- Crawls the state to compute the total supply and update the last known values
--- @return TotalSupplyDetails
function token.computeTotalSupply()
	-- add all the balances
	local totalSupply = 0
	local circulatingSupply = 0
	local userBalances = balances.getBalances()

	-- tally circulating supply
	for _, balance in pairs(userBalances) do
		circulatingSupply = circulatingSupply + balance
	end
	totalSupply = totalSupply + circulatingSupply

	LastKnownCirculatingSupply = circulatingSupply
	TotalSupply = totalSupply
	return {
		totalSupply = totalSupply,
		circulatingSupply = circulatingSupply,
	}
end

return token
