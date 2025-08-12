import { assertNoResultError } from './helpers.mjs';
import { describe, it, before, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert';
import {
  DEFAULT_HANDLE_OPTIONS,
  PROCESS_OWNER,
  STUB_TIMESTAMP,
} from '../tools/constants.mjs';
import {
  getVaults,
  handle,
  startMemory,
  createVault,
  createVaultedTransfer,
  getBalance,
  getInfo,
  getVault,
  getPaginatedVaults,
} from './helpers.mjs';

describe('Vaults', async () => {
  let sharedMemory = startMemory;
  let endingMemory;
  beforeEach(async () => {
  });

  afterEach(async () => {
  });

  const assertVaultExists = async ({ vaultId, address, memory }) => {
    const vault = await handle({
      options: {
        Tags: [
          { name: 'Action', value: 'Vault' },
          { name: 'Vault-Id', value: vaultId },
          { name: 'Address', value: address },
        ],
      },
      mem: memory,
    });
    assertNoResultError(vault);
    // make sure it is a vault
    assert.strictEqual(
      vault.Messages[0].Tags.find((tag) => tag.name === 'Vault-Id').value,
      vaultId,
    );
    const data = vault.Messages[0].Data;
    // Check if vault exists
    if (data === 'Vault not found') {
      throw new Error('Vault not found');
    }
    return JSON.parse(data);
  };

  describe('createVault', () => {
    it('should create a vault', async () => {
      const lockLengthMs = 1209600000;
      const quantity = 1000000000;
      const balanceBefore = await handle({
        options: {
          Tags: [{ name: 'Action', value: 'Balance' }],
        },
        memory: sharedMemory,
      });
      const balanceBeforeData = JSON.parse(balanceBefore.Messages[0].Data);
      const { result: createVaultResult, memory: newMemory } = await createVault({
        quantity,
        lockLengthMs,
        from: PROCESS_OWNER,
        memory: sharedMemory,
      });
      // parse the data and ensure the vault was created
      const createVaultResultData = JSON.parse(
        createVaultResult.Messages[0].Data,
      );
      const vaultId = createVaultResult.Messages[0].Tags.find(
        (tag) => tag.name === 'Vault-Id',
      ).value;
      // assert the vault id is in the tags
      assert.deepEqual(vaultId, DEFAULT_HANDLE_OPTIONS.Id);

      // assert the balance is deducted
      const balanceAfterVault = await handle({
        options: {
          Tags: [{ name: 'Action', value: 'Balance' }],
        },
        mem: newMemory,
      });
      const balanceAfterVaultData = JSON.parse(
        balanceAfterVault.Messages[0].Data,
      );
      assert.deepEqual(balanceAfterVaultData, balanceBeforeData - quantity);

      const vaultData = await assertVaultExists({
        vaultId,
        address: PROCESS_OWNER,
        memory: newMemory,
      });
      assert.deepEqual(
        createVaultResultData.balance,
        vaultData.balance,
        quantity,
      );
      assert.deepEqual(
        vaultData.startTimestamp,
        createVaultResultData.startTimestamp,
      );
      assert.deepEqual(
        vaultData.endTimestamp,
        createVaultResultData.endTimestamp,
        createVaultResult.startTimestamp + lockLengthMs,
      );
      endingMemory = newMemory;
    });

    it('should throw an error if vault size is too small', async () => {
      const lockLengthMs = 1209600000;
      const quantity = 99999999;
      const balanceBefore = await getBalance({
        address: PROCESS_OWNER,
        memory: sharedMemory,
      });
      const { result: createVaultResult, memory: vaultMemory } = await createVault({
        quantity,
        lockLengthMs,
        shouldAssertNoResultError: false,
        memory: sharedMemory,
      });

      const actionTag = createVaultResult.Messages?.[0]?.Tags?.find(
        (tag) => tag.name === 'Action',
      );
      assert.strictEqual(actionTag.value, 'Invalid-Create-Vault-Notice');
      const errorTag = createVaultResult.Messages?.[0]?.Tags?.find(
        (tag) => tag.name === 'Error',
      );
      assert.ok(errorTag, 'Error tag should be present');
      assert(
        errorTag.value.includes(
          'Invalid quantity. Must be integer greater than',
        ),
      );

      // assert the balance is deducted
      const balanceAfterVault = await getBalance({
        address: PROCESS_OWNER,
        memory: vaultMemory,
      });
      assert.deepEqual(balanceAfterVault, balanceBefore);
      endingMemory = vaultMemory;
    });

    it('should prune a created vault once the end timestamp is reached', async () => {
      const lockLengthMs = 1209600000;
      const quantity = 1000000000;

      const { result: createVaultResult, memory: vaultMemory } = await createVault({
        quantity,
        lockLengthMs,
        memory: sharedMemory,
        msgId: 'unique-vault-id-'.padEnd(43, 'b'),
      });

      const vaultData = JSON.parse(createVaultResult.Messages[0].Data);

      const balanceBeforeUnlocked = await getBalance({
        address: PROCESS_OWNER,
        memory: vaultMemory,
        timestamp: vaultData.startTimestamp,
      });

      // any message after the end timestamp should prune the vault
      const nextMessageTimestamp = vaultData.endTimestamp + 1;
      const { result: getInfoResult, memory: infoMemory } = await getInfo({
        memory: vaultMemory,
        timestamp: nextMessageTimestamp,
      });

      const vaultAfterPrune = await getVault({
        address: PROCESS_OWNER,
        memory: infoMemory,
        timestamp: nextMessageTimestamp,
        vaultId: 'unique-vault-id-'.padEnd(43, 'b'),
        assertNoResultError: false,
      });
      assert.deepEqual(vaultAfterPrune, undefined);

      // after that message, assert the vault is gone and the balance is increased
      const balanceAfterVault = await getBalance({
        address: PROCESS_OWNER,
        memory: infoMemory,
      });
      assert.deepEqual(balanceAfterVault, balanceBeforeUnlocked + quantity);
    });
  });

  describe('extendVault', () => {
    it('should extend a vault', async () => {
      const lockLengthMs = 1209600000;
      const quantity = 1000000000;

      const { result: createVaultResult, memory: vaultMemory } = await createVault({
        quantity,
        lockLengthMs,
        memory: sharedMemory,
      });

      // ensure no error
      const errorTag = createVaultResult.Messages?.[0]?.Tags?.find(
        (tag) => tag.name === 'Error',
      );
      assert.deepEqual(errorTag, undefined);

      const createVaultResultData = JSON.parse(
        createVaultResult.Messages[0].Data,
      );
      const vaultId = createVaultResult.Messages[0].Tags.find(
        (tag) => tag.name === 'Vault-Id',
      ).value;

      const extendVaultResult = await handle({
        options: {
          Tags: [
            {
              name: 'Action',
              value: 'Extend-Vault',
            },
            {
              name: 'Vault-Id',
              value: vaultId,
            },
            {
              name: 'Extend-Length',
              value: lockLengthMs.toString(),
            },
          ],
        },
        mem: vaultMemory,
      });

      // ensure no error
      assertNoResultError(extendVaultResult);

      const extendVaultResultData = JSON.parse(
        extendVaultResult.Messages[0].Data,
      );
      assert.deepEqual(
        extendVaultResultData.balance,
        createVaultResultData.balance,
        quantity,
      );
      endingMemory = extendVaultResult.Memory;
    });
  });

  describe('increaseVaultBalance', () => {
    it('should increase a vault balance', async () => {
      const quantity = 1000000000;
      const lockLengthMs = 1209600000;
      const { result: createVaultResult, memory: vaultMemory } = await createVault({
        quantity,
        lockLengthMs,
        memory: sharedMemory,
      });

      // ensure no error
      const errorTag = createVaultResult.Messages?.[0]?.Tags?.find(
        (tag) => tag.name === 'Error',
      );
      assert.deepEqual(errorTag, undefined);

      const createVaultResultData = JSON.parse(
        createVaultResult.Messages[0].Data,
      );

      const vaultId = createVaultResult.Messages[0].Tags.find(
        (tag) => tag.name === 'Vault-Id',
      ).value;

      const increaseVaultBalanceResult = await handle({
        options: {
          Tags: [
            {
              name: 'Action',
              value: 'Increase-Vault',
            },
            {
              name: 'Vault-Id',
              value: vaultId,
            },
            {
              name: 'Quantity',
              value: quantity.toString(),
            },
          ],
        },
        mem: vaultMemory,
      });

      // ensure no error
      const increaseVaultBalanceErrorTag =
        increaseVaultBalanceResult.Messages?.[0]?.Tags?.find(
          (tag) => tag.name === 'Error',
        );
      assert.deepEqual(increaseVaultBalanceErrorTag, undefined);

      const increaseVaultBalanceResultData = JSON.parse(
        increaseVaultBalanceResult.Messages[0].Data,
      );
      assert.deepEqual(
        increaseVaultBalanceResultData.balance,
        createVaultResultData.balance + quantity,
      );
      endingMemory = increaseVaultBalanceResult.Memory;
    });
  });

  describe('vaultedTransfer', () => {
    const quantity = 1000000000;
    const lockLengthMs = 1209600000;
    const recipient = '0x0000000000000000000000000000000000000000';

    it('should create a vault for the recipient with a valid address', async () => {
      const { result: createVaultedTransferResult, memory: vaultMemory } =
        await createVaultedTransfer({
          quantity,
          lockLengthMs,
          recipient,
          memory: sharedMemory,
        });

      // it should create two messages, one for sender and other for recipient
      assert.deepEqual(createVaultedTransferResult.Messages.length, 2);

      const senderMessage = createVaultedTransferResult.Messages.find((msg) =>
        msg.Tags.find(
          (tag) => tag.name === 'Action' && tag.value === 'Debit-Notice',
        ),
      );

      // ensure it is not undefined
      assert.ok(senderMessage);

      const recipientMessage = createVaultedTransferResult.Messages.find(
        (msg) =>
          msg.Tags.find(
            (tag) =>
              tag.name === 'Action' && tag.value === 'Create-Vault-Notice',
          ),
      );

      assert.ok(recipientMessage);

      const vaultId = recipientMessage.Tags.find(
        (tag) => tag.name === 'Vault-Id',
      ).value;

      // ensure vault id is defined
      assert.ok(vaultId);

      const createdVaultData = await assertVaultExists({
        vaultId,
        address: recipient,
        memory: vaultMemory,
      });

      assert.deepEqual(createdVaultData.balance, quantity);
      assert.deepEqual(createdVaultData.startTimestamp, STUB_TIMESTAMP);
      assert.deepEqual(
        createdVaultData.endTimestamp,
        STUB_TIMESTAMP + lockLengthMs,
      );
      endingMemory = createVaultedTransferResult.Memory;
    });

    it('should create a revokable vault for the recipient and the controller should be able to revoke that vault', async () => {
      // Use PROCESS_OWNER as controller for simplicity in tests
      const controller = PROCESS_OWNER;
      
      const { result: createVaultedTransferResult, memory: vaultMemory } =
        await createVaultedTransfer({
          quantity,
          lockLengthMs,
          recipient,
          from: controller,
          memory: sharedMemory,
          revokable: true,
        });

      // Find the Create-Vault-Notice message to get the vault ID
      const vaultMessage = createVaultedTransferResult.Messages.find(
        (msg) => msg.Tags.find(
          (tag) => tag.name === 'Action' && tag.value === 'Create-Vault-Notice'
        )
      );
      
      // If no vault message, check for error
      if (!vaultMessage) {
        const errorMessage = createVaultedTransferResult.Messages.find(
          (msg) => msg.Tags.find(
            (tag) => tag.name === 'Error'
          )
        );
        if (errorMessage) {
          const errorTag = errorMessage.Tags.find(tag => tag.name === 'Error');
          assert.fail(`Vault creation failed: ${errorTag?.value}`);
        }
        assert.fail('No Create-Vault-Notice message found');
      }
      
      const vaultId = vaultMessage.Tags.find(
        (tag) => tag.name === 'Vault-Id',
      ).value;

      // ensure vault id is defined
      assert.ok(vaultId);

      const expectedVaultData = {
        balance: quantity,
        controller,
        startTimestamp: STUB_TIMESTAMP,
        endTimestamp: STUB_TIMESTAMP + lockLengthMs,
      };

      const createdVaultData = await assertVaultExists({
        vaultId,
        address: recipient,
        memory: vaultMemory,
      });
      assert.deepEqual(createdVaultData, expectedVaultData);

      // Assert balance is reduced for controller
      const controllerBalance = await getBalance({
        address: controller,
        memory: vaultMemory,
      });
      // Controller had initial balance, so check it's reduced by quantity
      const expectedBalance = 10000000000000 - quantity; // Initial balance minus vaulted amount
      assert.deepEqual(controllerBalance, expectedBalance);

      // Revoke the vault
      const result = await handle({
        options: {
          Tags: [
            { name: 'Action', value: 'Revoke-Vault' },
            { name: 'Recipient', value: recipient },
            { name: 'Vault-Id', value: vaultId },
          ],
          From: controller,
          Owner: controller,
        },
        mem: vaultMemory,
      });

      assert.deepEqual(result.Messages.length, 2);
      const recipientMessageAfterRevoke = result.Messages.find((msg) =>
        msg.Tags.find(
          (tag) => tag.name === 'Action' && tag.value === 'Revoke-Vault-Notice',
        ),
      );
      assert.ok(recipientMessageAfterRevoke);
      const recipientVaultDataAfterRevoke = JSON.parse(
        recipientMessageAfterRevoke.Data,
      );
      assert.deepEqual(recipientVaultDataAfterRevoke, expectedVaultData);

      const controllerMessageAfterRevoke = result.Messages.find((msg) =>
        msg.Tags.find(
          (tag) => tag.name === 'Action' && tag.value === 'Credit-Notice',
        ),
      );
      assert.ok(controllerMessageAfterRevoke);
      // Credit-Notice sends a text message, not JSON
      // Just verify it exists - the important part is balance was restored

      // Assert balance is back for controller
      const controllerBalanceAfter = await getBalance({
        address: controller,
        memory: result.Memory,
      });
      // After revoking, controller should have the initial balance again
      assert.deepEqual(controllerBalanceAfter, 10000000000000);

      endingMemory = result.Memory;
    });

    it('should fail if the vault size is too small', async () => {
      const quantity = 99999999;
      const { result: createVaultedTransferResult, memory: vaultMemory } =
        await createVaultedTransfer({
          quantity,
          lockLengthMs,
          recipient,
          shouldAssertNoResultError: false,
          memory: sharedMemory,
        });

      const errorTag = createVaultedTransferResult.Messages?.[0]?.Tags?.find(
        (tag) => tag.name === 'Error',
      );
      assert.ok(errorTag);
      assert(
        errorTag.value.includes(
          'Invalid quantity. Must be integer greater than',
        ),
      );
      endingMemory = createVaultedTransferResult.Memory;
    });

    it('should fail if the recipient address is invalid and Allow-Unsafe-Addresses is not provided', async () => {
      const recipient = 'invalid-address';
      const { result: createVaultedTransferResult, memory: vaultMemory } =
        await createVaultedTransfer({
          quantity,
          lockLengthMs,
          recipient,
          shouldAssertNoResultError: false,
          memory: sharedMemory,
        });

      const errorTag = createVaultedTransferResult.Messages?.[0]?.Tags?.find(
        (tag) => tag.name === 'Error',
      );
      assert.ok(errorTag);
      assert(errorTag.value.includes('Invalid recipient'));
      endingMemory = createVaultedTransferResult.Memory;
    });

    it('should create a vault for the recipient with an invalid address and Allow-Unsafe-Addresses is provided', async () => {
      const recipient = 'invalid-address';
      const msgId = 'unique-id-'.padEnd(43, 'a');
      const { result: createVaultedTransferResult, memory: vaultMemory } =
        await createVaultedTransfer({
          quantity,
          lockLengthMs,
          recipient,
          allowUnsafeAddresses: true,
          msgId,
          memory: sharedMemory,
        });

      const createdVaultData = await assertVaultExists({
        vaultId: msgId,
        address: recipient,
        memory: vaultMemory,
      });
      assert.deepEqual(createdVaultData.balance, quantity);
      assert.deepEqual(createdVaultData.startTimestamp, STUB_TIMESTAMP);
      assert.deepEqual(
        createdVaultData.endTimestamp,
        STUB_TIMESTAMP + lockLengthMs,
      );
      endingMemory = createVaultedTransferResult.Memory;
    });

    it('should prune the vault after the end timestamp', async () => {
      const { result: createVaultedTransferResult, memory: vaultMemory } =
        await createVaultedTransfer({
          quantity,
          lockLengthMs,
          memory: sharedMemory,
          revokable: true,
          recipient: 'unique-recipient-'.padEnd(43, 'a'),
          msgId: 'unique-vault-id-'.padEnd(43, 'a'),
        });

      // Find the Create-Vault-Notice message for vault data
      const vaultMessage = createVaultedTransferResult.Messages.find(
        (msg) => msg.Tags.find(
          (tag) => tag.name === 'Action' && tag.value === 'Create-Vault-Notice'
        )
      );
      const vaultData = JSON.parse(vaultMessage.Data);

      const balanceBeforeUnlocked = await getBalance({
        address: 'unique-recipient-'.padEnd(43, 'a'),
        memory: vaultMemory,
        timestamp: vaultData.startTimestamp,
      });

      // any message after the end timestamp should prune the vault
      const nextMessageTimestamp = vaultData.endTimestamp + 1;
      const { result: getInfoResult, memory: infoMemory } = await getInfo({
        memory: vaultMemory,
        timestamp: nextMessageTimestamp,
      });

      const vaultAfterPrune = await getVault({
        address: 'unique-recipient-'.padEnd(43, 'a'),
        memory: infoMemory,
        timestamp: nextMessageTimestamp,
        vaultId: 'unique-vault-id-'.padEnd(43, 'a'),
        assertNoResultError: false,
      });
      assert.deepEqual(vaultAfterPrune, undefined);

      const balanceAfterPrune = await getBalance({
        address: 'unique-recipient-'.padEnd(43, 'a'),
        memory: infoMemory,
        timestamp: nextMessageTimestamp,
      });
      assert.deepEqual(balanceAfterPrune, balanceBeforeUnlocked + quantity);
    });
  });

  describe('getPaginatedVaults', () => {
    let paginatedVaultMemory = sharedMemory; // save the memory
    const vaultId1 = 'unique-id-1-'.padEnd(43, 'a');
    const secondVaulter = 'unique-second-address-'.padEnd(43, 'a');
    const vaultId2 = 'unique-id-2-'.padEnd(43, 'a');
    const vaultId3 = 'unique-id-3-'.padEnd(43, 'a');

    before(async () => {
      const { memory: updatedMemory } = await createVault({
        quantity: 500000000,
        lockLengthMs: 1209600000,
        memory: sharedMemory,
        msgId: vaultId1,
      });

      const transferResult = await handle({
        options: {
          From: PROCESS_OWNER,
          Owner: PROCESS_OWNER,
          Tags: [
            { name: 'Action', value: 'Transfer' },
            { name: 'Recipient', value: secondVaulter },
            { name: 'Quantity', value: String(1300000000) },
            { name: 'Cast', value: String(true) },
          ],
        },
        mem: updatedMemory,
      });

      const { memory: updatedMemory2 } = await createVault({
        quantity: 600000000,
        lockLengthMs: 1209600000,
        memory: transferResult.Memory,
        from: secondVaulter,
        msgId: vaultId2,
      });
      const { memory: updatedMemory3 } = await createVaultedTransfer({
        quantity: 700000000,
        lockLengthMs: 1209600000,
        memory: updatedMemory2,
        recipient: secondVaulter,
        revokable: true,
        msgId: vaultId3,
      });

      paginatedVaultMemory = updatedMemory3;
    });

    it('should get paginated vaults', async () => {
      let cursor = '';
      let fetchedVaults = [];
      while (true) {
        const paginatedVaultsResult = await getPaginatedVaults({
          memory: paginatedVaultMemory,
          cursor,
          sortBy: 'vaultId',
          limit: 1,
        });

        // parse items, nextCursor
        const { items, nextCursor, hasMore, sortBy, sortOrder, totalItems } =
          paginatedVaultsResult;

        assert.equal(totalItems, 2);
        assert.equal(items.length, 1);
        assert.equal(sortBy, 'vaultId');
        assert.equal(sortOrder, 'desc');
        assert.equal(hasMore, !!nextCursor);
        cursor = nextCursor;
        fetchedVaults.push(...items);
        endingMemory = paginatedVaultMemory;
        if (!cursor) break;
      }

      assert.deepEqual(fetchedVaults, [
        {
          address: secondVaulter,
          vaultId: vaultId3,
          balance: 700000000,
          startTimestamp: 21600000,
          endTimestamp: 1231200000,
          controller: PROCESS_OWNER,
        },
        {
          address: PROCESS_OWNER,
          vaultId: vaultId1,
          balance: 500000000,
          startTimestamp: 21600000,
          endTimestamp: 1231200000,
        },
      ]);
    });

    it('should get paginated vaults sorted by ascending balance', async () => {
      let cursor = '';
      let fetchedVaults = [];
      while (true) {
        const paginatedVaultsResult = await getPaginatedVaults({
          memory: paginatedVaultMemory,
          cursor,
          limit: 1,
          sortBy: 'balance',
          sortOrder: 'asc',
        });

        // parse items, nextCursor
        const { items, nextCursor, hasMore, sortBy, sortOrder, totalItems } =
          paginatedVaultsResult;

        assert.equal(totalItems, 2);
        assert.equal(items.length, 1);
        assert.equal(sortBy, 'balance');
        assert.equal(sortOrder, 'asc');
        assert.equal(hasMore, !!nextCursor);
        cursor = nextCursor;
        fetchedVaults.push(...items);
        endingMemory = paginatedVaultMemory;
        if (!cursor) break;
      }

      assert.deepEqual(fetchedVaults, [
        {
          address: PROCESS_OWNER,
          vaultId: vaultId1,
          balance: 500000000,
          startTimestamp: 21600000,
          endTimestamp: 1231200000,
        },
        {
          address: secondVaulter,
          vaultId: vaultId3,
          balance: 700000000,
          startTimestamp: 21600000,
          endTimestamp: 1231200000,
          controller: PROCESS_OWNER,
        },
      ]);
    });

    it('should get paginated vaults sorted by ascending balance', async () => {
      let cursor = '';
      let fetchedVaults = [];
      while (true) {
        const paginatedVaultsResult = await getPaginatedVaults({
          memory: paginatedVaultMemory,
          cursor,
          limit: 1,
          sortBy: 'address',
          sortOrder: 'asc',
        });

        // parse items, nextCursor
        const { items, nextCursor, hasMore, sortBy, sortOrder, totalItems } =
          paginatedVaultsResult;

        assert.equal(totalItems, 2);
        assert.equal(items.length, 1);
        assert.equal(sortBy, 'address');
        assert.equal(sortOrder, 'asc');
        assert.equal(hasMore, !!nextCursor);
        cursor = nextCursor;
        fetchedVaults.push(...items);
        endingMemory = paginatedVaultMemory;
        if (!cursor) break;
      }

      assert.deepEqual(fetchedVaults, [
        {
          address: PROCESS_OWNER,
          vaultId: vaultId1,
          balance: 500000000,
          startTimestamp: 21600000,
          endTimestamp: 1231200000,
        },
        {
          address: secondVaulter,
          vaultId: vaultId3,
          balance: 700000000,
          startTimestamp: 21600000,
          endTimestamp: 1231200000,
          controller: PROCESS_OWNER,
        },
      ]);
    });
  });
});
