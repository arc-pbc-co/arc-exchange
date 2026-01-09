# Development Guide

This guide covers development practices, conventions, and workflows for ARC Exchange.

## Code Organization

### Monorepo Structure

```
arc-exchange/
├── apps/
│   ├── web/              # Next.js frontend
│   └── api/              # NestJS backend
├── packages/
│   ├── shared/           # Shared types, constants
│   └── contract-types/   # Contract ABIs
├── contracts/            # Solidity contracts
└── docs/                 # Documentation
```

### Import Aliases

| Package | Alias | Example |
|---------|-------|---------|
| web | `@/` | `import { Button } from '@/components/ui'` |
| api | `./` | `import { AuthService } from './auth/auth.service'` |
| shared | `@arc-exchange/shared` | `import { PoolStatus } from '@arc-exchange/shared'` |

## Coding Standards

### TypeScript

- Use strict mode
- Prefer `interface` over `type` for objects
- Use explicit return types for public functions
- Avoid `any` - use `unknown` if needed

```typescript
// Good
interface Pool {
  id: string;
  name: string;
  status: PoolStatus;
}

function getPool(id: string): Promise<Pool> {
  // ...
}

// Avoid
type Pool = {
  id: any;
  name: string;
}

function getPool(id) {
  // ...
}
```

### React/Next.js

- Use functional components with hooks
- Prefer server components when possible
- Use `'use client'` directive only when needed
- Extract reusable logic into custom hooks

```tsx
// Server Component (default)
export default async function PoolPage({ params }: { params: { id: string } }) {
  const pool = await fetchPool(params.id);
  return <PoolDetails pool={pool} />;
}

// Client Component (when needed)
'use client';

export function PurchaseForm({ poolId }: { poolId: string }) {
  const [amount, setAmount] = useState(0);
  // ...
}
```

### NestJS

- One module per domain
- Use DTOs for request/response validation
- Inject dependencies via constructor
- Handle errors with NestJS exceptions

```typescript
// pools.controller.ts
@Controller('pools')
export class PoolsController {
  constructor(private readonly poolsService: PoolsService) {}

  @Get(':id')
  async findOne(@Param('id') id: string): Promise<Pool> {
    return this.poolsService.findById(id);
  }

  @Post()
  @UseGuards(JwtAuthGuard)
  async create(@Body() dto: CreatePoolDto): Promise<Pool> {
    return this.poolsService.create(dto);
  }
}
```

### Solidity

- Use Solidity 0.8.28+
- Follow OpenZeppelin patterns
- Use custom errors over require strings
- Document with NatSpec comments

```solidity
/// @notice Mint pool tokens to a verified investor
/// @param to Address to receive tokens
/// @param poolId Pool ID to mint
/// @param amount Number of tokens
function mint(
    address to,
    uint256 poolId,
    uint256 amount
) external onlyRole(MINTER_ROLE) {
    if (!isVerifiedInvestor[to]) revert NotVerifiedInvestor(to);
    if (poolId >= nextPoolId) revert PoolDoesNotExist(poolId);
    _mint(to, poolId, amount, "");
}
```

## API Development

### Creating a New Endpoint

1. **Create DTO** (`module.dto.ts`):
```typescript
import { IsString, IsNumber, IsOptional } from 'class-validator';

export class CreatePoolDto {
  @IsString()
  name: string;

  @IsString()
  description: string;

  @IsNumber()
  targetRaise: number;

  @IsOptional()
  @IsString()
  imageUrl?: string;
}
```

2. **Create Service** (`module.service.ts`):
```typescript
@Injectable()
export class PoolsService {
  constructor(private prisma: PrismaService) {}

  async create(dto: CreatePoolDto): Promise<Pool> {
    return this.prisma.pool.create({
      data: {
        name: dto.name,
        description: dto.description,
        targetRaise: dto.targetRaise,
        imageUrl: dto.imageUrl,
        status: PoolStatus.DRAFT,
      },
    });
  }
}
```

3. **Create Controller** (`module.controller.ts`):
```typescript
@Controller('pools')
export class PoolsController {
  constructor(private service: PoolsService) {}

  @Post()
  @UseGuards(JwtAuthGuard)
  async create(@Body() dto: CreatePoolDto) {
    return this.service.create(dto);
  }
}
```

### Error Handling

Use NestJS built-in exceptions:

```typescript
import {
  NotFoundException,
  BadRequestException,
  ForbiddenException
} from '@nestjs/common';

// Not found
throw new NotFoundException('Pool not found');

// Invalid request
throw new BadRequestException('Invalid token amount');

// Not authorized
throw new ForbiddenException('Only accredited investors can invest');
```

## Smart Contract Development

### Writing Tests

