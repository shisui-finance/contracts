use starknet::ContractAddress;

#[starknet::interface]
trait IDefaultPool<TContractState> {
    fn increase_debt(ref self: TContractState, asset: ContractAddress, amount: u256);

    fn decrease_debt(ref self: TContractState, asset: ContractAddress, amount: u256);

    fn send_asset_to_active_pool(ref self: TContractState, asset: ContractAddress, amount: u256);

    fn received_erc20(ref self: TContractState, asset: ContractAddress, amount: u256);

    fn get_asset_balance(self: @TContractState, asset: ContractAddress) -> u256;

    fn get_debt_token_balance(self: @TContractState, asset: ContractAddress) -> u256;
}


/// The Active Pool holds the collaterals and debt amounts for all active vessels.
///
/// When a vessel is liquidated, it's collateral and debt tokens are transferred from the Active Pool, to either the
/// Stability Pool, the Default Pool, or both, depending on the liquidation conditions.
#[starknet::contract]
mod DefaultPool {
    use starknet::{ContractAddress, get_caller_address};
    use shisui::core::address_provider::{
        IAddressProviderDispatcher, IAddressProviderDispatcherTrait
    };


    #[storage]
    struct Storage {
        address_provider: IAddressProviderDispatcher,
        assets_balances: LegacyMap<ContractAddress, u256>,
        debt_token_balances: LegacyMap<ContractAddress, u256>,
    }


    #[constructor]
    fn constructor(ref self: ContractState, address_provider: IAddressProviderDispatcher) {
        self.address_provider.write(address_provider);
    }

    #[external(v0)]
    impl DefaultPoolImpl of super::IDefaultPool<ContractState> {
        fn increase_debt(ref self: ContractState, asset: ContractAddress, amount: u256) {}

        fn decrease_debt(ref self: ContractState, asset: ContractAddress, amount: u256) {}

        fn send_asset_to_active_pool(
            ref self: ContractState, asset: ContractAddress, amount: u256
        ) {}

        fn received_erc20(ref self: ContractState, asset: ContractAddress, amount: u256) {}

        fn get_asset_balance(self: @ContractState, asset: ContractAddress) -> u256 {
            return 0;
        }

        fn get_debt_token_balance(self: @ContractState, asset: ContractAddress) -> u256 {
            return 0;
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _is_erc20_deposit_contract(self: @ContractState, account: ContractAddress) -> bool {
            return false;
        }
    }
}
