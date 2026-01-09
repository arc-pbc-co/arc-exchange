# API Reference

The ARC Exchange API is a NestJS application providing REST endpoints for the platform.

**Base URL:** `http://localhost:3001` (development)

**Swagger Docs:** `http://localhost:3001/api/docs`

## Authentication

All authenticated endpoints require a JWT token in the Authorization header:

```
Authorization: Bearer <token>
```

### Sign-In with Ethereum (SIWE) Flow

1. Request a nonce
2. Sign the SIWE message with wallet
3. Verify signature to receive JWT

---

## Auth Endpoints

### GET /api/auth/nonce

Request a nonce for SIWE authentication.

**Query Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `walletAddress` | string | No | Wallet address for pre-registration |

**Response:**
```json
{
  "nonce": "abc123xyz..."
}
```

---

### POST /api/auth/verify

Verify a signed SIWE message and receive JWT.

**Request Body:**
```json
{
  "message": "app.arcexchange.io wants you to sign in...",
  "signature": "0x..."
}
```

**Response:**
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIs...",
  "user": {
    "id": "clxyz123...",
    "walletAddress": "0x1234...5678",
    "email": null,
    "kycStatus": "APPROVED",
    "isAccredited": true,
    "isUsPerson": true
  }
}
```

---

### GET /api/auth/me

Get current authenticated user.

**Headers:** `Authorization: Bearer <token>`

**Response:**
```json
{
  "id": "clxyz123...",
  "walletAddress": "0x1234...5678",
  "email": "user@example.com",
  "kycStatus": "APPROVED",
  "isAccredited": true,
  "isUsPerson": true
}
```

---

## User Endpoints

### GET /api/users/profile

Get user profile with investments.

**Headers:** `Authorization: Bearer <token>`

**Response:**
```json
{
  "id": "clxyz123...",
  "walletAddress": "0x1234...5678",
  "email": "user@example.com",
  "displayName": "John Doe",
  "kycVerification": {
    "status": "APPROVED",
    "isAccredited": true,
    "isUsPerson": true,
    "verifiedAt": "2024-01-15T12:00:00Z",
    "expiresAt": "2025-01-15T12:00:00Z"
  },
  "investments": [...]
}
```

---

### PATCH /api/users/email

Update user email.

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "email": "newemail@example.com"
}
```

**Response:**
```json
{
  "id": "clxyz123...",
  "walletAddress": "0x1234...5678",
  "email": "newemail@example.com"
}
```

---

### GET /api/users/kyc

Get KYC verification status.

**Headers:** `Authorization: Bearer <token>`

**Response:**
```json
{
  "status": "APPROVED",
  "isAccredited": true,
  "isUsPerson": true,
  "verifiedAt": "2024-01-15T12:00:00Z",
  "expiresAt": "2025-01-15T12:00:00Z"
}
```

---

## Pool Endpoints

### GET /api/pools

List all active pools.

**Query Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `status` | string | No | Filter by status (ACTIVE, FUNDED, etc.) |

**Response:**
```json
[
  {
    "id": "pool123...",
    "name": "Solar Farm Alpha",
    "description": "20MW solar installation...",
    "sector": "Clean Energy",
    "targetRaise": 5000000,
    "currentRaise": 2500000,
    "yieldRate": 8.5,
    "maturityDate": "2027-01-15T00:00:00Z",
    "status": "ACTIVE",
    "pricePerToken": 100,
    "imageUrl": "https://..."
  }
]
```

---

### GET /api/pools/:id

Get pool details.

**Path Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `id` | string | Pool ID |

**Response:**
```json
{
  "id": "pool123...",
  "name": "Solar Farm Alpha",
  "description": "20MW solar installation...",
  "sector": "Clean Energy",
  "targetRaise": 5000000,
  "currentRaise": 2500000,
  "yieldRate": 8.5,
  "maturityDate": "2027-01-15T00:00:00Z",
  "status": "ACTIVE",
  "pricePerToken": 100,
  "imageUrl": "https://...",
  "metadataUri": "ipfs://...",
  "contractTokenId": "1",
  "investments": [
    {
      "id": "inv123...",
      "tokenAmount": "100",
      "purchasePriceUsd": 10000,
      "purchasedAt": "2024-06-01T12:00:00Z"
    }
  ],
  "distributions": [
    {
      "id": "dist123...",
      "amountUsd": 50000,
      "distributionDate": "2024-07-01T00:00:00Z",
      "status": "COMPLETED"
    }
  ]
}
```

---

### POST /api/pools (Admin)

