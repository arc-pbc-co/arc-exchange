# Smart Contracts

ARC Exchange uses four main smart contracts deployed on Polygon. All contracts are written in Solidity 0.8.28 and use OpenZeppelin libraries.

## Contract Overview

| Contract | Standard | Purpose |
|----------|----------|---------|
| `ArcToken` | ERC-20 | Platform utility token with 1B max supply |
| `ProjectPool` | ERC-1155 | Multi-token contract for investment pool shares |
| `Marketplace` | Custom | Primary sales marketplace using USDC |
| `Reserve` | Custom | Escrow and dividend distribution management |

## ArcToken (ERC-20)

**Location:** `contracts/src/ArcToken.sol`

The ARC Token is the platform's utility token.

### Features

- **Max Supply Cap**: 1 billion tokens (1,000,000,000 × 10^18)
- **Burnable**: Tokens can be burned to reduce supply
- **Pausable**: All transfers can be paused in emergencies
- **Permit (EIP-2612)**: Gasless approvals via signatures
- **Role-based Minting**: Only MINTER_ROLE can create new tokens

### Roles

| Role | Permissions |
|------|-------------|
| `DEFAULT_ADMIN_ROLE` | Manage all roles |
| `MINTER_ROLE` | Mint new tokens |
| `PAUSER_ROLE` | Pause/unpause transfers |

### Key Functions

```solidity
// Mint tokens (requires MINTER_ROLE)
function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE)

// Batch mint to multiple recipients
function mintBatch(address[] calldata recipients, uint256[] calldata amounts) external onlyRole(MINTER_ROLE)

// Pause all transfers
function pause() external onlyRole(PAUSER_ROLE)

// Check remaining mintable supply
function remainingSupply() external view returns (uint256)
```

---

## ProjectPool (ERC-1155)

**Location:** `contracts/src/ProjectPool.sol`

The ProjectPool contract manages investment pool shares as ERC-1155 multi-tokens. Each token ID represents a different investment pool.

### Features

- **Multi-Token**: Each pool has a unique token ID
- **Investor Whitelist**: Only verified investors can hold tokens
- **Transfer Restrictions**: Pools can disable secondary transfers
- **Pool Metadata**: IPFS URIs for pool information
- **Max Supply per Pool**: Optional cap on tokens per pool

### Roles

| Role | Permissions |
|------|-------------|
| `DEFAULT_ADMIN_ROLE` | Manage all roles |
| `ADMIN_ROLE` | Create/update pools, burn tokens |
| `MINTER_ROLE` | Mint pool tokens |
| `PAUSER_ROLE` | Pause/unpause transfers |
| `VERIFIER_ROLE` | Add/remove verified investors |

### Pool Structure

```solidity
struct PoolInfo {
    string metadataUri;    // IPFS URI for metadata
    uint256 maxSupply;     // 0 = unlimited
    bool transferable;     // Allow secondary transfers
    bool active;           // Accept new investments
    uint256 createdAt;     // Creation timestamp
}
```

### Key Functions

```solidity
// Verify an investor (KYC approved)
function verifyInvestor(address investor) external onlyRole(VERIFIER_ROLE)

// Batch verify investors
function verifyInvestorBatch(address[] calldata investors) external onlyRole(VERIFIER_ROLE)

// Revoke investor verification
function revokeInvestor(address investor) external onlyRole(VERIFIER_ROLE)

// Create a new pool
function createPool(
    string calldata metadataUri,
    uint256 maxSupply,
    bool transferable
) external onlyRole(ADMIN_ROLE) returns (uint256 poolId)

// Mint tokens to a verified investor
function mint(
    address to,
    uint256 poolId,
    uint256 amount
) external onlyRole(MINTER_ROLE)

// Get pool information
function getPoolInfo(uint256 poolId) external view returns (
    string memory metadataUri,
    uint256 maxSupply,
    uint256 currentSupply,
    bool transferable,
    bool active,
    uint256 createdAt
)
```

### Transfer Restrictions

The `_update` hook enforces:
1. **Recipient must be verified**: `isVerifiedInvestor[to] == true`
2. **Pool must be transferable**: `pools[tokenId].transferable == true`
3. **Minting/burning exempt**: from/to `address(0)` bypasses checks

---

## Marketplace

**Location:** `contracts/src/Marketplace.sol`

The Marketplace handles primary sales of pool tokens.

### Features

- **USDC Payments**: All purchases use USDC stablecoin
- **Configurable Pricing**: Per-pool token pricing
- **Platform Fees**: Adjustable fee (max 10%)
- **Purchase Limits**: Min/max tokens per purchase
- **Time-based Sales**: Start/end timestamps

### Configuration

| Setting | Default | Max |
|---------|---------|-----|
| Platform Fee | Configurable | 10% (1000 bps) |
| Min Purchase | Per pool | - |
| Max Purchase | Per pool | - |

### Pool Listing Structure

