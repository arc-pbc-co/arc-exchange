# Architecture Overview

## System Architecture

ARC Exchange follows a modular monorepo architecture with clear separation between frontend, backend, and blockchain components.

```
┌──────────────────────────────────────────────────────────────────────────┐
│                              FRONTEND                                     │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │                    Next.js 14 Web App                              │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐  │  │
│  │  │  RainbowKit  │  │    wagmi     │  │      React Query         │  │  │
│  │  │  (Wallet UI) │  │  (Web3 Hooks)│  │   (Server State)         │  │  │
│  │  └──────────────┘  └──────────────┘  └──────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────┘
                │                                          │
                │ REST API                                 │ JSON-RPC
                ▼                                          ▼
┌──────────────────────────────┐          ┌────────────────────────────────┐
│         BACKEND              │          │        POLYGON BLOCKCHAIN       │
│  ┌────────────────────────┐  │          │  ┌──────────────────────────┐  │
│  │      NestJS API        │  │          │  │     Smart Contracts      │  │
│  │  ┌─────────────────┐   │  │          │  │  ┌────────────────────┐  │  │
│  │  │ Auth (SIWE/JWT) │   │  │          │  │  │    ArcToken        │  │  │
│  │  ├─────────────────┤   │  │          │  │  │    (ERC-20)        │  │  │
│  │  │ Users/KYC       │   │  │          │  │  ├────────────────────┤  │  │
│  │  ├─────────────────┤   │  │◀────────▶│  │  │   ProjectPool      │  │  │
│  │  │ Pools           │   │  │          │  │  │   (ERC-1155)       │  │  │
│  │  ├─────────────────┤   │  │          │  │  ├────────────────────┤  │  │
│  │  │ Investments     │   │  │          │  │  │   Marketplace      │  │  │
│  │  └─────────────────┘   │  │          │  │  ├────────────────────┤  │  │
│  │                        │  │          │  │  │     Reserve        │  │  │
│  │  ┌─────────────────┐   │  │          │  │  └────────────────────┘  │  │
│  │  │   Prisma ORM    │   │  │          │  └──────────────────────────┘  │
│  │  └────────┬────────┘   │  │          └────────────────────────────────┘
│  └───────────│────────────┘  │
│              ▼               │
│  ┌────────────────────────┐  │
│  │     PostgreSQL         │  │
│  └────────────────────────┘  │
└──────────────────────────────┘
```

## Component Breakdown

### Frontend (apps/web)

The frontend is a Next.js 14 application using the App Router.

| Component | Purpose |
|-----------|---------|
| `src/app/` | Next.js App Router pages and layouts |
| `src/components/` | Reusable React components |
| `src/providers/` | Context providers (wagmi, React Query) |
| `src/lib/` | Utility functions and configurations |

**Key Dependencies:**
- **Next.js 14**: React framework with App Router
- **wagmi v2**: React hooks for Ethereum
- **viem**: TypeScript Ethereum library
- **RainbowKit v2**: Wallet connection UI
- **TanStack Query v5**: Server state management
- **Tailwind CSS**: Utility-first styling
- **Zustand**: Client state management

### Backend (apps/api)

The backend is a NestJS application providing REST APIs.

| Module | Purpose |
|--------|---------|
| `AuthModule` | SIWE authentication and JWT issuance |
| `UsersModule` | User profile and KYC management |
| `PoolsModule` | Investment pool CRUD operations |
| `InvestmentsModule` | Investment tracking and portfolio |
| `PrismaModule` | Database access layer |

**Key Dependencies:**
- **NestJS 10**: Node.js framework
- **Prisma 5**: Type-safe ORM
- **Passport/JWT**: Authentication
- **siwe**: Sign-In with Ethereum
- **ethers v6**: Ethereum interactions
- **class-validator**: DTO validation

### Smart Contracts (contracts/)

Solidity smart contracts built with Foundry.

