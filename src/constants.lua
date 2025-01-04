local constants = {}
constants.totalTokenSupply = 10000000000000
constants.mARDRIVEPerARDRIVE = 1000000

--- @param ARDRIVE number
--- @return mARDRIVE
function constants.ARDRIVEToMARDRIVE(ARDRIVE)
	return ARDRIVE * constants.mARDRIVEPerARDRIVE
end

-- General
constants.MIN_UNSAFE_ADDRESS_LENGTH = 1
constants.MAX_UNSAFE_ADDRESS_LENGTH = 128

return constants
