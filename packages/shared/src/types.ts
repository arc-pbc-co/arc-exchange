// User types
export interface User {
  id: string;
  walletAddress: string;
  email?: string;
  createdAt: Date;
  updatedAt: Date;
}

export type KycStatus = 'PENDING' | 'IN_PROGRESS' | 'APPROVED' | 'REJECTED' | 'EXPIRED';

export interface KycVerification {
  id: string;
  userId: string;
  provider: string;
  status: KycStatus;
  isAccredited: boolean;
  isUsPerson: boolean;
  verifiedAt?: Date;
  expiresAt?: Date;
}

// Pool types
export type PoolStatus =
  | 'DRAFT'
  | 'PENDING_APPROVAL'
  | 'ACTIVE'
  | 'FUNDED'
  | 'CLOSED'
  | 'MATURED';

export interface Pool {
  id: string;
  name: string;
  description: string;
  sector: string;
  targetRaise: number;
  currentRaise: number;
  yieldRate: number;
  maturityDate: Date;
  status: PoolStatus;
  imageUrl?: string;
  metadataUri?: string;
  contractTokenId?: string;
  totalSupply: string;
  pricePerToken: number;
  createdAt: Date;
  updatedAt: Date;
}

// Investment types
export interface Investment {
  id: string;
  userId: string;
  poolId: string;
  tokenAmount: string;
  purchasePriceUsd: number;
  txHash?: string;
  purchasedAt: Date;
  pool?: Pool;
}

// Distribution types
export type DistributionStatus = 'PENDING' | 'PROCESSING' | 'COMPLETED' | 'FAILED';

export interface Distribution {
  id: string;
  poolId: string;
  amountUsd: number;
  distributionDate: Date;
  status: DistributionStatus;
  txHash?: string;
}

// API Response types
export interface ApiResponse<T> {
  data: T;
  message?: string;
}

export interface PaginatedResponse<T> {
  data: T[];
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
}

// Auth types
export interface AuthTokenPayload {
  sub: string;
  walletAddress: string;
  isVerified: boolean;
  isAccredited: boolean;
}

export interface LoginResponse {
  accessToken: string;
  user: {
    id: string;
    walletAddress: string;
    email?: string;
    kycStatus: KycStatus | null;
    isAccredited: boolean;
    isUsPerson: boolean;
  };
}

// Portfolio types
export interface PortfolioSummary {
  totalInvested: number;
  totalTokens: number;
  poolsInvested: number;
  investments: {
    id: string;
    poolName: string;
    poolSector: string;
    tokenAmount: string;
    purchasePriceUsd: number;
    yieldRate: number;
    purchasedAt: Date;
  }[];
}

// NFT Metadata (ERC-1155)
export interface PoolNftMetadata {
  name: string;
  description: string;
  image: string;
  external_url?: string;
  attributes: {
    trait_type: string;
    value: string | number;
    display_type?: string;
  }[];
  properties: {
    sector: string;
    yieldRate: number;
    maturityDate: string;
    targetRaise: number;
    pricePerToken: number;
  };
}