```solidity
// test/Marketplace.t.sol
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/Marketplace.sol";

contract MarketplaceTest is Test {
    Marketplace marketplace;
    address admin = address(1);
    address user = address(2);

    function setUp() public {
        // Deploy contracts
        vm.startPrank(admin);
        // ... setup
        vm.stopPrank();
    }

    function testPurchase() public {
        vm.startPrank(user);
        // ... test
        vm.stopPrank();
    }

    function testRevertIfNotVerified() public {
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(
            Marketplace.BuyerNotVerified.selector,
            user
        ));
        marketplace.purchase(0, 10);
        vm.stopPrank();
    }
}
```

### Gas Optimization

- Use `calldata` for read-only arrays
- Pack storage variables
- Use custom errors instead of strings
- Cache storage reads in memory

```solidity
// Good
function mintBatch(
    address[] calldata recipients,  // calldata for read-only
    uint256[] calldata amounts
) external {
    uint256 len = recipients.length;  // Cache length
    for (uint256 i = 0; i < len; ) {
        _mint(recipients[i], amounts[i]);
        unchecked { ++i; }  // Unchecked increment
    }
}
```

## Database Migrations

### Creating Migrations

```bash
# After modifying schema.prisma
pnpm --filter @arc-exchange/api db:migrate
```

### Migration Best Practices

1. Keep migrations small and focused
2. Test migrations locally before deploying
3. Never modify existing migrations
4. Back up data before destructive changes

### Seeding Data

```typescript
// apps/api/prisma/seed.ts
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  // Seed admin user
  await prisma.adminUser.upsert({
    where: { email: 'admin@arcexchange.io' },
    update: {},
    create: {
      email: 'admin@arcexchange.io',
      passwordHash: '...',
      firstName: 'Admin',
      lastName: 'User',
      role: 'SUPER_ADMIN',
    },
  });

  // Seed sample pools
  // ...
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
```

## Testing

### Backend Tests

```bash
# Run all tests
pnpm --filter @arc-exchange/api test

# Run with coverage
pnpm --filter @arc-exchange/api test:cov

# Run in watch mode
pnpm --filter @arc-exchange/api test:watch
```

### Contract Tests

```bash
# Run all tests
pnpm --filter @arc-exchange/contracts test

# Run specific test file
forge test --match-path test/Marketplace.t.sol

# Run with gas report
forge test --gas-report

# Run with verbosity
forge test -vvv
```

## Environment Management

### Local Development

Use `.env` file (copied from `.env.example`):

```env
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/arc_exchange"
JWT_SECRET="dev-secret-change-in-production"
```

### Staging/Production

Use environment variables from hosting provider:
- Vercel (frontend)
- Railway/Fly.io (backend)
- Supabase (database)

## Git Workflow

### Branch Naming

| Type | Pattern | Example |
|------|---------|---------|
| Feature | `feature/<name>` | `feature/pool-details-page` |
| Bug Fix | `fix/<name>` | `fix/auth-token-expiry` |
| Chore | `chore/<name>` | `chore/update-dependencies` |

### Commit Messages

Follow conventional commits:

```
feat: add pool investment page
fix: resolve token balance calculation
docs: update API reference
chore: upgrade wagmi to v2
refactor: simplify auth service
test: add marketplace contract tests
```

### Pull Request Process

1. Create feature branch from `main`
2. Make changes and commit
3. Run checks: `pnpm typecheck && pnpm lint && pnpm test`
4. Push and create PR
5. Request review
6. Address feedback
7. Merge when approved

## Deployment

### Contract Deployment

```bash
# Deploy to testnet (Amoy)
forge script script/Deploy.s.sol --rpc-url $POLYGON_AMOY_RPC_URL --broadcast

# Verify on Polygonscan
forge verify-contract <address> src/Marketplace.sol:Marketplace --chain-id 80002
```

### Backend Deployment

1. Push to main branch
2. CI/CD builds and tests
3. Deploy to Railway/Fly.io
4. Run migrations: `pnpm db:migrate`

### Frontend Deployment

1. Push to main branch
2. Vercel auto-deploys
3. Preview deployments for PRs

## Monitoring & Debugging

### Local Debugging

```bash
# API debug mode
pnpm --filter @arc-exchange/api start:debug

# Contract traces
forge test -vvvv
```

### Production Monitoring

- Use structured logging
- Monitor error rates
- Track transaction success rates
- Set up alerts for critical failures

## Security Checklist

Before deploying:

- [ ] All environment variables are set correctly
- [ ] JWT secret is strong and unique
- [ ] Database connections use SSL
- [ ] API endpoints are properly authenticated
- [ ] Contract roles are correctly configured
- [ ] No sensitive data in logs
- [ ] Rate limiting is enabled
- [ ] Input validation is thorough
