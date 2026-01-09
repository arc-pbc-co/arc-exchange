# ARC Exchange Wiki

Welcome to the ARC Exchange documentation. ARC Exchange is a blockchain-based impact investment marketplace built on Polygon, enabling tokenization of real-world assets into tradeable ERC-1155 NFTs for accredited US investors.

## Quick Navigation

- [Architecture Overview](./Architecture.md)
- [Smart Contracts](./Smart-Contracts.md)
- [API Reference](./API-Reference.md)
- [Frontend Application](./Frontend.md)
- [Database Schema](./Database-Schema.md)
- [Getting Started](./Getting-Started.md)
- [Development Guide](./Development-Guide.md)

## Project Overview

### What is ARC Exchange?

ARC Exchange is a platform that bridges traditional impact investments with blockchain technology. It allows:

- **Asset Tokenization**: Real-world investment opportunities (real estate, infrastructure, clean energy, etc.) are tokenized as ERC-1155 NFTs
- **Accredited Investor Access**: Only KYC-verified, accredited US investors can participate
- **USDC Payments**: All transactions use USDC stablecoin for predictable pricing
- **Dividend Distributions**: Automated coupon/dividend distributions to token holders

### Key Features

| Feature | Description |
|---------|-------------|
| Wallet Authentication | Sign-In with Ethereum (SIWE) for secure, decentralized login |
| KYC/Accreditation | Integration-ready verification system |
| Investment Pools | Tokenized real-world asset pools with yield rates |
| Primary Marketplace | Purchase pool tokens directly from the platform |
| Dividend Claims | Claim periodic distributions based on token holdings |
| Transfer Restrictions | Compliant token transfers only between verified investors |

### Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | Next.js 14, React 18, Tailwind CSS, RainbowKit |
| Web3 | wagmi, viem, Sign-In with Ethereum |
| Backend | NestJS 10, Prisma ORM, PostgreSQL |
| Blockchain | Polygon (Mainnet/Amoy), Solidity 0.8.28, Foundry |
| Smart Contracts | ERC-20, ERC-1155, OpenZeppelin |

## Repository Structure

```
arc-exchange/
├── apps/
│   ├── web/              # Next.js 14 frontend
│   └── api/              # NestJS backend API
├── packages/
│   ├── shared/           # Shared types, utils, constants
│   └── contract-types/   # Contract ABIs and TypeScript types
├── contracts/            # Solidity smart contracts (Foundry)
│   ├── src/              # Contract source files
│   ├── test/             # Contract tests
│   └── script/           # Deployment scripts
├── docs/                 # Documentation
└── docker-compose.yml    # Local development infrastructure
```

## Investment Flow

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  1. User        │     │  2. KYC         │     │  3. Browse      │
│  Connects       │────▶│  Verification   │────▶│  Investment     │
│  Wallet         │     │  (Accredited)   │     │  Pools          │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                                         │
                                                         ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  6. Claim       │     │  5. Receive     │     │  4. Purchase    │
│  Dividends      │◀────│  ERC-1155       │◀────│  with USDC      │
│  (USDC)         │     │  Pool Tokens    │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

## Getting Help

- Check the [Development Guide](./Development-Guide.md) for setup instructions
- Review [API Reference](./API-Reference.md) for endpoint documentation
- See [Smart Contracts](./Smart-Contracts.md) for blockchain integration details
