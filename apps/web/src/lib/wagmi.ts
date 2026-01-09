import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { polygon, polygonAmoy } from 'wagmi/chains';

export const config = getDefaultConfig({
  appName: 'ARC Exchange',
  projectId: process.env.NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID || 'demo',
  chains: [
    polygon,
    ...(process.env.NODE_ENV === 'development' ? [polygonAmoy] : []),
  ],
  ssr: false,
});
