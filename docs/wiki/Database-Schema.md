# Database Schema

ARC Exchange uses PostgreSQL with Prisma ORM. The schema is defined in `apps/api/prisma/schema.prisma`.

## Entity Relationship Diagram

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│      User       │────▶│  KycVerification │     │    AdminUser    │
└────────┬────────┘     └─────────────────┘     └────────┬────────┘
         │                                               │
         │ 1:N                                          │ 1:N
         ▼                                              ▼
┌─────────────────┐                            ┌─────────────────┐
│   Investment    │◀───────────────────────────│      Pool       │
└────────┬────────┘         N:1                └────────┬────────┘
         │                                              │
         │ 1:N                                         │ 1:N
         ▼                                              ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│DistributionClaim│◀────│  Distribution   │◀────│  ReserveOp      │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

## Core Models

### User

Users authenticated via wallet addresses.

| Column | Type | Description |
|--------|------|-------------|
| `id` | String (CUID) | Primary key |
| `walletAddress` | String | Ethereum address (unique, lowercase) |
| `email` | String? | Optional email (unique) |
| `displayName` | String? | Display name |
| `avatarUrl` | String? | Avatar image URL |
| `isActive` | Boolean | Account active status |
| `createdAt` | DateTime | Creation timestamp |
| `updatedAt` | DateTime | Last update timestamp |

**Relations:**
- `kycVerification` → KycVerification (1:1)
- `investments` → Investment[] (1:N)
- `nonces` → AuthNonce[] (1:N)
- `transactions` → Transaction[] (1:N)
- `distributionClaims` → DistributionClaim[] (1:N)
- `notifications` → Notification[] (1:N)
- `watchlist` → PoolWatchlist[] (1:N)

---

### AdminUser

Platform administrators (separate from wallet users).

| Column | Type | Description |
|--------|------|-------------|
| `id` | String (CUID) | Primary key |
| `email` | String | Admin email (unique) |
| `passwordHash` | String | Hashed password |
| `firstName` | String | First name |
| `lastName` | String | Last name |
| `role` | AdminRole | SUPER_ADMIN, ADMIN, OPERATOR, VIEWER |
| `isActive` | Boolean | Account active status |
| `lastLoginAt` | DateTime? | Last login timestamp |

---

### KycVerification

KYC and accreditation verification records.

| Column | Type | Description |
|--------|------|-------------|
| `id` | String (CUID) | Primary key |
| `userId` | String | User ID (unique) |
| `provider` | String | Verification provider name |
| `status` | KycStatus | PENDING, IN_PROGRESS, APPROVED, etc. |
| `isAccredited` | Boolean | Accredited investor status |
| `isUsPerson` | Boolean | US person status |
| `accreditationType` | String? | income, net_worth, professional |
| `verifiedAt` | DateTime? | Verification timestamp |
| `expiresAt` | DateTime? | Expiration timestamp |
| `externalId` | String? | Provider's reference ID |
| `documentIds` | String[] | Document references |
| `rawResponse` | Json? | Provider's raw response |
| `rejectionReason` | String? | Reason if rejected |
| `reviewedBy` | String? | Admin who reviewed |

**Enum - KycStatus:**
- `PENDING` - Not started
- `IN_PROGRESS` - Verification underway
- `UNDER_REVIEW` - Manual review needed
- `APPROVED` - Verified and approved
- `REJECTED` - Verification failed
- `EXPIRED` - Verification expired

---

### Pool

Investment pools for tokenized assets.

