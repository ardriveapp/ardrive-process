import assert from 'node:assert';
import { ARDRIVEToMARDRIVE, getBalances, handle } from './helpers.mjs';

function assertValidBalance(balance, expectedMin = 1) {
  assert(
    Number.isInteger(balance) &&
      balance >= expectedMin &&
      balance <= 1_000_000_000_000_000,
    `Invariant violated: balance ${balance} is invalid`,
  );
}

function assertValidAddress(address) {
  assert(address.length > 0, `Invariant violated: address ${address} is empty`);
}

function assertValidTimestampsAtTimestamp({
  startTimestamp,
  endTimestamp,
  timestamp,
}) {
  assert(
    startTimestamp <= timestamp,
    `Invariant violated: startTimestamp ${startTimestamp} is in the future`,
  );
  assert(
    endTimestamp === null || endTimestamp > startTimestamp,
    `Invariant violated: endTimestamp of ${endTimestamp} is not greater than startTimestamp ${startTimestamp}`,
  );
}

async function assertNoBalanceInvariants({ timestamp, memory }) {
  // Assert all balances are >= 0 and all belong to valid addresses
  const balances = await getBalances({
    memory,
    timestamp,
  });
  for (const [address, balance] of Object.entries(balances)) {
    assertValidBalance(balance, 0);
    assertValidAddress(address);
  }
}

async function assertNoTotalSupplyInvariants({ timestamp, memory }) {
  const supplyResult = await handle({
    options: {
      Tags: [
        {
          name: 'Action',
          value: 'Total-Supply',
        },
      ],
      Timestamp: timestamp,
    },
    memory,
  });

  // assert no errors
  assert.deepEqual(supplyResult.Messages?.[0]?.Error, undefined);
  // assert correct tag in message by finding the index of the tag in the message
  const notice = supplyResult.Messages?.[0]?.Tags?.find(
    (tag) => tag.name === 'Action' && tag.value === 'Total-Supply',
  );
  assert.ok(notice, 'should have a Total-Supply tag');

  const supplyData = JSON.parse(supplyResult.Messages?.[0]?.Data);

  assert.ok(
    supplyData.total === ARDRIVEToMARDRIVE(10000000),
    'total supply should be 10,000,000,000,000 mARDRIVE but was ' +
      supplyData.total,
  );
  assertValidBalance(supplyData.circulating, 0);
  assertValidBalance(supplyData.locked, 0);
  assertValidBalance(supplyData.staked, 0);
  assertValidBalance(supplyData.delegated, 0);
  assertValidBalance(supplyData.withdrawn, 0);
  assertValidBalance(supplyData.protocolBalance, 0);
}

export async function assertNoInvariants({ timestamp, memory }) {
  await assertNoBalanceInvariants({ timestamp, memory });
  await assertNoTotalSupplyInvariants({ timestamp, memory });
}
