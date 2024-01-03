use starknet::ContractAddress;

#[starknet::interface]
trait IActivePool<TContractState> {
    fn increase_debt(ref self: TContractState, asset: ContractAddress, amount: u256);

    fn decrease_debt(ref self: TContractState, asset: ContractAddress, amount: u256);

    fn send_asset(
        ref self: TContractState, asset: ContractAddress, account: ContractAddress, amount: u256
    );

    fn received_erc20(ref self: TContractState, asset: ContractAddress, amount: u256);

    fn get_asset_balance(self: @TContractState, asset: ContractAddress) -> u256;

    fn get_debt_token_balance(self: @TContractState, asset: ContractAddress) -> u256;
}


/// The Active Pool holds the collaterals and debt amounts for all active vessels.
///
/// When a vessel is liquidated, it's collateral and debt tokens are transferred from the Active Pool, to either the
/// Stability Pool, the Default Pool, or both, depending on the liquidation conditions.
#[starknet::contract]
mod ActivePool {
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
    use super::IActivePool;
    use snforge_std::PrintTrait;

    component!(path: ReentrancyGuardComponent, storage: reentrancy, event: ReentrancyEvent);

    #[storage]
    struct Storage {
        address_provider: IAddressProviderDispatcher,
        assets_balances: LegacyMap<ContractAddress, u256>,
        debt_token_balances: LegacyMap<ContractAddress, u256>,
        #[substorage(v0)]
        reentrancy: ReentrancyGuardComponent::Storage,
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ReentrancyEvent: ReentrancyGuardComponent::Event,
        ActivePoolAssetBalanceUpdated: ActivePoolAssetBalanceUpdated,
        ActivePoolDebtUpdated: ActivePoolDebtUpdated,
        AssetSent: AssetSent
    }


    #[derive(Drop, starknet::Event)]
    struct ActivePoolAssetBalanceUpdated {
        asset: ContractAddress,
        old_balance: u256,
        new_balance: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct ActivePoolDebtUpdated {
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
    impl ActivePoolImpl of IActivePool<ContractState> {
        fn increase_debt(ref self: ContractState, asset: ContractAddress, amount: u256) {
            self.assert_caller_is_borrow_operations_or_vessel_manager();
            let old_balance = self.debt_token_balances.read(asset);
            let new_balance = old_balance + amount;
            self.debt_token_balances.write(asset, new_balance);
            self.emit(ActivePoolDebtUpdated { asset, old_balance, new_balance });
        }

        fn decrease_debt(ref self: ContractState, asset: ContractAddress, amount: u256) {
            self.assert_caller_is_borrow_operations_or_stability_pool_or_vessel_manager();
            let old_balance = self.debt_token_balances.read(asset);
            let new_balance = old_balance - amount;
            self.debt_token_balances.write(asset, new_balance);
            self.emit(ActivePoolDebtUpdated { asset, old_balance, new_balance });
        }

        fn send_asset(
            ref self: ContractState, asset: ContractAddress, account: ContractAddress, amount: u256
        ) {
            self.reentrancy.start();
            self.assert_caller_is_borrow_operations_or_stability_pool_or_vessel();
            let safety_transfer_amount = decimals_correction(asset, amount);
            if (safety_transfer_amount == 0) {
                self.reentrancy.end();
                return;
            }

            let old_balance = self.assets_balances.read(asset);
            let new_balance = old_balance - amount;
            self.assets_balances.write(asset, new_balance);

            IERC20Dispatcher { contract_address: asset }.transfer(account, safety_transfer_amount);
            if (self.is_erc20_deposit_contract(account)) {
                IDepositDispatcher { contract_address: account }.received_erc20(asset, amount);
            }
            self.emit(ActivePoolAssetBalanceUpdated { asset, old_balance, new_balance });
            self.emit(AssetSent { account, asset, amount: safety_transfer_amount });
            self.reentrancy.end();
        }

        fn received_erc20(ref self: ContractState, asset: ContractAddress, amount: u256) {
            self.assert_caller_is_borrow_operations_or_default_pool();
            let old_balance = self.assets_balances.read(asset);
            let new_balance = old_balance + amount;
            self.assets_balances.write(asset, new_balance);

            self.emit(ActivePoolAssetBalanceUpdated { asset, old_balance, new_balance });
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
        fn is_erc20_deposit_contract(self: @ContractState, account: ContractAddress) -> bool {
            let address_provider = self.address_provider.read();
            return account == address_provider.get_address(AddressesKey::default_pool)
                || account == address_provider.get_address(AddressesKey::coll_surplus_pool)
                || account == address_provider.get_address(AddressesKey::stability_pool);
        }

        #[inline(always)]
        fn assert_caller_is_borrow_operations_or_default_pool(self: @ContractState) {
            let caller = get_caller_address();
            let address_provider = self.address_provider.read();
            assert(
                caller == address_provider.get_address(AddressesKey::borrower_operations)
                    || caller == address_provider.get_address(AddressesKey::default_pool),
                CommunErrors::CallerNotAuthorized
            );
        }

        #[inline(always)]
        fn assert_caller_is_borrow_operations_or_vessel_manager(self: @ContractState) {
            let caller = get_caller_address();
            let address_provider = self.address_provider.read();
            assert(
                caller == address_provider.get_address(AddressesKey::borrower_operations)
                    || caller == address_provider.get_address(AddressesKey::vessel_manager),
                CommunErrors::CallerNotAuthorized
            );
        }

        #[inline(always)]
        fn assert_caller_is_borrow_operations_or_stability_pool_or_vessel_manager(
            self: @ContractState
        ) {
            let caller = get_caller_address();
            let address_provider = self.address_provider.read();
            assert(
                caller == address_provider.get_address(AddressesKey::borrower_operations)
                    || caller == address_provider.get_address(AddressesKey::stability_pool)
                    || caller == address_provider.get_address(AddressesKey::vessel_manager),
                CommunErrors::CallerNotAuthorized
            );
        }

        #[inline(always)]
        fn assert_caller_is_borrow_operations_or_stability_pool_or_vessel(self: @ContractState) {
            let caller = get_caller_address();
            let address_provider = self.address_provider.read();
            assert(
                caller == address_provider.get_address(AddressesKey::borrower_operations)
                    || caller == address_provider.get_address(AddressesKey::stability_pool)
                    || caller == address_provider.get_address(AddressesKey::vessel_manager)
                    || caller == address_provider
                        .get_address(AddressesKey::vessel_manager_operations),
                CommunErrors::CallerNotAuthorized
            );
        }
    }
}
