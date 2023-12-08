use starknet::ContractAddress;

#[starknet::interface]
trait ICollateralSurplusPool<TContractState> {
    fn account_surplus(
        ref self: TContractState, asset: ContractAddress, account: ContractAddress, amount: u256
    );

    fn claim_coll(ref self: TContractState, asset: ContractAddress, account: ContractAddress);

    fn received_erc20(ref self: TContractState, asset: ContractAddress, amount: u256);

    fn get_asset_balance(self: @TContractState, asset: ContractAddress) -> u256;

    fn get_collateral(
        self: @TContractState, asset: ContractAddress, account: ContractAddress
    ) -> u256;
}


#[starknet::contract]
mod CollateralSurplusPool {
    use starknet::{ContractAddress, get_caller_address};
    use shisui::core::address_provider::{
        IAddressProviderDispatcher, IAddressProviderDispatcherTrait
    };


    #[storage]
    struct Storage {
        address_provider: IAddressProviderDispatcher,
        // deposited ether tracker
        balances: LegacyMap<ContractAddress, u256>,
        // Collateral surplus claimable by vessel owners
        user_balances: LegacyMap<(ContractAddress, ContractAddress), u256>
    }


    #[constructor]
    fn constructor(ref self: ContractState, address_provider: IAddressProviderDispatcher) {
        self.address_provider.write(address_provider);
    }

    #[external(v0)]
    impl CollateralSurplusPoolImpl of super::ICollateralSurplusPool<ContractState> {
        fn account_surplus(
            ref self: ContractState, asset: ContractAddress, account: ContractAddress, amount: u256
        ) {}

        fn claim_coll(ref self: ContractState, asset: ContractAddress, account: ContractAddress) {}

        fn received_erc20(ref self: ContractState, asset: ContractAddress, amount: u256) {}

        /// Returns the Asset state variable at ActivePool address.
        /// Not necessarily equal to the raw ether balance - ether can be forcibly sent to contracts.
        fn get_asset_balance(self: @ContractState, asset: ContractAddress) -> u256 {
            return 0;
        }

        fn get_collateral(
            self: @ContractState, asset: ContractAddress, account: ContractAddress
        ) -> u256 {
            return 0;
        }
    }
}
