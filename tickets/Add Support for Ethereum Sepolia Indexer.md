Add Support for Ethereum Sepolia Indexer 

This task involves integrating the Ethereum Sepolia testnet as a supported EVM-compatible chain within the WDK Indexer system. The integration is limited to the USDT0 token, which will be monitored for balance and transfer activity. This setup supports testing and development efforts that rely on testnet environments.

Token address:
USDT0: 0xd077A400968890Eacc75cdc901F0356c943e4fDbfDb

Scope includes:
Setting up an EVM-based indexer worker for the Ethereum Sepolia testnet using wdk-indexer-wrk-evm.
Configuring the worker to index the USDT0 token at the provided address.
Ensuring the indexer announces under the topic sepolia+usdt0 on HyperDHT.
Deploying and validating the worker in the appropriate environment 
Confirming token data can be queried via WDK App Nodes.
Incorporating any testnet-specific RPC, network configurations if needed (infura quicknode etc should support it)

Acceptance Criteria:
A new indexer worker for sepolia+usdt0 is operational and syncing blocks from the Ethereum Sepolia network.
The worker indexes token balances and transfers for USDT0 at the specified address.
Indexer announces correctly on the DHT and is discoverable by App Nodes.
WDK API returns valid responses for token balance and transfer endpoints for Sepolia addresses.
Deployment and functionality are validated in a staging/test environment.
Relevant configuration and deployment instructions are documented.