| Column | Type | Description |
|--------|------|-------------|
| `id` | String (CUID) | Primary key |
| `name` | String | Pool name |
| `description` | Text | Full description |
| `shortDescription` | String? | Summary |
| `sector` | String | Investment sector |
| `subsector` | String? | Specific category |
| `targetRaise` | Decimal(18,2) | Target funding amount |
| `minInvestment` | Decimal(18,2) | Minimum per investor |
| `maxInvestment` | Decimal(18,2)? | Maximum per investor |
| `currentRaise` | Decimal(18,2) | Current funding |
| `yieldRate` | Decimal(5,2) | Expected yield (%) |
| `yieldFrequency` | YieldFrequency | Payment frequency |
| `maturityDate` | DateTime | Pool maturity date |
| `startDate` | DateTime? | Investment open date |
| `endDate` | DateTime? | Investment close date |
| `status` | PoolStatus | Current status |
| `riskRating` | RiskRating | LOW, MEDIUM, HIGH, SPECULATIVE |
| `imageUrl` | String? | Pool image |
| `bannerUrl` | String? | Banner image |
| `documents` | Json? | Document references |
| `highlights` | String[] | Key highlights |
| `metadataUri` | String? | IPFS metadata URI |
| `contractTokenId` | BigInt? | ERC-1155 token ID |
| `contractAddress` | String? | Contract address |
| `marketplaceListingId` | BigInt? | Marketplace listing ID |
| `totalSupply` | BigInt | Total tokens |
| `availableSupply` | BigInt | Available tokens |
| `pricePerToken` | Decimal(18,6) | Token price (USDC) |
| `isTransferable` | Boolean | Allow transfers |
| `location` | String? | Geographic location |
| `projectSponsor` | String? | Project issuer |

**Enum - PoolStatus:**
- `DRAFT` - Initial creation
- `PENDING_REVIEW` - Awaiting approval
- `APPROVED` - Approved, not live
- `ACTIVE` - Open for investment
- `FUNDED` - Target reached
- `CLOSED` - Manually closed
- `MATURED` - Reached maturity
- `CANCELLED` - Cancelled

**Enum - YieldFrequency:**
- `MONTHLY`
- `QUARTERLY`
- `SEMI_ANNUAL`
- `ANNUAL`
- `AT_MATURITY`

---

### Investment

User investments in pools.

| Column | Type | Description |
|--------|------|-------------|
| `id` | String (CUID) | Primary key |
| `userId` | String | User ID |
| `poolId` | String | Pool ID |
| `tokenAmount` | BigInt | Current token balance |
| `totalInvestedUsd` | Decimal(18,2) | Total invested |
| `averagePriceUsd` | Decimal(18,6) | Average purchase price |
| `totalClaimedUsd` | Decimal(18,2) | Total claimed dividends |
| `status` | InvestmentStatus | ACTIVE, REDEEMED, SOLD |
| `firstPurchasedAt` | DateTime | First purchase |
| `lastPurchasedAt` | DateTime | Last purchase |

**Unique Constraint:** `(userId, poolId)`

---

### Distribution

Dividend/coupon distributions for pools.

| Column | Type | Description |
|--------|------|-------------|
| `id` | String (CUID) | Primary key |
| `poolId` | String | Pool ID |
| `title` | String | Distribution title |
| `description` | String? | Description |
| `totalAmountUsd` | Decimal(18,2) | Total distribution amount |
| `amountPerToken` | Decimal(18,8) | Amount per token |
| `snapshotTokenSupply` | BigInt | Supply at snapshot |
| `snapshotDate` | DateTime | Balance snapshot date |
| `distributionDate` | DateTime | Payment date |
| `expiresAt` | DateTime? | Claim deadline |
| `status` | DistributionStatus | Current status |
| `contractDistributionId` | BigInt? | Reserve contract ID |
| `depositTxHash` | String? | USDC deposit tx |
| `createdById` | String? | Admin who created |

**Enum - DistributionStatus:**
- `PENDING` - Created, not funded
- `FUNDED` - USDC deposited
- `ACTIVE` - Open for claiming
- `COMPLETED` - All claimed/expired
- `CANCELLED` - Cancelled
- `EXPIRED` - Past expiration

---

### DistributionClaim

Individual claim records.

| Column | Type | Description |
|--------|------|-------------|
| `id` | String (CUID) | Primary key |
| `distributionId` | String | Distribution ID |
| `investmentId` | String | Investment ID |
| `userId` | String | User ID |
| `tokenBalance` | BigInt | Balance at snapshot |
| `amountUsd` | Decimal(18,6) | Claimable amount |
| `status` | ClaimStatus | PENDING, CLAIMED, EXPIRED |
| `claimedAt` | DateTime? | Claim timestamp |
| `txHash` | String? | Claim transaction hash |