```solidity
struct PoolListing {
    uint256 pricePerToken;  // USDC (6 decimals)
    uint256 maxSupply;      // Tokens available
    uint256 minPurchase;    // Minimum per tx
    uint256 maxPurchase;    // Maximum per tx (0 = unlimited)
    uint256 startTime;      // Sale start
    uint256 endTime;        // Sale end (0 = no end)
    bool active;            // Listing active
}
```

### Key Functions

```solidity
// List a pool for sale
function listPool(
    uint256 poolId,
    uint256 pricePerToken,
    uint256 maxSupply,
    uint256 minPurchase,
    uint256 maxPurchase,
    uint256 startTime,
    uint256 endTime
) external onlyRole(ADMIN_ROLE)

// Purchase pool tokens (user calls this)
function purchase(uint256 poolId, uint256 amount) external nonReentrant whenNotPaused

// Batch purchase from multiple pools
function purchaseBatch(
    uint256[] calldata poolIds,
    uint256[] calldata amounts
) external nonReentrant whenNotPaused

// Calculate purchase price
function calculatePrice(uint256 poolId, uint256 amount) external view
    returns (uint256 subtotal, uint256 fee, uint256 total)

// Check if user can purchase
function canPurchase(uint256 poolId, address user, uint256 amount) external view
    returns (bool, string memory reason)
```

### Purchase Flow

1. User approves USDC spending to Marketplace
2. User calls `purchase(poolId, amount)`
3. Marketplace validates listing and user verification
4. USDC transferred from user to treasury
5. Pool tokens minted to user via ProjectPool

---

## Reserve

**Location:** `contracts/src/Reserve.sol`

The Reserve contract manages escrow accounts and dividend distributions.

### Features

- **Per-Pool Escrow**: Track funds by pool
- **Dividend Distributions**: Create claimable distributions
- **Pro-rata Claims**: Based on token holdings
- **Expiration Support**: Reclaim unclaimed funds

### Distribution Structure

```solidity
struct Distribution {
    uint256 poolId;                 // Target pool
    uint256 totalAmount;            // Total USDC
    uint256 totalSupplyAtSnapshot;  // Token supply at creation
    uint256 amountPerToken;         // USDC per token (scaled 1e18)
    uint256 claimedAmount;          // Amount claimed
    uint256 createdAt;              // Creation time
    uint256 expiresAt;              // Expiration (0 = never)
    bool active;                    // Is active
}
```

### Key Functions

```solidity
// Deposit funds to pool escrow
function deposit(uint256 poolId, uint256 amount) external nonReentrant whenNotPaused

// Withdraw from escrow (admin only)
function withdraw(uint256 poolId, uint256 amount, address to) external onlyRole(ADMIN_ROLE)

// Create a distribution (funds from caller)
function createDistribution(
    uint256 poolId,
    uint256 amount,
    uint256 expiresAt
) external onlyRole(DISTRIBUTOR_ROLE) returns (uint256 distributionId)

// Create distribution from pool escrow balance
function createDistributionFromBalance(
    uint256 poolId,
    uint256 amount,
    uint256 expiresAt
) external onlyRole(DISTRIBUTOR_ROLE) returns (uint256 distributionId)

// Claim a distribution (user calls this)
function claim(uint256 distributionId) external nonReentrant whenNotPaused

// Batch claim multiple distributions
function claimBatch(uint256[] calldata distributionIds) external nonReentrant whenNotPaused

// Get claimable amount for user
function getClaimableAmount(uint256 distributionId, address user) external view returns (uint256)
```

### Distribution Flow

1. Admin deposits USDC to Reserve
2. Admin creates distribution for a pool
3. Amount per token calculated: `totalAmount * 1e18 / totalSupply`
4. Users call `claim()` to receive USDC
5. User receives: `userBalance * amountPerToken / 1e18`

---

## Contract Addresses

Addresses are configured in `packages/shared/src/constants.ts`:

| Network | Chain ID | USDC Address |
|---------|----------|--------------|
| Polygon Mainnet | 137 | `0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359` |
| Polygon Amoy | 80002 | TBD |

## Development & Testing

### Install Dependencies

```bash
cd contracts
forge install OpenZeppelin/openzeppelin-contracts --no-git
forge install foundry-rs/forge-std --no-git
```

### Build Contracts

```bash
pnpm --filter @arc-exchange/contracts build
```

### Run Tests

```bash
pnpm --filter @arc-exchange/contracts test
```

### Deploy Locally

```bash
# Start local node
anvil

# Deploy contracts
pnpm --filter @arc-exchange/contracts deploy:local
```

## Security Considerations

1. **Role Management**: All privileged functions require specific roles
2. **Reentrancy Protection**: Critical functions use `nonReentrant`
3. **Pausability**: All contracts can be paused in emergencies
4. **Safe Transfers**: Uses OpenZeppelin's `SafeERC20`
5. **Input Validation**: Zero address and amount checks
6. **Transfer Restrictions**: Only verified investors can hold pool tokens