Create a new pool.

**Headers:** `Authorization: Bearer <admin-token>`

**Request Body:**
```json
{
  "name": "Solar Farm Alpha",
  "description": "20MW solar installation in Arizona",
  "sector": "Clean Energy",
  "targetRaise": 5000000,
  "yieldRate": 8.5,
  "maturityDate": "2027-01-15",
  "pricePerToken": 100,
  "imageUrl": "https://..."
}
```

**Response:**
```json
{
  "id": "pool123...",
  "name": "Solar Farm Alpha",
  "status": "DRAFT",
  "createdAt": "2024-06-01T12:00:00Z"
}
```

---

### PATCH /api/pools/:id (Admin)

Update a pool.

**Headers:** `Authorization: Bearer <admin-token>`

**Request Body:**
```json
{
  "name": "Solar Farm Alpha - Updated",
  "status": "ACTIVE",
  "metadataUri": "ipfs://Qm...",
  "contractTokenId": "1"
}
```

---

### POST /api/pools/:id/activate (Admin)

Activate a pool for investments.

**Headers:** `Authorization: Bearer <admin-token>`

**Response:**
```json
{
  "id": "pool123...",
  "status": "ACTIVE"
}
```

---

## Investment Endpoints

### GET /api/investments

List user's investments.

**Headers:** `Authorization: Bearer <token>`

**Response:**
```json
[
  {
    "id": "inv123...",
    "poolId": "pool123...",
    "tokenAmount": "100",
    "purchasePriceUsd": 10000,
    "purchasedAt": "2024-06-01T12:00:00Z",
    "pool": {
      "id": "pool123...",
      "name": "Solar Farm Alpha",
      "sector": "Clean Energy",
      "yieldRate": 8.5
    },
    "claims": [
      {
        "id": "claim123...",
        "amountUsd": 212.50,
        "status": "CLAIMED",
        "distribution": {
          "distributionDate": "2024-07-01T00:00:00Z"
        }
      }
    ]
  }
]
```

---

### GET /api/investments/portfolio

Get portfolio summary.

**Headers:** `Authorization: Bearer <token>`

**Response:**
```json
{
  "totalInvested": 25000,
  "totalTokens": 250,
  "poolsInvested": 3,
  "investments": [
    {
      "id": "inv123...",
      "poolName": "Solar Farm Alpha",
      "poolSector": "Clean Energy",
      "tokenAmount": "100",
      "purchasePriceUsd": 10000,
      "yieldRate": 8.5,
      "purchasedAt": "2024-06-01T12:00:00Z"
    }
  ]
}
```

---

### POST /api/investments

Record a new investment.

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "poolId": "pool123...",
  "tokenAmount": "100",
  "txHash": "0xabc123..."
}
```

**Response:**
```json
{
  "id": "inv123...",
  "poolId": "pool123...",
  "tokenAmount": "100",
  "purchasePriceUsd": 10000,
  "purchasedAt": "2024-06-01T12:00:00Z",
  "pool": {
    "name": "Solar Farm Alpha"
  }
}
```

---

## Error Responses

All endpoints return standard error responses:

### 400 Bad Request
```json
{
  "statusCode": 400,
  "message": ["tokenAmount must be a positive number"],
  "error": "Bad Request"
}
```

### 401 Unauthorized
```json
{
  "statusCode": 401,
  "message": "Invalid or expired token",
  "error": "Unauthorized"
}
```

### 403 Forbidden
```json
{
  "statusCode": 403,
  "message": "Only accredited investors can invest",
  "error": "Forbidden"
}
```

### 404 Not Found
```json
{
  "statusCode": 404,
  "message": "Pool not found",
  "error": "Not Found"
}
```

---

## Rate Limiting

| Endpoint | Limit |
|----------|-------|
| `/api/auth/*` | 10 requests/minute |
| `/api/*` (authenticated) | 100 requests/minute |

---

## API Constants

### Pool Status Values
- `DRAFT` - Initial creation
- `PENDING_APPROVAL` - Awaiting review
- `ACTIVE` - Open for investment
- `FUNDED` - Target reached
- `CLOSED` - Manually closed
- `MATURED` - Reached maturity

### KYC Status Values
- `PENDING` - Not started
- `IN_PROGRESS` - Verification in progress
- `APPROVED` - Verified and accredited
- `REJECTED` - Verification failed
- `EXPIRED` - Verification expired

### Investment Sectors
- Real Estate
- Infrastructure
- Clean Energy
- Agriculture
- Healthcare
- Education
- Financial Services
- Technology
