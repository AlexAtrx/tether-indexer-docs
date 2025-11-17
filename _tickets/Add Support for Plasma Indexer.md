Add Support for Plasma Indexer

The goal of this task is to integrate the Plasma blockchain as a supported EVM-compatible chain into the WDK Indexer system. This implementation should mirror the existing support provided for other EVM-based chains such as Polygon. The Plasma indexer will track token balances and transfers for specific tokens, notably USDT0 and XAUT0.
 
Token addresses:
USDT0: 0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb
XAUT0: 0x1B64B9025EEbb9A6239575dF9Ea4b9Ac46D4d193
 
Scope includes:
Creating a new indexer worker instance for the Plasma chain using wdk-indexer-wrk-evm.
Configuring the worker to handle the USDT0 and XAUT0 token contracts.
Ensuring the indexer worker publishes to the correct plasma+usdt0 and plasma+xaut0 topics over HyperDHT.
Registering and announcing the Plasma indexer in the appropriate environment (dev/staging/prod).
Verifying communication with App Nodes and proper syncing of token balances and transfers.
Including any necessary configuration in deployment scripts or templates.
 
Acceptance Criteria:
Plasma indexer is launched using the existing EVM worker base.
Both USDT0 and XAUT0 tokens are indexed correctly.
Indexer worker successfully publishes under plasma+usdt0 and plasma+xaut0 topics.
Token balance and transfer endpoints return valid data for Plasma addresses via WDK API.
Worker is deployed and validated in staging with successful synchronization.
Documentation updated to include Plasma support configuration and deployment steps.
 