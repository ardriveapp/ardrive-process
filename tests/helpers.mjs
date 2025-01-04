import AoLoader from '@permaweb/ao-loader';
import {
  AOS_WASM,
  AO_LOADER_HANDLER_ENV,
  AO_LOADER_OPTIONS,
  DEFAULT_HANDLE_OPTIONS,
  BUNDLED_SOURCE_CODE,
  STUB_TIMESTAMP
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
    memory,
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
    memory,
  });
  assertNoResultError(transferResult);
  return transferResult.Memory;
};
