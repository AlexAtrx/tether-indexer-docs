## WDK

Tether's Wallet Development Kit (WDK) is an open-source, modular, and extensible backend toolkit designed for building secure, multi-chain, self-custodial wallets. It supports multiple blockchain environments (Node.js, Bare runtime, React Native, future embedded), enabling wallet deployment across embedded devices, mobile, desktop, and servers. The WDK architecture emphasizes stateless self-custody (keys never leave user control) and vendor independence.

### Company and Product Overview

- Tether is best known for USD₮ (USDT), the largest USD-pegged stablecoin.
- The WDK is developer-first, open-source, and tailored for multi-chain wallets usable by humans, machines, and AI agents.
- It targets environments from embedded systems to mobile and desktop, offering strong TypeScript typings, modular SDK components, UI kits for React Native, and extensive documentation with ready-to-use starters.
- Use cases range from consumer wallets and DeFi apps to IoT and AI-driven finance.

### Architecture and Core Features

- Modular architecture: Composable modules each with single responsibility (wallet modules, protocol modules, core module orchestrating).
- Supports adding new chains, tokens, and protocols via dedicated modules.
- Stateless self-custody ensures private keys never leave the app; no user data is stored by WDK itself.
- Unified APIs give consistent interfaces across blockchains and protocols.
- Cross-platform compatibility: runs seamlessly from Node.js to React Native to embedded systems.

### Backend and Integration Components

- Modular SDK for wallet and protocol operations.
- Indexer API: high-performance REST API providing blockchain data (balances, token transfers, transaction history) across multiple blockchains including Bitcoin, Ethereum, Solana, TON, and more.
- UI Kits: prebuilt React Native components to build interfaces rapidly.
- Examples and starters: production-ready templates for quick wallet deployment.

### Security

- Multi-signature authentication.
- Hierarchical Deterministic (HD) wallets for secure key generation and recovery.
- End-to-end encryption to safeguard transaction data.
- Private keys remain fully controlled by the user (self-custody).
- Backup and recovery support via mnemonic seed phrases.
- The system integrates with technologies like Spark's Bitcoin Lightning infrastructure for advanced payment capabilities.

### Developer Experience

- Strong TypeScript-first focus for scalable and maintainable code.
- Modular plug-in framework for finely tuned wallet capabilities.
- Easily customizable for different use cases with simple configuration objects.
- Supports rapid development with comprehensive documentation, guides, and examples.
- Facilitates integration of DeFi features like swaps, lending, and staking.
- Designed for zero lock-in, avoiding SaaS dependencies or closed platforms.

### Ecosystem and Future-Readiness

- Supports major blockchain protocols such as Ethereum, Bitcoin, Tron, Arbitrum, Polygon, Solana, TON, and the Lightning Network.
- Enables cross-chain transfers and DeFi interactions.
- Designed with account abstraction standards for forward compatibility.
- Open-source ambition is to enable trillions of self-custodial wallets supporting humans, devices, and AI agents.

This backend context for the Tether WDK is key for a coding LLM to assist in developing the WDK backend, providing modular blockchain wallet functionality, secure transaction handling, and expandable protocol support within a developer-friendly, cross-platform environment.

# Additional Artifact

- `diagram.png`: simple, repetitive diagram; **not exhaustive** but provides helpful structure.