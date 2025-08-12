local tips = require("tips")
local constants = require("constants")

local testAddress1 = "test-this-is-valid-arweave-wallet-address-1"
local testAddress2 = "test-this-is-valid-arweave-wallet-address-2"
local testAddress3 = "test-this-is-valid-arweave-wallet-address-3"
local testAddress4 = "test-this-is-valid-arweave-wallet-address-4"

describe("tips", function()
	describe("calculateStakeWeight", function()
		before_each(function()
			_G.Balances = {
				[testAddress1] = 1000000, -- 1 ARDRIVE
				[testAddress2] = 5000000, -- 5 ARDRIVE
				[testAddress3] = 0,
			}
			_G.Vaults = {}
		end)

		it("should return balance as weight when no vaults exist", function()
			local weight = tips.calculateStakeWeight(testAddress1, 1000000)
			assert.are.equal(1000000, weight)
		end)

		it("should return 0 for address with no balance and no vaults", function()
			local weight = tips.calculateStakeWeight(testAddress3, 1000000)
			assert.are.equal(0, weight)
		end)

		it("should return 0 for non-existent address", function()
			local weight = tips.calculateStakeWeight("non-existent-address", 1000000)
			assert.are.equal(0, weight)
		end)

		it("should apply 1.0x multiplier for 14-day vault", function()
			_G.Vaults[testAddress1] = {
				["vault1"] = {
					balance = 2000000, -- 2 ARDRIVE
					startTimestamp = 0,
					endTimestamp = constants.MIN_TOKEN_LOCK_TIME_MS, -- 14 days
				},
			}
			local weight = tips.calculateStakeWeight(testAddress1, 1000) -- Current time within vault period
			-- Balance (1 ARDRIVE) + Vault (2 ARDRIVE * 1.0x) = 3 ARDRIVE
			assert.are.equal(3000000, weight)
		end)

		it("should apply 3.0x multiplier for 365+ day vault", function()
			local oneYearMs = 365 * 24 * 60 * 60 * 1000
			_G.Vaults[testAddress1] = {
				["vault1"] = {
					balance = 2000000, -- 2 ARDRIVE
					startTimestamp = 0,
					endTimestamp = oneYearMs,
				},
			}
			local weight = tips.calculateStakeWeight(testAddress1, 1000)
			-- Balance (1 ARDRIVE) + Vault (2 ARDRIVE * 3.0x) = 7 ARDRIVE
			assert.are.equal(7000000, weight)
		end)

		it("should apply linear scaling between 14 and 365 days", function()
			-- Test 189.5 days (halfway between 14 and 365)
			-- Should give 2.0x multiplier
			local halfwayDays = 189.5
			local halfwayMs = halfwayDays * 24 * 60 * 60 * 1000
			_G.Vaults[testAddress1] = {
				["vault1"] = {
					balance = 2000000, -- 2 ARDRIVE
					startTimestamp = 0,
					endTimestamp = halfwayMs,
				},
			}
			local weight = tips.calculateStakeWeight(testAddress1, 1000)
			-- Balance (1 ARDRIVE) + Vault (2 ARDRIVE * 2.0x) = 5 ARDRIVE
			assert.are.equal(5000000, weight)
		end)

		it("should exclude expired vaults from weight calculation", function()
			_G.Vaults[testAddress1] = {
				["expired"] = {
					balance = 2000000,
					startTimestamp = 0,
					endTimestamp = 1000, -- Expires at timestamp 1000
				},
				["active"] = {
					balance = 3000000,
					startTimestamp = 0,
					endTimestamp = constants.MIN_TOKEN_LOCK_TIME_MS,
				},
			}
			local weight = tips.calculateStakeWeight(testAddress1, 2000) -- Current time after expired vault
			-- Balance (1 ARDRIVE) + Active Vault (3 ARDRIVE * 1.0x) = 4 ARDRIVE
			-- Expired vault not counted
			assert.are.equal(4000000, weight)
		end)

		it("should handle multiple active vaults with different durations", function()
			local oneYearMs = 365 * 24 * 60 * 60 * 1000
			_G.Vaults[testAddress1] = {
				["vault1"] = {
					balance = 1000000, -- 1 ARDRIVE at 1.0x
					startTimestamp = 0,
					endTimestamp = constants.MIN_TOKEN_LOCK_TIME_MS,
				},
				["vault2"] = {
					balance = 2000000, -- 2 ARDRIVE at 3.0x
					startTimestamp = 0,
					endTimestamp = oneYearMs,
				},
			}
			local weight = tips.calculateStakeWeight(testAddress1, 1000)
			-- Balance (1) + Vault1 (1 * 1.0) + Vault2 (2 * 3.0) = 8 ARDRIVE
			assert.are.equal(8000000, weight)
		end)

		it("should handle address with only vaults and no liquid balance", function()
			_G.Balances[testAddress4] = nil
			_G.Vaults[testAddress4] = {
				["vault1"] = {
					balance = 5000000,
					startTimestamp = 0,
					endTimestamp = constants.MIN_TOKEN_LOCK_TIME_MS,
				},
			}
			local weight = tips.calculateStakeWeight(testAddress4, 1000)
			assert.are.equal(5000000, weight) -- 5 ARDRIVE * 1.0x
		end)

		it("should cap multiplier at 3.0x for vaults longer than 365 days", function()
			local twoYearsMs = 730 * 24 * 60 * 60 * 1000
			_G.Vaults[testAddress1] = {
				["vault1"] = {
					balance = 1000000,
					startTimestamp = 0,
					endTimestamp = twoYearsMs,
				},
			}
			local weight = tips.calculateStakeWeight(testAddress1, 1000)
			-- Balance (1) + Vault (1 * 3.0x capped) = 4 ARDRIVE
			assert.are.equal(4000000, weight)
		end)
	end)

	describe("getTotalStakeWeight", function()
		before_each(function()
			_G.Balances = {
				[testAddress1] = 1000000,
				[testAddress2] = 2000000,
				[testAddress3] = 3000000,
			}
			_G.Vaults = {
				[testAddress1] = {
					["vault1"] = {
						balance = 1000000,
						startTimestamp = 0,
						endTimestamp = constants.MIN_TOKEN_LOCK_TIME_MS,
					},
				},
			}
		end)

		it("should calculate total weight excluding specified address", function()
			local total = tips.getTotalStakeWeight(testAddress1, 1000)
			-- testAddress2 (2 ARDRIVE) + testAddress3 (3 ARDRIVE) = 5 ARDRIVE
			-- testAddress1 excluded
			assert.are.equal(5000000, total)
		end)

		it("should include all addresses when excludeAddress is nil", function()
			local total = tips.getTotalStakeWeight(nil, 1000)
			-- testAddress1 (1 + 1) + testAddress2 (2) + testAddress3 (3) = 7 ARDRIVE
			assert.are.equal(7000000, total)
		end)

		it("should return 0 when all weight is in excluded address", function()
			_G.Balances = {
				[testAddress1] = 10000000,
			}
			local total = tips.getTotalStakeWeight(testAddress1, 1000)
			assert.are.equal(0, total)
		end)

		it("should handle empty network", function()
			_G.Balances = {}
			_G.Vaults = {}
			local total = tips.getTotalStakeWeight(testAddress1, 1000)
			assert.are.equal(0, total)
		end)
	end)

	describe("calculateSuggestedTip", function()
		it("should return 15% of transfer amount", function()
			local tip = tips.calculateSuggestedTip(1000000) -- 1 ARDRIVE
			assert.are.equal(150000, tip) -- 0.15 ARDRIVE
		end)

		it("should floor fractional amounts", function()
			local tip = tips.calculateSuggestedTip(1000001) -- Would be 150000.15
			assert.are.equal(150000, tip) -- Floored to 150000
		end)

		it("should handle minimum transfer amount", function()
			local minTransfer = constants.ARDRIVEToMARDRIVE(100) -- 100 ARDRIVE
			local tip = tips.calculateSuggestedTip(minTransfer)
			assert.are.equal(15000000, tip) -- 15 ARDRIVE
		end)

		it("should return 0 for 0 transfer", function()
			local tip = tips.calculateSuggestedTip(0)
			assert.are.equal(0, tip)
		end)

		it("should handle large amounts", function()
			local largeAmount = 1000000000000 -- 1M ARDRIVE
			local tip = tips.calculateSuggestedTip(largeAmount)
			assert.are.equal(150000000000, tip) -- 150K ARDRIVE
		end)
	end)

	describe("selectWeightedRecipient", function()
		before_each(function()
			_G.Balances = {
				[testAddress1] = 1000000, -- Sender
				[testAddress2] = 2000000,
				[testAddress3] = 3000000,
			}
			_G.Vaults = {}
		end)

		it("should select the only eligible recipient", function()
			_G.Balances = {
				[testAddress1] = 1000000, -- Sender
				[testAddress2] = 2000000, -- Only eligible
			}
			local recipient = tips.selectWeightedRecipient(testAddress1, 1000, "test-msg-id")
			assert.are.equal(testAddress2, recipient)
		end)

		it("should exclude the sender from selection", function()
			_G.Balances = {
				[testAddress1] = 10000000, -- Sender with most tokens
				[testAddress2] = 1000000,
			}
			local recipient = tips.selectWeightedRecipient(testAddress1, 1000, "test-msg-id")
			assert.are.equal(testAddress2, recipient)
		end)

		it("should error when no eligible recipients exist", function()
			_G.Balances = {
				[testAddress1] = 10000000, -- Only holder is sender
			}
			local status, err = pcall(tips.selectWeightedRecipient, testAddress1, 1000, "test-msg-id")
			assert.is_false(status)
			assert.match("No eligible tip recipients", err)
		end)

		it("should error when all non-sender addresses have zero weight", function()
			_G.Balances = {
				[testAddress1] = 10000000,
				[testAddress2] = 0,
				[testAddress3] = 0,
			}
			local status, err = pcall(tips.selectWeightedRecipient, testAddress1, 1000, "test-msg-id")
			assert.is_false(status)
			assert.match("No eligible tip recipients", err)
		end)

		it("should be deterministic with the same message ID", function()
			local recipient1 = tips.selectWeightedRecipient(testAddress1, 1000, "same-msg-id")
			local recipient2 = tips.selectWeightedRecipient(testAddress1, 1000, "same-msg-id")
			assert.are.equal(recipient1, recipient2)
		end)

		it("should produce different results with different message IDs", function()
			-- Add more addresses to increase probability of different selections
			_G.Balances = {
				[testAddress1] = 1000000, -- Sender
				[testAddress2] = 1000000,
				[testAddress3] = 1000000,
				[testAddress4] = 1000000,
			}
			
			local results = {}
			-- Try multiple message IDs
			for i = 1, 10 do
				local recipient = tips.selectWeightedRecipient(testAddress1, 1000, "msg-id-" .. i)
				results[recipient] = true
			end
			
			-- Should have selected different recipients
			local uniqueCount = 0
			for _ in pairs(results) do
				uniqueCount = uniqueCount + 1
			end
			assert.is_true(uniqueCount > 1, "Should select different recipients with different message IDs")
		end)

		it("should weight selection by stake amount", function()
			_G.Balances = {
				[testAddress1] = 1000000, -- Sender
				[testAddress2] = 9000000, -- 90% of eligible weight
				[testAddress3] = 1000000, -- 10% of eligible weight
			}
			
			local selections = {
				[testAddress2] = 0,
				[testAddress3] = 0,
			}
			
			-- Run many selections to verify weighted distribution
			for i = 1, 100 do
				local recipient = tips.selectWeightedRecipient(testAddress1, 1000, "weighted-test-msg-" .. i)
				selections[recipient] = selections[recipient] + 1
			end
			
			-- testAddress2 should be selected roughly 90% of the time
			-- Allow for variance with ISAAC RNG (60-100% for high weight address)
			assert.is_true(selections[testAddress2] >= 60, "High weight address should be selected more often: " .. selections[testAddress2])
			assert.is_true(selections[testAddress3] >= 1, "Low weight address should still be selected sometimes: " .. selections[testAddress3])
		end)

		it("should include vault weights in selection probability", function()
			_G.Balances = {
				[testAddress1] = 1000000, -- Sender
				[testAddress2] = 1000000, -- 1 ARDRIVE liquid
				[testAddress3] = 1000000, -- 1 ARDRIVE liquid
			}
			_G.Vaults = {
				[testAddress2] = {
					["vault1"] = {
						balance = 9000000, -- 9 ARDRIVE vaulted at 1.0x
						startTimestamp = 0,
						endTimestamp = constants.MIN_TOKEN_LOCK_TIME_MS,
					},
				},
			}
			
			-- testAddress2 has 10 ARDRIVE weight (1 + 9)
			-- testAddress3 has 1 ARDRIVE weight
			local selections = {
				[testAddress2] = 0,
				[testAddress3] = 0,
			}
			
			for i = 1, 200 do
				local recipient = tips.selectWeightedRecipient(testAddress1, 1000, "vault-weight-test-" .. i)
				selections[recipient] = selections[recipient] + 1
			end
			
			-- testAddress2 should be selected roughly 91% of the time (10/11)
			-- With ISAAC RNG, allow more variance (70% instead of 80%)
			assert.is_true(selections[testAddress2] >= 140, "Vaulted address should have higher selection rate: got " .. selections[testAddress2] .. " out of 200")
		end)

		it("should handle case where sender has all liquid balance but others have vaults", function()
			_G.Balances = {
				[testAddress1] = 10000000, -- Sender with all liquid
			}
			_G.Vaults = {
				[testAddress2] = {
					["vault1"] = {
						balance = 1000000,
						startTimestamp = 0,
						endTimestamp = constants.MIN_TOKEN_LOCK_TIME_MS,
					},
				},
			}
			
			local recipient = tips.selectWeightedRecipient(testAddress1, 1000, "test-msg-id")
			assert.are.equal(testAddress2, recipient)
		end)
	end)

	describe("validateTransferWithTip", function()
		it("should validate minimum transfer amount", function()
			local status, err = pcall(tips.validateTransferWithTip, 99999999, 1000000) -- 99.999999 ARDRIVE
			assert.is_false(status)
			assert.match("Transfer amount must be at least 100 ARDRIVE", err)
		end)

		it("should allow exactly minimum transfer amount", function()
			local status = pcall(tips.validateTransferWithTip, 100000000, 1000000) -- 100 ARDRIVE
			assert.is_true(status)
		end)

		it("should validate positive tip amount", function()
			local status, err = pcall(tips.validateTransferWithTip, 100000000, 0)
			assert.is_false(status)
			assert.match("Tip amount must be positive", err)
		end)

		it("should validate negative tip amount", function()
			local status, err = pcall(tips.validateTransferWithTip, 100000000, -1000)
			assert.is_false(status)
			assert.match("Tip amount must be positive", err)
		end)

		it("should accept valid transfer and tip amounts", function()
			local status = pcall(tips.validateTransferWithTip, 1000000000, 150000000) -- 1000 ARDRIVE + 150 tip
			assert.is_true(status)
		end)
	end)

	describe("processTransferWithTip", function()
		before_each(function()
			_G.Balances = {
				[testAddress1] = 200000000, -- 200 ARDRIVE (sender)
				[testAddress2] = 10000000, -- 10 ARDRIVE (service provider)
				[testAddress3] = 5000000, -- 5 ARDRIVE (potential tip recipient)
			}
			_G.Vaults = {}
		end)

		it("should execute transfer with default tip successfully", function()
			local result = tips.processTransferWithTip({
				from = testAddress1,
				recipient = testAddress2,
				quantity = 100000000, -- 100 ARDRIVE
				tipAmount = nil, -- Use default 15%
				currentTimestamp = 1000,
				msgId = "test-msg-id",
			})

			-- Either testAddress2 or testAddress3 could be selected
			assert.is_true(result.tipRecipient == testAddress2 or result.tipRecipient == testAddress3)
			assert.are.equal(15000000, result.tipAmount) -- 15 ARDRIVE (15%)
			assert.are.equal(100000000, result.transferAmount)
			
			-- Check balances
			assert.are.equal(85000000, _G.Balances[testAddress1]) -- 200 - 100 - 15
			
			if result.tipRecipient == testAddress2 then
				assert.are.equal(125000000, _G.Balances[testAddress2]) -- 10 + 100 + 15
				assert.are.equal(5000000, _G.Balances[testAddress3]) -- unchanged
			else
				assert.are.equal(110000000, _G.Balances[testAddress2]) -- 10 + 100
				assert.are.equal(20000000, _G.Balances[testAddress3]) -- 5 + 15
			end
		end)

		it("should execute transfer with custom tip amount", function()
			local result = tips.processTransferWithTip({
				from = testAddress1,
				recipient = testAddress2,
				quantity = 100000000,
				tipAmount = 20000000, -- 20 ARDRIVE custom tip
				currentTimestamp = 1000,
				msgId = "test-msg-id-2", -- Different ID for different selection
			})

			-- Either testAddress2 or testAddress3 could be selected
			assert.is_true(result.tipRecipient == testAddress2 or result.tipRecipient == testAddress3)
			assert.are.equal(20000000, result.tipAmount)
			
			-- Check balances
			assert.are.equal(80000000, _G.Balances[testAddress1]) -- 200 - 100 - 20
			
			if result.tipRecipient == testAddress2 then
				assert.are.equal(130000000, _G.Balances[testAddress2]) -- 10 + 100 + 20
				assert.are.equal(5000000, _G.Balances[testAddress3]) -- unchanged
			else
				assert.are.equal(110000000, _G.Balances[testAddress2]) -- 10 + 100
				assert.are.equal(25000000, _G.Balances[testAddress3]) -- 5 + 20
			end
		end)

		it("should fail when insufficient balance for transfer plus tip", function()
			_G.Balances[testAddress1] = 110000000 -- Only 110 ARDRIVE

			local status, err = pcall(tips.processTransferWithTip, {
				from = testAddress1,
				recipient = testAddress2,
				quantity = 100000000, -- 100 ARDRIVE
				tipAmount = nil, -- Would need 15 more
				currentTimestamp = 1000,
				msgId = "test-msg-id",
			})

			assert.is_false(status)
			assert.match("Insufficient balance", err)
			
			-- Balances unchanged
			assert.are.equal(110000000, _G.Balances[testAddress1])
			assert.are.equal(10000000, _G.Balances[testAddress2])
		end)

		it("should fail when no eligible tip recipients", function()
			_G.Balances = {
				[testAddress1] = 200000000, -- Only the sender has balance
			}

			local status, err = pcall(tips.processTransferWithTip, {
				from = testAddress1,
				recipient = testAddress2,
				quantity = 100000000,
				tipAmount = nil,
				currentTimestamp = 1000,
				msgId = "test-msg-id",
			})

			assert.is_false(status)
			assert.match("No eligible tip recipients", err)
			
			-- Balances unchanged
			assert.are.equal(200000000, _G.Balances[testAddress1])
		end)

		it("should select tip recipient based on vault weights", function()
			_G.Vaults = {
				[testAddress3] = {
					["vault1"] = {
						balance = 95000000, -- 95 ARDRIVE vaulted (100 total weight)
						startTimestamp = 0,
						endTimestamp = constants.MIN_TOKEN_LOCK_TIME_MS,
					},
				},
			}

			local result = tips.processTransferWithTip({
				from = testAddress1,
				recipient = testAddress2,
				quantity = 100000000,
				tipAmount = 10000000,
				currentTimestamp = 1000,
				msgId = "test-msg-id",
			})

			-- testAddress3 has 100 ARDRIVE weight (5 + 95)
			-- testAddress2 has 10 ARDRIVE weight
			-- testAddress3 should almost always be selected
			assert.are.equal(testAddress3, result.tipRecipient)
		end)

		it("should handle self-transfer attempt", function()
			local status, err = pcall(tips.processTransferWithTip, {
				from = testAddress1,
				recipient = testAddress1, -- Self
				quantity = 100000000,
				tipAmount = nil,
				currentTimestamp = 1000,
				msgId = "test-msg-id",
			})

			assert.is_false(status)
			assert.match("Cannot transfer to self", err)
		end)

		it("should return comprehensive result object", function()
			local result = tips.processTransferWithTip({
				from = testAddress1,
				recipient = testAddress2,
				quantity = 100000000,
				tipAmount = 15000000,
				currentTimestamp = 1000,
				msgId = "test-msg-id-comprehensive",
			})

			assert.are.equal(testAddress1, result.from)
			assert.are.equal(testAddress2, result.recipient)
			assert.are.equal(100000000, result.transferAmount)
			assert.are.equal(15000000, result.tipAmount)
			-- Either address could be selected
			assert.is_true(result.tipRecipient == testAddress2 or result.tipRecipient == testAddress3)
			assert.is_true(result.tipWeight > 0)
			assert.is_true(result.totalNetworkWeight > 0)
		end)
	end)
end)