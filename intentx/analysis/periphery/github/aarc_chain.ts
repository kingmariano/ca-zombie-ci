export const BASE_CHAIN_ID = 8453;

export const BASE_CHAIN = {
    id: BASE_CHAIN_ID,
    name: 'Base',
    network: 'base',
    nativeCurrency: {
        decimals: 18,
        name: 'Ethereum',
        symbol: 'ETH',
    },
    rpcUrls: {
        default: {
            http: ['https://mainnet.base.org'],
        },
        public: {
            http: ['https://mainnet.base.org'],
        },
    },
    blockExplorers: {
        default: { name: 'BaseScan', url: 'https://basescan.org' },
    },
};