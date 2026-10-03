export enum SupportedChainId {
    BASE = 8453
}

export type AddressMap = {
    [chainId: number]: string;
};

export const DIAMOND_ADDRESS: AddressMap = {
    [SupportedChainId.BASE]: '0x91Cf2D8Ed503EC52768999aA6D8DBeA6e52dbe43'
};

export const MULTIACCOUNT_ADDRESS: AddressMap = {
    [SupportedChainId.BASE]: '0x8Ab178C07184ffD44F0ADfF4eA2ce6cFc33F3b86'
};

export const multiAccountAbi = [
    {
        name: "getAccountsLength",
        type: "function",
        stateMutability: "view",
        inputs: [
            {
                name: "user",
                type: "address"
            }
        ],
        outputs: [
            {
                name: "",
                type: "uint256"
            }
        ]
    },
    {
        name: "getAccounts",
        type: "function",
        stateMutability: "view",
        inputs: [
            {
                name: "user",
                type: "address"
            },
            {
                name: "start",
                type: "uint256"
            },
            {
                name: "size",
                type: "uint256"
            }
        ],
        outputs: [
            {
                name: "",
                type: "tuple[]",
                components: [
                    {
                        name: "accountAddress",
                        type: "address"
                    },
                    {
                        name: "name",
                        type: "string"
                    }
                ]
            }
        ]
    },
    {
        name: "addAccount",
        type: "function",
        stateMutability: "nonpayable",
        inputs: [
            {
                name: "name",
                type: "string"
            }
        ],
        outputs: []
    }
] as const;

export const BASE_RPC_URL = "https://mainnet.base.org";