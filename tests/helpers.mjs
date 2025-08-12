import AoLoader from '@permaweb/ao-loader';
import {
  AOS_WASM,
  AO_LOADER_HANDLER_ENV,
  AO_LOADER_OPTIONS,
  DEFAULT_HANDLE_OPTIONS,
  BUNDLED_SOURCE_CODE,
  STUB_TIMESTAMP,
  PROCESS_OWNER
} from '../tools/constants.mjs';
import assert from 'node:assert';

export const mARDRIVEPerARDRIVE = 1_000_000;
export const ARDRIVEToMARDRIVE = (amount) => amount * mARDRIVEPerARDRIVE;

/**
 * Loads the aos wasm binary and returns the handle function with program memory
 * @returns {Promise<{handle: Function, memory: WebAssembly.Memory}>}
 */
export async function createAosLoader() {
  const handle = await AoLoader(AOS_WASM, AO_LOADER_OPTIONS);
  const evalRes = await handle(
    null,
    {
      ...DEFAULT_HANDLE_OPTIONS,
      Tags: [
        { name: 'Action', value: 'Eval' },
        { name: 'Module', value: ''.padEnd(43, '1') },
      ],
      Data: BUNDLED_SOURCE_CODE,
    },
    AO_LOADER_HANDLER_ENV,
  );
  return {
    handle,
    memory: evalRes.Memory,
  };
}

export function assertNoResultError(result) {
  const errorTag = result.Messages?.[0]?.Tags?.find(
    (tag) => tag.name === 'Error',
  );
  assert.strictEqual(errorTag, undefined);
}


const { handle: originalHandle, memory } = await createAosLoader();
export const startMemory = memory;

export async function handle({ options = {}, mem = startMemory }) {
  return originalHandle(
    mem,
    {
      ...DEFAULT_HANDLE_OPTIONS,
      ...options,
    },
    AO_LOADER_HANDLER_ENV,
  );
}

export const getBalances = async ({ memory, timestamp = STUB_TIMESTAMP }) => {
  assert(memory, 'Memory is required');
  const result = await handle({
    options: {
      Tags: [{ name: 'Action', value: 'Balances' }],
    },
    timestamp,
    memory,
  });

  const balancesData = result.Messages?.[0]?.Data;
  if (!balancesData) {
    const { Memory, ...rest } = result;
    assert(false, `Something went wrong: ${JSON.stringify(rest, null, 2)}`);
  }
  const balances = JSON.parse(result.Messages?.[0]?.Data);
  return balances;
};

export const getBalance = async ({
  address,
  memory,
  timestamp = STUB_TIMESTAMP,
}) => {
  const result = await handle({
    options: {
      Tags: [
        { name: 'Action', value: 'Balance' },
        { name: 'Address', value: address },
      ],
    },
    timestamp,
    mem: memory,
  });
  // enforce the token.lua "spec" as defined by https://github.com/permaweb/aos/blob/15dd81ee596518e2f44521e973b8ad1ce3ee9945/blueprints/token.lua
  assert(
    ['Action', 'Balance', 'Account', 'Ticker'].every((tag) =>
      result.Messages[0].Tags.map((t) => t.name).includes(tag),
    ),
    `Tags are not in compliance with the token.lua spec. ${JSON.stringify(result.Messages[0].Tags, null, 2)}`,
  );
  assert(
    typeof result.Messages[0].Data === 'string' &&
      !isNaN(Number(result.Messages[0].Data)),
    'Balance is invalid. It is not a string which is out of compliance with the token.lua spec',
  );
  const balance = JSON.parse(result.Messages[0].Data);
  return balance;
};

export const transfer = async ({
  recipient = STUB_ADDRESS,
  quantity = initialOperatorStake,
  memory = startMemory,
  cast = false,
  timestamp = STUB_TIMESTAMP,
} = {}) => {
  if (quantity === 0) {
    // Nothing to do
    return memory;
  }

  const transferResult = await handle({
    options: {
      From: PROCESS_OWNER,
      Owner: PROCESS_OWNER,
      Tags: [
        { name: 'Action', value: 'Transfer' },
        { name: 'Recipient', value: recipient },
        { name: 'Quantity', value: quantity },
        { name: 'Cast', value: cast },
      ],
      Timestamp: timestamp,
    },
    mem: memory,
  });
  assertNoResultError(transferResult);
  return transferResult.Memory;
};

export const createVault = async ({
  memory = startMemory,
  from = PROCESS_OWNER,
  quantity,
  lockLengthMs,
  vaultId,
  msgId,
  timestamp = STUB_TIMESTAMP,
  shouldAssertNoResultError = true,
}) => {
  const id = msgId || vaultId || DEFAULT_HANDLE_OPTIONS.Id;
  const result = await handle({
    options: {
      From: from,
      Owner: PROCESS_OWNER,
      Tags: [
        { name: 'Action', value: 'Create-Vault' },
        { name: 'Quantity', value: String(quantity) },
        { name: 'Lock-Length', value: String(lockLengthMs) },
        { name: 'Vault-Id', value: id },
      ],
      Timestamp: timestamp,
      Id: id,
    },
    mem: memory,
  });
  if (shouldAssertNoResultError) {
    assertNoResultError(result);
  }
  return { result, memory: result.Memory };
};

