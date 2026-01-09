# Frontend Application

The ARC Exchange frontend is a Next.js 14 application using the App Router, located in `apps/web/`.

## Technology Stack

| Technology | Purpose |
|------------|---------|
| Next.js 14 | React framework with App Router |
| React 18 | UI library |
| Tailwind CSS | Utility-first styling |
| wagmi v2 | React hooks for Ethereum |
| viem | TypeScript Ethereum library |
| RainbowKit v2 | Wallet connection UI |
| TanStack Query v5 | Server state management |
| Zustand | Client state management |

## Project Structure

```
apps/web/
├── src/
│   ├── app/                  # Next.js App Router
│   │   ├── layout.tsx        # Root layout
│   │   ├── page.tsx          # Home page
│   │   ├── globals.css       # Global styles
│   │   └── env.d.ts          # Environment types
│   ├── components/           # Reusable components
│   │   └── connect-button.tsx
│   ├── providers/            # Context providers
│   │   └── index.tsx
│   └── lib/                  # Utilities
│       └── wagmi.ts          # Wagmi configuration
├── public/                   # Static assets
├── tailwind.config.ts        # Tailwind configuration
├── tsconfig.json             # TypeScript config
└── package.json
```

## Configuration

### Environment Variables

```env
# API URL
NEXT_PUBLIC_API_URL="http://localhost:3001"

# WalletConnect Project ID (required for RainbowKit)
NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID="your_project_id"

# Contract Addresses
NEXT_PUBLIC_ARC_TOKEN_ADDRESS=""
NEXT_PUBLIC_PROJECT_POOL_ADDRESS=""
NEXT_PUBLIC_MARKETPLACE_ADDRESS=""
NEXT_PUBLIC_USDC_ADDRESS="0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359"
```

### Wagmi Configuration

```typescript
// src/lib/wagmi.ts
import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { polygon, polygonAmoy } from 'wagmi/chains';

export const config = getDefaultConfig({
  appName: 'ARC Exchange',
  projectId: process.env.NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID!,
  chains: [polygon, polygonAmoy],
});
```

## Providers Setup

The application uses multiple providers for different functionality:

```tsx
// src/providers/index.tsx
'use client';

import { RainbowKitProvider } from '@rainbow-me/rainbowkit';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { WagmiProvider } from 'wagmi';
import { config } from '@/lib/wagmi';

const queryClient = new QueryClient();

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider>
          {children}
        </RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  );
}
```

## Key Components

### Connect Button

Wallet connection component using RainbowKit:

```tsx
// src/components/connect-button.tsx
'use client';

import { ConnectButton } from '@rainbow-me/rainbowkit';

export function WalletConnectButton() {
  return (
    <ConnectButton
      accountStatus="address"
      chainStatus="icon"
      showBalance={false}
    />
  );
}
```

### Root Layout

```tsx
// src/app/layout.tsx
import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import './globals.css';
import { Providers } from '@/providers';

const inter = Inter({ subsets: ['latin'], variable: '--font-inter' });

export const metadata: Metadata = {
  title: 'ARC Exchange - Impact Investment Marketplace',
  description: 'Blockchain-based marketplace for tokenized impact investments',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className={`${inter.variable} font-sans antialiased`}>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
```

## Web3 Integration

### Using wagmi Hooks

```tsx
'use client';

import { useAccount, useBalance, useReadContract } from 'wagmi';
import { formatUnits } from 'viem';

export function AccountInfo() {
  const { address, isConnected } = useAccount();
  const { data: balance } = useBalance({ address });

  if (!isConnected) {
    return <p>Connect your wallet</p>;
  }

  return (
    <div>
      <p>Address: {address}</p>
      <p>Balance: {formatUnits(balance?.value ?? 0n, 18)} MATIC</p>
    </div>
  );
}
```

### Reading Contract Data

```tsx
import { useReadContract } from 'wagmi';
import { PROJECT_POOL_ABI } from '@arc-exchange/contract-types';

export function PoolInfo({ poolId }: { poolId: number }) {
  const { data: poolInfo } = useReadContract({
    address: process.env.NEXT_PUBLIC_PROJECT_POOL_ADDRESS as `0x${string}`,
    abi: PROJECT_POOL_ABI,
    functionName: 'getPoolInfo',
    args: [BigInt(poolId)],
  });

  return (
    <div>
      <p>Max Supply: {poolInfo?.[1]?.toString()}</p>
      <p>Current Supply: {poolInfo?.[2]?.toString()}</p>
      <p>Active: {poolInfo?.[4] ? 'Yes' : 'No'}</p>
    </div>
  );
}
```

### Writing to Contracts

```tsx
import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { parseUnits } from 'viem';
import { MARKETPLACE_ABI } from '@arc-exchange/contract-types';

export function PurchaseButton({ poolId, amount }: { poolId: number; amount: number }) {
  const { writeContract, data: hash, isPending } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const handlePurchase = () => {
    writeContract({
      address: process.env.NEXT_PUBLIC_MARKETPLACE_ADDRESS as `0x${string}`,
      abi: MARKETPLACE_ABI,
      functionName: 'purchase',
      args: [BigInt(poolId), BigInt(amount)],
    });
  };

  return (
    <button onClick={handlePurchase} disabled={isPending || isConfirming}>
      {isPending ? 'Confirming...' : isConfirming ? 'Processing...' : 'Purchase'}
    </button>
  );
}
```

## API Integration

### Using TanStack Query

```tsx
import { useQuery, useMutation } from '@tanstack/react-query';

const API_URL = process.env.NEXT_PUBLIC_API_URL;

// Fetch pools
export function usePools() {
  return useQuery({
    queryKey: ['pools'],
    queryFn: async () => {
      const res = await fetch(`${API_URL}/api/pools`);
      return res.json();
    },
  });
}

// Create investment
export function useCreateInvestment() {
  return useMutation({
    mutationFn: async (data: { poolId: string; tokenAmount: string; txHash: string }) => {
      const res = await fetch(`${API_URL}/api/investments`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${getToken()}`,
        },
        body: JSON.stringify(data),
      });
      return res.json();
    },
  });
}
```

## Styling

### Tailwind Configuration

```typescript
// tailwind.config.ts
import type { Config } from 'tailwindcss';

const config: Config = {
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['var(--font-inter)', 'system-ui', 'sans-serif'],
      },
    },
  },
  plugins: [],
};

export default config;
```

### Utility Functions

```typescript
// Using clsx and tailwind-merge for conditional classes
import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

// Usage
<button className={cn(
  'px-4 py-2 rounded',
  isActive && 'bg-blue-500 text-white',
  isDisabled && 'opacity-50 cursor-not-allowed'
)}>
  Click me
</button>
```

## Development

### Start Development Server

```bash
# From root directory
pnpm dev:web

# Or directly
cd apps/web && pnpm dev
```

### Build for Production

```bash
pnpm build:web
```

### Type Checking

```bash
pnpm --filter @arc-exchange/web typecheck
```

### Linting

```bash
pnpm --filter @arc-exchange/web lint
```

## Best Practices

1. **Server Components by Default**: Use client components only when needed
2. **Optimistic Updates**: Use TanStack Query for optimistic UI updates
3. **Error Boundaries**: Wrap critical sections with error boundaries
4. **Loading States**: Show loading indicators for async operations
5. **Mobile-First**: Design for mobile, enhance for desktop
6. **Accessibility**: Follow WCAG guidelines
