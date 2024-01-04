use starknet::ContractAddress;
#[starknet::interface]
trait IStabilityPool<TContractState> {
    fn add_collateral_type(ref self: TContractState, collateral: ContractAddress);
}


#[starknet::contract]
mod StabilityPool {
    use starknet::ContractAddress;
    use shisui::core::address_provider::{
        IAddressProviderDispatcher, IAddressProviderDispatcherTrait, AddressesKey
    };
    #[storage]
    struct Storage {
        address_provider: IAddressProviderDispatcher,
    }

    #[constructor]
    fn constructor(ref self: ContractState, address_provider: IAddressProviderDispatcher) {
        self.address_provider.write(address_provider);
    }

    #[external(v0)]
    impl StabilityPoolImpl of super::IStabilityPool<ContractState> {
        fn add_collateral_type(ref self: ContractState, collateral: ContractAddress) {}
    }
}