---

### Transaction

All blockchain transactions.

| Column | Type | Description |
|--------|------|-------------|
| `id` | String (CUID) | Primary key |
| `userId` | String | User ID |
| `poolId` | String? | Pool ID |
| `investmentId` | String? | Investment ID |
| `type` | TransactionType | Transaction type |
| `status` | TransactionStatus | Current status |
| `amountUsd` | Decimal(18,2)? | USD amount |
| `tokenAmount` | BigInt? | Token amount |
| `pricePerToken` | Decimal(18,6)? | Price per token |
| `platformFeeUsd` | Decimal(18,2)? | Platform fee |
| `txHash` | String? | Blockchain tx hash (unique) |
| `blockNumber` | BigInt? | Block number |
| `fromAddress` | String? | Sender address |
| `toAddress` | String? | Recipient address |
| `gasUsed` | BigInt? | Gas used |
| `gasPrice` | BigInt? | Gas price |
| `paymentMethod` | String? | usdc, wire, ach |
| `paymentId` | String? | External payment ID |
| `paymentStatus` | String? | Payment status |
| `errorMessage` | String? | Error message |
| `retryCount` | Int | Retry attempts |
| `confirmedAt` | DateTime? | Confirmation time |

**Enum - TransactionType:**
- `PURCHASE` - Primary market purchase
- `SALE` - Secondary market sale
- `TRANSFER_IN` - Received tokens
- `TRANSFER_OUT` - Sent tokens
- `CLAIM` - Distribution claim
- `DEPOSIT` - USDC deposit
- `WITHDRAWAL` - USDC withdrawal
- `REFUND` - Refund

---

## Supporting Models

### AuthNonce

SIWE authentication nonces.

| Column | Type | Description |
|--------|------|-------------|
| `id` | String (CUID) | Primary key |
| `userId` | String? | User ID (optional) |
| `nonce` | String | Unique nonce |
| `walletAddress` | String? | Pre-auth wallet |
| `expiresAt` | DateTime | Expiration time |
| `usedAt` | DateTime? | Usage timestamp |

---

### Notification

User notifications.

| Column | Type | Description |
|--------|------|-------------|
| `id` | String (CUID) | Primary key |
| `userId` | String | User ID |
| `type` | NotificationType | Notification type |
| `title` | String | Title |
| `message` | String | Message body |
| `data` | Json? | Additional data |
| `isRead` | Boolean | Read status |
| `readAt` | DateTime? | Read timestamp |

---

### AuditLog

Admin action audit trail.

| Column | Type | Description |
|--------|------|-------------|
| `id` | String (CUID) | Primary key |
| `adminUserId` | String | Admin user ID |
| `action` | String | Action name |
| `entityType` | String | Entity type |
| `entityId` | String | Entity ID |
| `changes` | Json? | Before/after values |
| `ipAddress` | String? | Client IP |
| `userAgent` | String? | Client user agent |

---

## Database Commands

### Generate Prisma Client

```bash
pnpm --filter @arc-exchange/api db:generate
```

### Push Schema Changes

```bash
pnpm --filter @arc-exchange/api db:push
```

### Run Migrations

```bash
pnpm --filter @arc-exchange/api db:migrate
```

### Open Prisma Studio

```bash
pnpm --filter @arc-exchange/api db:studio
```

---

## Indexes

Key indexes for performance:

| Table | Columns | Purpose |
|-------|---------|---------|
| `users` | `wallet_address` | Wallet lookup |
| `users` | `email` | Email lookup |
| `pools` | `status` | Status filtering |
| `pools` | `sector` | Sector filtering |
| `pools` | `contract_token_id` | Blockchain sync |
| `investments` | `user_id` | User portfolios |
| `investments` | `pool_id` | Pool investors |
| `transactions` | `tx_hash` | Tx lookup |
| `transactions` | `created_at` | Time queries |
| `audit_logs` | `created_at` | Audit queries |
