# ARC Exchange

Blockchain-based impact investment marketplace on Polygon. Enables tokenization of real-world assets into tradeable ERC-1155 NFTs for accredited US investors.

## Architecture

```
arc-exchange/
├── apps/
│   ├── web/          # Next.js 14 frontend
│   └── api/          # NestJS backend
├── packages/
│   ├── shared/       # Shared types, utils, constants
│   └── contract-types/  # Contract ABIs and types
├── contracts/        # Solidity smart contracts (Foundry)
└── docker-compose.yml
```

## Prerequisites

- Node.js 20+
- pnpm 9+
- Docker & Docker Compose
- Foundry (for smart contracts)

## Quick Start

### 1. Install dependencies

```bash
pnpm install
```

### 2. Set up environment variables

```bash
cp .env.example .env
# Edit .env with your values
```

### 3. Start infrastructure

```bash
docker-compose up -d
```

### 4. Initialize database

```bash
pnpm --filter @arc-exchange/api db:push
```

### 5. Start development servers

```bash
# Start both frontend and backend
pnpm dev

# Or start individually
pnpm dev:web   # Frontend on http://localhost:3000
pnpm dev:api   # Backend on http://localhost:3001
```

## Smart Contracts

### Install Foundry dependencies

```bash
cd contracts
forge install OpenZeppelin/openzeppelin-contracts --no-git
forge install foundry-rs/forge-std --no-git
```

### Build contracts

```bash
pnpm --filter @arc-exchange/contracts build
```

### Run tests

```bash
pnpm --filter @arc-exchange/contracts test
```

### Deploy (local Anvil)

```bash
# Start local node (via docker-compose or directly)
anvil

# Deploy
pnpm --filter @arc-exchange/contracts deploy:local
```

## Project Structure

### Apps

- **web**: Next.js 14 app with App Router, Tailwind CSS, wagmi/viem for Web3
- **api**: NestJS API with Prisma ORM, JWT auth, SIWE authentication

### Packages

- **shared**: Common types, constants, and utility functions
- **contract-types**: Generated TypeScript types from contract ABIs

### Contracts

- **ArcToken.sol**: ERC-20 platform token
- **ProjectPool.sol**: ERC-1155 multi-token for pool shares with investor verification
- **Marketplace.sol**: Primary sales marketplace for pool tokens

## Key Features

- Wallet authentication via Sign-In with Ethereum (SIWE)
- Accredited investor verification (KYC/AML integration ready)
- ERC-1155 pool tokens with transfer restrictions
- USDC payments for pool token purchases
- Admin-controlled pool creation and management

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | Next.js 14, React 18, Tailwind CSS |
| Web3 | wagmi, viem, RainbowKit |
| Backend | NestJS, Prisma, PostgreSQL |
| Blockchain | Polygon, Solidity 0.8.23, Foundry |
| Auth | JWT, SIWE |

## API Documentation

Swagger docs available at `http://localhost:3001/api/docs` when running the API.

## License

Private - All rights reserved.
