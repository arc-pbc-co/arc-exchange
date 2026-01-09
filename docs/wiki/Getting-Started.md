# Getting Started

This guide will help you set up the ARC Exchange development environment.

## Prerequisites

Before you begin, ensure you have the following installed:

| Requirement | Version | Installation |
|-------------|---------|--------------|
| Node.js | 20+ | [nodejs.org](https://nodejs.org) |
| pnpm | 9+ | `npm install -g pnpm` |
| Docker | Latest | [docker.com](https://docker.com) |
| Docker Compose | Latest | Included with Docker Desktop |
| Foundry | Latest | [getfoundry.sh](https://getfoundry.sh) |

### Install Foundry

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/arc-pbc-co/arc-exchange.git
cd arc-exchange
```

### 2. Install Dependencies

```bash
pnpm install
```

### 3. Set Up Environment Variables

```bash
cp .env.example .env
```

Edit `.env` with your values:

```env
# Database
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/arc_exchange?schema=public"

# JWT (change in production!)
JWT_SECRET="your-secure-random-string"
JWT_EXPIRES_IN="7d"

# API Server
PORT=3001
CORS_ORIGIN="http://localhost:3000"

# Frontend
NEXT_PUBLIC_API_URL="http://localhost:3001"
NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID="your_project_id"

# Blockchain
POLYGON_RPC_URL="https://polygon-rpc.com"
POLYGON_AMOY_RPC_URL="https://rpc-amoy.polygon.technology"

# Contract Addresses (after deployment)
NEXT_PUBLIC_ARC_TOKEN_ADDRESS=""
NEXT_PUBLIC_PROJECT_POOL_ADDRESS=""
NEXT_PUBLIC_MARKETPLACE_ADDRESS=""
NEXT_PUBLIC_USDC_ADDRESS="0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359"
```

### 4. Start Infrastructure

Start PostgreSQL and local Ethereum node:

```bash
docker-compose up -d
```

This starts:
- **PostgreSQL** on `localhost:5432`
- **Anvil** (local Ethereum) on `localhost:8545`

### 5. Initialize Database

Generate Prisma client and push schema:

```bash
pnpm --filter @arc-exchange/api db:generate
pnpm --filter @arc-exchange/api db:push
```

### 6. Install Contract Dependencies

```bash
cd contracts
forge install OpenZeppelin/openzeppelin-contracts --no-git
forge install foundry-rs/forge-std --no-git
cd ..
```

### 7. Deploy Contracts Locally

```bash
pnpm --filter @arc-exchange/contracts deploy:local
```

Note the deployed contract addresses and update your `.env` file.

### 8. Start Development Servers

Start both frontend and backend:

```bash
pnpm dev
```

Or start individually:

```bash
# Terminal 1 - Backend
pnpm dev:api

# Terminal 2 - Frontend
pnpm dev:web
```

Access the application:
- **Frontend**: http://localhost:3000
- **API**: http://localhost:3001
- **API Docs**: http://localhost:3001/api/docs

## Project Scripts

### Root Scripts

| Command | Description |
|---------|-------------|
| `pnpm dev` | Start all dev servers in parallel |
| `pnpm dev:web` | Start frontend only |
| `pnpm dev:api` | Start backend only |
| `pnpm build` | Build all packages |
| `pnpm test` | Run all tests |
| `pnpm lint` | Lint all packages |
| `pnpm typecheck` | Type check all packages |
| `pnpm format` | Format code with Prettier |
| `pnpm clean` | Clean all build outputs |

### API Scripts

| Command | Description |
|---------|-------------|
| `pnpm --filter @arc-exchange/api dev` | Start API in watch mode |
| `pnpm --filter @arc-exchange/api build` | Build API |
| `pnpm --filter @arc-exchange/api db:generate` | Generate Prisma client |
| `pnpm --filter @arc-exchange/api db:push` | Push schema to database |
| `pnpm --filter @arc-exchange/api db:migrate` | Run migrations |
| `pnpm --filter @arc-exchange/api db:studio` | Open Prisma Studio |

### Contract Scripts

| Command | Description |
|---------|-------------|
| `pnpm --filter @arc-exchange/contracts build` | Build contracts |
| `pnpm --filter @arc-exchange/contracts test` | Run contract tests |
| `pnpm --filter @arc-exchange/contracts deploy:local` | Deploy to Anvil |

## Development Workflow

### 1. Making Changes

1. Create a feature branch
2. Make your changes
3. Run type checking: `pnpm typecheck`
4. Run linting: `pnpm lint`
5. Run tests: `pnpm test`
6. Commit and push

### 2. Database Changes

1. Update `apps/api/prisma/schema.prisma`
2. Generate migration: `pnpm --filter @arc-exchange/api db:migrate`
3. Test migration locally
4. Commit schema and migration files

### 3. Contract Changes

1. Update contracts in `contracts/src/`
2. Run tests: `pnpm --filter @arc-exchange/contracts test`
3. Deploy locally: `pnpm --filter @arc-exchange/contracts deploy:local`
4. Update contract addresses in `.env`
5. Regenerate types if needed

### 4. Adding Dependencies

```bash
# Add to specific package
pnpm --filter @arc-exchange/web add <package>
pnpm --filter @arc-exchange/api add <package>

# Add to root (dev only)
pnpm add -D -w <package>
```

## Troubleshooting

### Database Connection Issues

```bash
# Check if PostgreSQL is running
docker-compose ps

# View logs
docker-compose logs postgres

# Restart PostgreSQL
docker-compose restart postgres
```

### Port Already in Use

```bash
# Find process on port 3000
lsof -i :3000

# Kill process
kill -9 <PID>
```

### Prisma Client Not Generated

```bash
pnpm --filter @arc-exchange/api db:generate
```

### Contract Compilation Errors

```bash
# Update Foundry
foundryup

# Clean and rebuild
cd contracts
forge clean
forge build
```

### Node Modules Issues

```bash
# Clean and reinstall
rm -rf node_modules
rm -rf apps/*/node_modules
rm -rf packages/*/node_modules
pnpm install
```

## Next Steps

- Read the [Architecture Overview](./Architecture.md)
- Explore [Smart Contracts](./Smart-Contracts.md)
- Check the [API Reference](./API-Reference.md)
- Review the [Development Guide](./Development-Guide.md)
