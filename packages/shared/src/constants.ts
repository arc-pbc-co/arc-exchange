// Chain IDs
export const CHAIN_IDS = {
  POLYGON: 137,
  POLYGON_AMOY: 80002,
} as const;

// Contract addresses (to be filled after deployment)
export const CONTRACT_ADDRESSES = {
  [CHAIN_IDS.POLYGON]: {
    ARC_TOKEN: '',
    PROJECT_POOL: '',
    MARKETPLACE: '',
    RESERVE: '',
    USDC: '0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359', // Native USDC on Polygon
  },
  [CHAIN_IDS.POLYGON_AMOY]: {
    ARC_TOKEN: '',
    PROJECT_POOL: '',
    MARKETPLACE: '',
    RESERVE: '',
    USDC: '', // Test USDC on Amoy
  },
} as const;

// Investment sectors
export const SECTORS = [
  'Real Estate',
  'Infrastructure',
  'Clean Energy',
  'Agriculture',
  'Healthcare',
  'Education',
  'Financial Services',
  'Technology',
] as const;

export type Sector = (typeof SECTORS)[number];

// Pool status labels
export const POOL_STATUS_LABELS: Record<string, string> = {
  DRAFT: 'Draft',
  PENDING_APPROVAL: 'Pending Approval',
  ACTIVE: 'Open for Investment',
  FUNDED: 'Fully Funded',
  CLOSED: 'Closed',
  MATURED: 'Matured',
} as const;

// KYC status labels
export const KYC_STATUS_LABELS: Record<string, string> = {
  PENDING: 'Pending',
  IN_PROGRESS: 'In Progress',
  APPROVED: 'Verified',
  REJECTED: 'Rejected',
  EXPIRED: 'Expired',
} as const;

// API endpoints
export const API_ENDPOINTS = {
  AUTH: {
    NONCE: '/api/auth/nonce',
    VERIFY: '/api/auth/verify',
    ME: '/api/auth/me',
  },
  USERS: {
    PROFILE: '/api/users/profile',
    EMAIL: '/api/users/email',
    KYC: '/api/users/kyc',
  },
  POOLS: {
    LIST: '/api/pools',
    ADMIN_LIST: '/api/pools/admin',
    DETAIL: (id: string) => `/api/pools/${id}`,
    CREATE: '/api/pools',
    UPDATE: (id: string) => `/api/pools/${id}`,
    ACTIVATE: (id: string) => `/api/pools/${id}/activate`,
  },
  INVESTMENTS: {
    LIST: '/api/investments',
    PORTFOLIO: '/api/investments/portfolio',
    CREATE: '/api/investments',
  },
} as const;

// Minimum investment amounts
export const MIN_INVESTMENT_USD = 1000;

// Token decimals
export const DECIMALS = {
  USDC: 6,
  ARC: 18,
  POOL_TOKEN: 0, // ERC-1155 tokens are typically whole numbers
} as const;
