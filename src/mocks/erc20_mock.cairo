//! Contract to mock ERC20 with specfic decimals

#[starknet::contract]
mod ERC20Mock {
    // *************************************************************************
    //                                  IMPORTS
    // *************************************************************************
    use openzeppelin::token::erc20::interface::IERC20Metadata;
    use openzeppelin::token::erc20::ERC20Component;
    use starknet::ContractAddress;

    // *************************************************************************
    //                  Component
    // *************************************************************************
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    // *************************************************************************
    //                              STORAGE
    // *************************************************************************
    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        decimals: u8
    }

    // *************************************************************************
    //                              EVENT
    // *************************************************************************
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event
    }

    // *************************************************************************
    //                              CONSTRUCTOR
    // *************************************************************************
    #[constructor]
    fn constructor(ref self: ContractState, decimals: u8) {
        // Call the internal function that writes decimals to storage
        self._set_decimals(decimals);
        // Initialize ERC20
        let name = 'ERC20Mock';
        let symbol = 'MOCK';

        self.erc20.initializer(name, symbol);
    }

    // *************************************************************************
    //                          EXTERNAL FUNCTIONS
    // *************************************************************************
    #[external(v0)]
    impl ERC20MetadataImpl of IERC20Metadata<ContractState> {
        fn decimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }

        fn name(self: @ContractState) -> felt252 {
            self.erc20.name()
        }

        fn symbol(self: @ContractState) -> felt252 {
            self.erc20.symbol()
        }
    }

    // *************************************************************************
    //                          INTERNAL FUNCTIONS
    // *************************************************************************
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _set_decimals(ref self: ContractState, decimals: u8) {
            self.decimals.write(decimals);
        }
    }
}
