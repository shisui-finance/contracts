//! Contract to mock ERC20 with specfic decimals
use starknet::ContractAddress;
use openzeppelin::token::erc20::interface::IERC20;

#[starknet::interface]
trait IERC20MintBurn<TContractState> {
    fn mint(ref self: TContractState, recipient: ContractAddress, amount: u256);

    fn burn(ref self: TContractState, recipient: ContractAddress, amount: u256);
}


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
        self.decimals.write(decimals);
        // Initialize ERC20
        let name = 'ERC20Mock';
        let symbol = 'MOCK';

        self.erc20.initializer(name, symbol);
        self.mint(starknet::get_caller_address(), 10000_000000000000000000);
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

    #[external(v0)]
    impl ERC20MockImpl of super::IERC20MintBurn<ContractState> {
        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            self.erc20._mint(recipient, amount);
        }

        fn burn(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            self.erc20._burn(recipient, amount);
        }
    }
}
