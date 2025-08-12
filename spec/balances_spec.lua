local balances = require("balances")

local ownerAddress = "test-this-is-valid-arweave-wallet-address-0"
local testAddress1 = "test-this-is-valid-arweave-wallet-address-1"
local testAddress2 = "test-this-is-valid-arweave-wallet-address-2"
local testAddressEth = "0xFCAd0B19bB29D4674531d6f115237E16AfCE377c"
local unsafeAddress = "not-a-real-address"

describe("balances", function()
	before_each(function()
		_G.Balances = {
			[ownerAddress] = 100,
			[testAddress1] = 100,
		}
	end)

	it("should return the balance with getBalance", function()
		assert.are.equal(100, balances.getBalance(testAddress1))
	end)

	it("should return all balances with getBalances", function()
		assert.are.same({
			["test-this-is-valid-arweave-wallet-address-0"] = 100,
			["test-this-is-valid-arweave-wallet-address-1"] = 100,
		}, balances.getBalances())
	end)

	it("should transfer tokens", function()
		local result = balances.transfer(testAddress2, testAddress1, 100, false)
		assert.are.same(result[testAddress2], _G.Balances[testAddress2])
		assert.are.same(result[testAddress1], _G.Balances[testAddress1])
		assert.are.equal(100, _G.Balances[testAddress2])
		assert.are.equal(0, _G.Balances[testAddress1])
	end)

	it("should transfer tokens between Arweave and ETH addresses", function()
		local result = balances.transfer(testAddressEth, testAddress1, 100, false)
		assert.are.same(result[testAddressEth], _G.Balances[testAddressEth])
		assert.are.same(result[testAddress1], _G.Balances[testAddress1])
		assert.are.equal(100, _G.Balances[testAddressEth])
		assert.are.equal(0, _G.Balances[testAddress1])
	end)

	it("should fail when transferring to unsafe address and unsafe flag is true", function()
		local status, result = pcall(balances.transfer, unsafeAddress, testAddress1, 100, false)
		assert.is_false(status)
		assert.match("Invalid recipient", result)
		assert.are.equal(nil, _G.Balances[unsafeAddress])
		assert.are.equal(100, _G.Balances[testAddress1])
	end)

	it("should not fail when transferring to unsafe address and unsafe flag is false", function()
		local result = balances.transfer(unsafeAddress, testAddress1, 100, true)
		assert.are.same(result[unsafeAddress], _G.Balances[unsafeAddress])
		assert.are.same(result[testAddress1], _G.Balances[testAddress1])
		assert.are.equal(100, _G.Balances[unsafeAddress])
		assert.are.equal(0, _G.Balances[testAddress1])
	end)

	it("should error on insufficient balance", function()
		local status, result = pcall(balances.transfer, testAddress2, testAddress1, 101)
		assert.is_false(status)
		assert.match("Insufficient balance", result)
		assert.are.equal(nil, _G.Balances[testAddress2])
		assert.are.equal(100, _G.Balances[testAddress1])
	end)

	it("should error on insufficient balance (ETH)", function()
		local status, result = pcall(balances.transfer, testAddressEth, testAddress1, 101)
		assert.is_false(status)
		assert.match("Insufficient balance", result)
		assert.are.equal(nil, _G.Balances[testAddress2])
		assert.are.equal(100, _G.Balances[testAddress1])
	end)

	describe("mint", function()
		it("should mint tokens", function()
			local result = balances.mint(testAddress2, 100, false)
			assert.are.same(result[testAddress2], 100)
			assert.are.equal(100, _G.Balances[testAddress2])
			assert.are.equal(100, _G.Balances[testAddress1])
		end)
	end)

	describe("burn", function()
		it("should burn tokens", function()
			local result = balances.burn(testAddress1, 100)
			assert.are.same(result[testAddress1], 0)
			assert.are.equal(0, _G.Balances[testAddress1])
		end)
		it("should not burn tokens that arent available", function()
			local status, result = pcall(balances.burn, testAddress1, 1000)
			assert.is_false(status)
			assert.match("Insufficient balance", result)
			assert.are.equal(100, _G.Balances[testAddress1])
		end)
	end)

	describe("getPaginatedBalances", function()
		it("should return paginated balances", function()
			local returnedBalances = balances.getPaginatedBalances(nil, 10, "balance", "desc")
			assert.are.equal(10, returnedBalances.limit)
			assert.are.equal("balance", returnedBalances.sortBy)
			assert.are.equal("desc", returnedBalances.sortOrder)
			assert.is_false(returnedBalances.hasMore)
			assert.are.equal(2, returnedBalances.totalItems)
			assert.are.equal(2, #returnedBalances.items)
			
			-- Check that both addresses are present with correct balances
			-- Order is undefined when balances are equal
			local addresses = {}
			for _, item in ipairs(returnedBalances.items) do
				addresses[item.address] = item.balance
			end
			assert.are.equal(100, addresses[ownerAddress])
			assert.are.equal(100, addresses[testAddress1])
		end)
	end)
end)
