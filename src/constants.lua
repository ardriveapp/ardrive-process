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

-- Vaulting constants
constants.MIN_TOKEN_LOCK_TIME_MS = 14 * 24 * 60 * 60 * 1000 -- 14 days in milliseconds
constants.MAX_TOKEN_LOCK_TIME_MS = 200 * 365 * 24 * 60 * 60 * 1000 -- 200 years in milliseconds
constants.MIN_VAULT_SIZE = constants.ARDRIVEToMARDRIVE(100) -- 100 ARDRIVE minimum to prevent state bloat

return constants
