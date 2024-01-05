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


/// The Default Pool holds the collaterals and debt amounts for all active vessels.
///
/// When a vessel is liquidated, it's collateral and debt tokens are transferred from the Default Pool, to either the
/// Stability Pool, the Default Pool, or both, depending on the liquidation conditions.
#[starknet::contract]
mod DefaultPool {
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use openzeppelin::{
        token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait},
        security::reentrancyguard::{
            ReentrancyGuardComponent, ReentrancyGuardComponent::InternalImpl
        }
    };
    use shisui::core::address_provider::{
        IAddressProviderDispatcher, IAddressProviderDispatcherTrait, AddressesKey
    };
    use shisui::utils::{
        errors::CommunErrors, asserts::assert_address_non_zero, convert::decimals_correction
    };
    use shisui::interfaces::deposit::{IDepositDispatcher, IDepositDispatcherTrait};

    use snforge_std::PrintTrait;

    #[storage]
    struct Storage {
        address_provider: IAddressProviderDispatcher,
        assets_balances: LegacyMap<ContractAddress, u256>,
        debt_token_balances: LegacyMap<ContractAddress, u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        DefaultPoolAssetBalanceUpdated: DefaultPoolAssetBalanceUpdated,
        DefaultPoolDebtUpdated: DefaultPoolDebtUpdated,
        AssetSent: AssetSent
    }


    #[derive(Drop, starknet::Event)]
    struct DefaultPoolAssetBalanceUpdated {
        asset: ContractAddress,
        old_balance: u256,
        new_balance: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct DefaultPoolDebtUpdated {
        asset: ContractAddress,
        old_balance: u256,
        new_balance: u256,
    }


    #[derive(Drop, starknet::Event)]
    struct AssetSent {
        account: ContractAddress,
        asset: ContractAddress,
        amount: u256,
    }


    #[constructor]
    fn constructor(ref self: ContractState, address_provider: IAddressProviderDispatcher) {
        assert_address_non_zero(address_provider.contract_address);
        self.address_provider.write(address_provider);
    }

    #[external(v0)]
    impl DefaultPoolImpl of super::IDefaultPool<ContractState> {
        fn increase_debt(ref self: ContractState, asset: ContractAddress, amount: u256) {
            self.assert_caller_is_vessel_manager();
            let old_balance = self.debt_token_balances.read(asset);
            let new_balance = old_balance + amount;
            self.debt_token_balances.write(asset, new_balance);
            self.emit(DefaultPoolDebtUpdated { asset, old_balance, new_balance });
        }

        fn decrease_debt(ref self: ContractState, asset: ContractAddress, amount: u256) {
            self.assert_caller_is_vessel_manager();
            let old_balance = self.debt_token_balances.read(asset);
            let new_balance = old_balance - amount;
            self.debt_token_balances.write(asset, new_balance);
            self.emit(DefaultPoolDebtUpdated { asset, old_balance, new_balance });
        }

        fn send_asset_to_active_pool(
            ref self: ContractState, asset: ContractAddress, amount: u256
        ) {
            self.assert_caller_is_vessel_manager();
            let safety_transfer_amount = decimals_correction(asset, amount);
            if (safety_transfer_amount == 0) {
                return;
            }
            let active_pool_address = self
                .address_provider
                .read()
                .get_address(AddressesKey::active_pool);
            let old_balance = self.assets_balances.read(asset);
            let new_balance = old_balance - amount;
            self.assets_balances.write(asset, new_balance);

            IERC20Dispatcher { contract_address: asset }
                .transfer(active_pool_address, safety_transfer_amount);

            IDepositDispatcher { contract_address: active_pool_address }
                .received_erc20(asset, amount);

            self.emit(DefaultPoolAssetBalanceUpdated { asset, old_balance, new_balance });
            self
                .emit(
                    AssetSent {
                        account: active_pool_address, asset, amount: safety_transfer_amount
                    }
                );
        }

        fn received_erc20(ref self: ContractState, asset: ContractAddress, amount: u256) {
            self.assert_caller_is_active_pool();
            let old_balance = self.assets_balances.read(asset);
            let new_balance = old_balance + amount;
            self.assets_balances.write(asset, new_balance);

            self.emit(DefaultPoolAssetBalanceUpdated { asset, old_balance, new_balance });
        }

        fn get_asset_balance(self: @ContractState, asset: ContractAddress) -> u256 {
            return self.assets_balances.read(asset);
        }

        fn get_debt_token_balance(self: @ContractState, asset: ContractAddress) -> u256 {
            return self.debt_token_balances.read(asset);
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        #[inline(always)]
        fn assert_caller_is_vessel_manager(self: @ContractState) {
            let caller = get_caller_address();

            let address_provider = self.address_provider.read();
            assert(
                caller == address_provider.get_address(AddressesKey::vessel_manager),
                CommunErrors::CallerNotAuthorized
            );
        }

        #[inline(always)]
        fn assert_caller_is_active_pool(self: @ContractState) {
            let caller = get_caller_address();
            let address_provider = self.address_provider.read();
            assert(
                caller == address_provider.get_address(AddressesKey::active_pool),
                CommunErrors::CallerNotAuthorized
            );
        }
    }
}
