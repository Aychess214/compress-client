import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.5.4/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensure admin can register compression client",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const admin = accounts.get('deployer')!;
    const client = accounts.get('wallet_1')!;

    let block = chain.mineBlock([
      Tx.contractCall('compression-registry', 'register-compression-client', 
        [types.principal(client.address), types.uint(1000)], 
        admin.address
      )
    ]);

    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk().expectBool(true);
  }
});

Clarinet.test({
  name: "Prevent non-admin from registering client",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const client = accounts.get('wallet_1')!;
    const nonAdmin = accounts.get('wallet_2')!;

    let block = chain.mineBlock([
      Tx.contractCall('compression-registry', 'register-compression-client', 
        [types.principal(client.address), types.uint(1000)], 
        nonAdmin.address
      )
    ]);

    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectErr().expectUint(200);
  }
});

Clarinet.test({
  name: "Allocate compression session successfully",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const admin = accounts.get('deployer')!;
    const client = accounts.get('wallet_1')!;

    // First register the client
    let block = chain.mineBlock([
      Tx.contractCall('compression-registry', 'register-compression-client', 
        [types.principal(client.address), types.uint(1000)], 
        admin.address
      )
    ]);

    // Then allocate a session
    block = chain.mineBlock([
      Tx.contractCall('compression-registry', 'allocate-compression-session', 
        [types.principal(client.address), types.uint(100)], 
        client.address
      )
    ]);

    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk().expectUint(0);
  }
});