export const createVaultedTransfer = async ({
  memory = startMemory,
  from = PROCESS_OWNER,
  recipient,
  quantity,
  lockLengthMs,
  vaultId,
  msgId,
  revokable = false,
  allowUnsafeAddresses = false,
  timestamp = STUB_TIMESTAMP,
  shouldAssertNoResultError = true,
}) => {
  const id = msgId || vaultId || DEFAULT_HANDLE_OPTIONS.Id;
  const result = await handle({
    options: {
      From: from,
      Owner: PROCESS_OWNER,
      Tags: [
        { name: 'Action', value: 'Vaulted-Transfer' },
        { name: 'Recipient', value: recipient },
        { name: 'Quantity', value: String(quantity) },
        { name: 'Lock-Length', value: String(lockLengthMs) },
        { name: 'Vault-Id', value: id },
        { name: 'Revokable', value: revokable ? 'true' : 'false' },
        { name: 'Allow-Unsafe-Addresses', value: allowUnsafeAddresses ? 'true' : 'false' },
      ],
      Timestamp: timestamp,
      Id: id,
    },
    mem: memory,
  });
  if (shouldAssertNoResultError) {
    assertNoResultError(result);
  }
  return { result, memory: result.Memory };
};

export const getVault = async ({
  memory = startMemory,
  address,
  vaultId,
  timestamp = STUB_TIMESTAMP,
  assertNoResultError: shouldAssertNoResultError = true,
}) => {
  const result = await handle({
    options: {
      Tags: [
        { name: 'Action', value: 'Vault' },
        { name: 'Address', value: address },
        { name: 'Vault-Id', value: vaultId },
      ],
      Timestamp: timestamp,
    },
    mem: memory,
  });
  if (shouldAssertNoResultError) {
    assertNoResultError(result);
  }
  // Check if vault exists
  const data = result.Messages[0]?.Data;
  if (data === 'Vault not found' || !data) {
    return undefined;
  }
  return JSON.parse(data);
};

export const getVaults = async ({
  memory = startMemory,
  timestamp = STUB_TIMESTAMP,
}) => {
  const result = await handle({
    options: {
      Tags: [
        { name: 'Action', value: 'Vaults' },
      ],
      Timestamp: timestamp,
    },
    mem: memory,
  });
  assertNoResultError(result);
  return JSON.parse(result.Messages[0].Data);
};

export const getInfo = async ({
  memory = startMemory,
  timestamp = STUB_TIMESTAMP,
}) => {
  const result = await handle({
    options: {
      Tags: [
        { name: 'Action', value: 'Info' },
      ],
      Timestamp: timestamp,
    },
    mem: memory,
  });
  assertNoResultError(result);
  return { result, memory: result.Memory };
};

export const extendVault = async ({
  memory = startMemory,
  from = PROCESS_OWNER,
  vaultId,
  extendLengthMs,
  timestamp = STUB_TIMESTAMP,
}) => {
  const result = await handle({
    options: {
      From: from,
      Owner: PROCESS_OWNER,
      Tags: [
        { name: 'Action', value: 'Extend-Vault' },
        { name: 'Vault-Id', value: vaultId },
        { name: 'Extend-Length', value: String(extendLengthMs) },
      ],
      Timestamp: timestamp,
    },
    mem: memory,
  });
  assertNoResultError(result);
  return { result, memory: result.Memory };
};

export const increaseVault = async ({
  memory = startMemory,
  from = PROCESS_OWNER,
  vaultId,
  quantity,
  timestamp = STUB_TIMESTAMP,
}) => {
  const result = await handle({
    options: {
      From: from,
      Owner: PROCESS_OWNER,
      Tags: [
        { name: 'Action', value: 'Increase-Vault' },
        { name: 'Vault-Id', value: vaultId },
        { name: 'Quantity', value: String(quantity) },
      ],
      Timestamp: timestamp,
    },
    mem: memory,
  });
  assertNoResultError(result);
  return { result, memory: result.Memory };
};

export const revokeVault = async ({
  memory = startMemory,
  from = PROCESS_OWNER,
  recipient,
  vaultId,
  timestamp = STUB_TIMESTAMP,
}) => {
  const result = await handle({
    options: {
      From: from,
      Owner: PROCESS_OWNER,
      Tags: [
        { name: 'Action', value: 'Revoke-Vault' },
        { name: 'Recipient', value: recipient },
        { name: 'Vault-Id', value: vaultId },
      ],
      Timestamp: timestamp,
    },
    mem: memory,
  });
  assertNoResultError(result);
  return { result, memory: result.Memory };
};

export const getPaginatedVaults = async ({
  memory = startMemory,
  cursor,
  limit,
  sortBy,
  sortOrder,
  timestamp = STUB_TIMESTAMP,
}) => {
  const tags = [{ name: 'Action', value: 'Paginated-Vaults' }];
  if (cursor) tags.push({ name: 'Cursor', value: cursor });
  if (limit) tags.push({ name: 'Limit', value: String(limit) });
  if (sortBy) tags.push({ name: 'Sort-By', value: sortBy });
  if (sortOrder) tags.push({ name: 'Sort-Order', value: sortOrder });

  const result = await handle({
    options: {
      Tags: tags,
      Timestamp: timestamp,
    },
    mem: memory,
  });
  assertNoResultError(result);
  return JSON.parse(result.Messages[0].Data);
};
