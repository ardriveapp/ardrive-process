import { getBalance, handle, startMemory } from './helpers.mjs';
import { afterEach, describe, it } from 'node:test';
import assert from 'node:assert';
import {
  STUB_ADDRESS,
  PROCESS_OWNER,
  STUB_TIMESTAMP,
} from '../tools/constants.mjs';
import { assertNoInvariants } from './invariants.mjs';

describe('Token Minting/Burning', async () => {
  let endingMemory;
  afterEach(() => {
    assertNoInvariants({ memory: endingMemory, timestamp: STUB_TIMESTAMP });
  });

  it('should mint tokens if process owner to self', async () => {
    const balance = await getBalance({
      address: PROCESS_OWNER,
      memory: startMemory,
    });
    assert.equal(balance, 10000000000000); // Should equal the total supply of ArDrive tokens

    const mintResult = await handle({
      options: {
        From: PROCESS_OWNER,
        Owner: PROCESS_OWNER,
        Tags: [
          { name: 'Action', value: 'Mint' },
          { name: 'Recipient', value: PROCESS_OWNER },
          { name: 'Quantity', value: 666 },
          { name: 'Cast', value: false },
        ],
      },
      mem: startMemory,
    });

    const newBalance = await getBalance({
      address: PROCESS_OWNER,
      memory: mintResult.Memory,
    });
    assert.equal(newBalance, 10000000000666); // Should equal the total supply of ArDrive tokens plus the mint

    endingMemory = mintResult.Memory
  });

  it('should mint tokens if process owner to another', async () => {
    const balance = await getBalance({
      address: STUB_ADDRESS,
      memory: startMemory,
    });
    assert.equal(balance, 0); // Should equal 0

    const mintResult = await handle({
      options: {
        From: PROCESS_OWNER,
        Owner: PROCESS_OWNER,
        Tags: [
          { name: 'Action', value: 'Mint' },
          { name: 'Recipient', value: STUB_ADDRESS },
          { name: 'Quantity', value: 666 },
          { name: 'Cast', value: false },
        ],
      },
      mem: startMemory,
    });

    const newBalance = await getBalance({
      address: STUB_ADDRESS,
      memory: mintResult.Memory,
    });
    assert.equal(newBalance, 666); // Should equal the amount minted
    endingMemory = mintResult.Memory
  });

  it('should mint tokens to an invalid recipient with Allow-Unsafe-Addresses set to true', async () => {
    const balance = await getBalance({
      address: 'INVALID-RECIPIENT',
      memory: startMemory,
    });
    assert.equal(balance, 0); // Should equal 0
    const mintResult = await handle({
        options: {
          From: PROCESS_OWNER,
          Owner: PROCESS_OWNER,
          Tags: [
            { name: 'Action', value: 'Mint' },
            { name: 'Recipient', value: "INVALID-RECIPIENT" },
            { name: 'Quantity', value: 666 },
            { name: 'Cast', value: false },
            { name: 'Allow-Unsafe-Addresses', value: true },
          ],
        },
        mem: startMemory,
    })

    const newBalance = await getBalance({
      address: 'INVALID-RECIPIENT',
      memory: mintResult.Memory,
    });
    assert.equal(newBalance, 666); // Should equal the amount minted
    endingMemory = mintResult.Memory
  })

  it('should not mint tokens to an invalid recipient', async () => {
    const mintResult = await handle({
        options: {
          From: PROCESS_OWNER,
          Owner: PROCESS_OWNER,
          Tags: [
            { name: 'Action', value: 'Mint' },
            { name: 'Recipient', value: "INVALID-RECIPIENT" },
            { name: 'Quantity', value: 1000 },
            { name: 'Cast', value: false },
          ],
        },
        mem: startMemory,
      })
      const newBalance = await getBalance({
        address: "INVALID-RECIPIENT",
        memory: mintResult.Memory,
      });
      assert.equal(newBalance, 0);
  })

  it('should not mint non-integer quantity of tokens', async () => {
    const mintResult = await handle({
        options: {
          From: PROCESS_OWNER,
          Owner: PROCESS_OWNER,
          Tags: [
            { name: 'Action', value: 'Mint' },
            { name: 'Recipient', value: STUB_ADDRESS },
            { name: 'Quantity', value: 1000.5 },
            { name: 'Cast', value: false },
          ],
        },
        mem: startMemory,
      })
      const newBalance = await getBalance({
        address: STUB_ADDRESS,
        memory: mintResult.Memory,
      });
      assert.equal(newBalance, 0);
  })

  it('should not mint tokens if not the process owner', async () => {
    const balance = await getBalance({
      address: STUB_ADDRESS,
      memory: startMemory,
    });
    assert.equal(balance, 0);

    
    const mintResult = await handle({
      options: {
        From: STUB_ADDRESS,
        Owner: STUB_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Mint' },
          { name: 'Recipient', value: STUB_ADDRESS },
          { name: 'Quantity', value: 666 },
          { name: 'Cast', value: false },
        ],
      },
      mem: startMemory,
    });

    const newBalance = await getBalance({
      address: STUB_ADDRESS,
      memory: mintResult.Memory,
    });
    assert.equal(newBalance, 0); // Should still equal zero
    endingMemory = mintResult.Memory
  });

  it('should burn tokens if the user has a balance', async () => {
    const balance = await getBalance({
      address: PROCESS_OWNER,
      memory: startMemory,
    });
    assert.equal(balance, 10000000000000); // Should equal the total supply of ArDrive tokens

    const burnResult = await handle({
      options: {
        Tags: [
          { name: 'Action', value: 'Burn' },
          { name: 'Quantity', value: 1000000000000 },
          { name: 'Cast', value: false },
        ],
      },
      mem: startMemory,
    });

    const newBalance = await getBalance({
      address: PROCESS_OWNER,
      memory: burnResult.Memory
    });
    assert.equal(newBalance, 9000000000000); // Should equal the total supply of ArDrive tokens plus the mint minus the burn quantity
    endingMemory = burnResult.Memory
  });

  it('should not burn tokens if the user does not have enough', async () => {
    const balance = await getBalance({
      address: PROCESS_OWNER,
      memory: startMemory,
    });
    assert.equal(balance, 10000000000000); // Should equal the total supply of ArDrive tokens
    const burnResult = await handle({
      options: {
        Tags: [
          { name: 'Action', value: 'Burn' },
          { name: 'Quantity', value: 10000000000001 },
          { name: 'Cast', value: false },
        ],
      },
      mem: startMemory,
    });

    const newBalance = await getBalance({
      address: PROCESS_OWNER,
      memory: burnResult.Memory
    });
    assert.equal(newBalance, 10000000000000); // Should equal the total supply of ArDrive tokens without any burning
    endingMemory = burnResult.Memory
  });

  it('should not burn tokens if quantity is not an integer', async () => {
    const balance = await getBalance({
      address: PROCESS_OWNER,
      memory: startMemory,
    });
    assert.equal(balance, 10000000000000); // Should equal the total supply of ArDrive tokens
    const burnResult = await handle({
      options: {
        Tags: [
          { name: 'Action', value: 'Burn' },
          { name: 'Quantity', value: 1.5 },
          { name: 'Cast', value: false },
        ],
      },
      mem: startMemory,
    });

    const newBalance = await getBalance({
      address: PROCESS_OWNER,
      memory: burnResult.Memory
    });
    assert.equal(newBalance, 10000000000000);
    endingMemory = burnResult.Memory
  });

  it('should correctly update the total supply after minting and burning', async () => {
    const mintResult = await handle({
      options: {
        From: PROCESS_OWNER,
        Owner: PROCESS_OWNER,
        Tags: [
          { name: 'Action', value: 'Mint' },
          { name: 'Recipient', value: STUB_ADDRESS },
          { name: 'Quantity', value: 500 },
          { name: 'Cast', value: false },
        ],
      },
      mem: startMemory,
    });
  
    const burnResult = await handle({
      options: {
        From: STUB_ADDRESS,
        Owner: STUB_ADDRESS,
        Tags: [
          { name: 'Action', value: 'Burn' },
          { name: 'Quantity', value: 100 },
          { name: 'Cast', value: false },
        ],
      },
      mem: mintResult.Memory,
    });
  
    const totalSupply = await handle({
      options: {
        Tags: [{ name: 'Action', value: 'Total-Supply' }],
      },
      mem: burnResult.Memory,
    });
  
    assert.equal(
      JSON.parse(totalSupply.Messages[0].Data),
      10000000000400, // Adjusted supply after minting and burning
      'Total supply mismatch'
    );
  });
  

});