| Contract | Standard | Purpose |
|----------|----------|---------|
| `ArcToken` | ERC-20 | Platform utility token |
| `ProjectPool` | ERC-1155 | Multi-token pool shares |
| `Marketplace` | Custom | Primary sales with USDC |
| `Reserve` | Custom | Escrow and distributions |

### Shared Packages (packages/)

| Package | Purpose |
|---------|---------|
| `@arc-exchange/shared` | Types, constants, utilities |
| `@arc-exchange/contract-types` | Contract ABIs and TypeScript types |

## Data Flow

### Authentication Flow

```
User                    Frontend                 Backend
 │                         │                        │
 │  1. Click Connect       │                        │
 │────────────────────────▶│                        │
 │                         │  2. Request Nonce      │
 │                         │───────────────────────▶│
 │                         │                        │ 3. Generate & Store Nonce
 │                         │◀───────────────────────│
 │  4. Sign Message        │                        │
 │◀────────────────────────│                        │
 │                         │  5. Verify Signature   │
 │                         │───────────────────────▶│
 │                         │                        │ 6. Validate & Create JWT
 │                         │◀───────────────────────│
 │  7. Authenticated       │                        │
 │◀────────────────────────│                        │
```

### Investment Purchase Flow

```
User                    Frontend          Backend            Blockchain
 │                         │                 │                    │
 │  1. Select Pool         │                 │                    │
 │────────────────────────▶│                 │                    │
 │                         │  2. Check Verification              │
 │                         │────────────────▶│                    │
 │                         │◀────────────────│                    │
 │  3. Approve USDC        │                 │                    │
 │◀────────────────────────│                 │                    │
 │  4. Sign Approval       │                 │                    │
 │────────────────────────▶│                 │                    │
 │                         │  5. Approve Tx ────────────────────▶│
 │                         │                 │                    │
 │  6. Purchase Tokens     │                 │                    │
 │────────────────────────▶│                 │                    │
 │                         │  7. Purchase Tx ────────────────────▶│
 │                         │                 │      8. Mint Tokens│
 │                         │                 │◀────────────────────│
 │                         │  9. Record Investment               │
 │                         │────────────────▶│                    │
 │ 10. Confirmation        │                 │                    │
 │◀────────────────────────│                 │                    │
```

## Security Architecture

### Access Control

| Layer | Mechanism |
|-------|-----------|
| Frontend | Wallet connection required |
| API | JWT authentication with SIWE |
| Smart Contracts | Role-based (Admin, Minter, Verifier) |
| Token Transfers | Verified investor whitelist |

### Smart Contract Roles

```
DEFAULT_ADMIN_ROLE
    │
    ├── ADMIN_ROLE (Pool management, settings)
    │
    ├── MINTER_ROLE (Token minting)
    │
    ├── PAUSER_ROLE (Emergency pause)
    │
    └── VERIFIER_ROLE (Investor verification)
```

### Investor Verification

1. User connects wallet
2. User completes KYC with external provider
3. Admin verifies and approves in backend
4. Backend calls `verifyInvestor()` on ProjectPool contract
5. User can now receive and transfer pool tokens

## Deployment Architecture

### Development

```
Docker Compose
├── PostgreSQL (localhost:5432)
└── Anvil (localhost:8545) - Local Ethereum node
```

### Production (Recommended)

```
┌─────────────────┐
│   Cloudflare    │
│   (CDN/WAF)     │
└────────┬────────┘
         │
    ┌────┴────┐
    ▼         ▼
┌───────┐ ┌───────┐
│Vercel │ │Railway│
│(Web)  │ │(API)  │
└───────┘ └───┬───┘
              │
         ┌────┴────┐
         ▼         ▼
    ┌────────┐ ┌─────────┐
    │Supabase│ │ Polygon │
    │(Postgres)│(Mainnet)│
    └────────┘ └─────────┘
```
