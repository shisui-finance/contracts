use starknet::ContractAddress;

#[starknet::interface]
trait IVesselManager<TContractState> {
    fn execute_full_redemption(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> ();

    fn execute_partial_redemption(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress, amount: u256
    ) -> ();

    fn execute_full_liquidation(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> ();

    fn update_stake_and_total_stake(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> u256;

    fn update_vessel_reward_snapshots(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> ();

    fn add_vessel_owner_to_array(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> felt252;

    fn apply_pending_rewards(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> ();

    fn close_vessel(self: @TContractState, asset: ContractAddress, borrower: ContractAddress) -> ();

    fn close_vessel_liquidation(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> ();

    fn remove_stake(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress, amount: u256
    ) -> ();

    fn set_vessel_status(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress, status: felt252
    ) -> ();

    fn increase_vessel_collateral(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress, amount: u256
    ) -> ();

    fn decrease_vessel_collateral(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress, amount: u256
    ) -> ();

    fn increase_vessel_debt(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress, amount: u256
    ) -> ();

    fn decrease_vessel_debt(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress, amount: u256
    ) -> ();

    fn finalize_redemption(
        self: @TContractState,
        asset: ContractAddress,
        reciever: ContractAddress,
        debt_to_redeem: u256,
        fee: u256,
        total_redemption_rewards: u256
    ) -> ();

    fn redistribute_and_call(
        self: @TContractState,
        asset: ContractAddress,
        debt: u256,
        collateral: u256,
        debt_to_offset: u256,
        coll_to_send_stability_pool: ContractAddress,
    ) -> ();

    fn update_system_snapshots_exclude_coll_remainder(
        self: @TContractState, asset: ContractAddress, coll_remainder: u256
    ) -> ();

    fn move_pending_vessel_rewards_to_active_pool(
        self: @TContractState, asset: ContractAddress, debt_token_amount: u256, asset_amount: u256
    ) -> ();

    fn send_gas_compensation(
        self: @TContractState,
        asset: ContractAddress,
        liquidator: ContractAddress,
        debt_token_amount: u256,
        asset_amount: u256
    ) -> ();

    fn get_vessel_owners_count(self: @TContractState, asset: ContractAddress) -> felt252;

    fn get_vessel_from_owners_array(
        self: @TContractState, asset: ContractAddress, index: felt252
    ) -> ContractAddress;

    fn get_nominal_icr(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> u256;

    fn get_current_icr(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress, price: u256
    ) -> u256;

    fn get_pending_asset_rewards(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> u256;

    fn get_pending_debt_token_rewards(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> u256;

    fn has_pending_rewards(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> bool;

    fn get_entire_debt_and_collateral(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> (u256, u256, u256, u256);

    fn get_redemption_rate(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> u256;

    fn get_redemption_rate_with_decay(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> u256;

    fn get_redemption_fee_with_decay(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> u256;

    fn get_borrowing_rate(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> u256;

    fn get_vessel_status(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> VesselManager::Status;

    fn get_vessel_stake(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> u256;

    fn get_vessel_debt(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> u256;

    fn get_vessel_collateral(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> u256;

    fn get_tcr(self: @TContractState, asset: ContractAddress, price: u256) -> u256;

    fn check_recovery_mode(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> bool;

    fn is_valid_first_redemption_hint(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> bool;

    fn update_base_rate_from_redemption(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> ();

    fn get_redemption_fee(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> u256;

    fn is_vessel_active(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> bool;
}

#[starknet::contract]
mod VesselManager {
    use shisui::pools::vessel_manager::IVesselManager;
use shisui::{
        core::{
            address_provider::{
                IAddressProviderDispatcher, IAddressProviderDispatcherTrait, AddressesKey
            },
            debt_token::{IDebtTokenDispatcher, IDebtTokenDispatcherTrait},
        },
        utils::{errors::CommunErrors, shisui_math::{compute_nominal_cr, compute_cr}},
        pools::{
            active_pool::{IActivePoolDispatcher, IActivePoolDispatcherTrait},
            collateral_surplus_pool::{
                ICollateralSurplusPoolDispatcher, ICollateralSurplusPoolDispatcherTrait
            },
            default_pool::{IDefaultPoolDispatcher, IDefaultPoolDispatcherTrait},
        },
    };
    use starknet::{ContractAddress, get_caller_address};

    const MINUTE_DECAY: u256 = 999037758833783000;
    const DECINMAL_PRECISION: u256 = 1000000000000000000;

    enum Status {
        non_existent,
        active,
        closed_by_owner,
        closed_by_liquidation,
        closed_by_redemption
    }

    enum VesselManagerOperation {
        apply_pending_rewards,
        liquidate_in_normal_mode,
        liquidate_in_recovery_mode,
        redeem_collateral
    }

    #[derive(Drop)]
    struct Vessel {
        debt: u256,
        collateral: u256,
        stake: u256,
        status: Status,
    }

    struct RewardSnapshot {
        asset: u256,
        debt: u256
    }

    #[storage]
    struct Storage {
        address_provider: IAddressProviderDispatcher,
        vessels: LegacyMap<(ContractAddress, ContractAddress), Vessel>,
        total_stakes: LegacyMap<ContractAddress, u256>,
        reward_snpashots: LegacyMap<(ContractAddress, ContractAddress), RewardSnapshot>,
        l_colls: LegacyMap<ContractAddress, u256>,
        l_debts: LegacyMap<ContractAddress, u256>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, address_provider: IAddressProviderDispatcher) {
        self.address_provider.write(address_provider);
    }

    #[external(v0)]
    impl VesselManagerImpl of super::IVesselManager<ContractState> {
        fn execute_full_redemption(
            self: @ContractState, asset: ContractAddress, borrower: ContractAddress
        ) -> () {
            self.only_vessel_manager_operations();
            let (debt, collateral, _, _) = self.get_entire_debt_and_collateral(asset, borrower);
            self.execute_partial_redemption(asset, borrower, debt);
            self.close_vessel(asset, borrower);
            self.redistribute_and_call(asset, debt, collateral, debt, borrower);
        }

        fn get_nominal_icr(
            self: @ContractState, asset: ContractAddress, borrower: ContractAddress
        ) -> u256 {
            let (current_asset, current_debt) = self.get_current_vessel_amounts(asset, borrower);
            return compute_nominal_cr(current_asset, current_debt);
        }

        fn get_current_icr(
            self: @ContractState, asset: ContractAddress, borrower: ContractAddress, price: u256
        ) -> u256 {
            let (current_asset, current_debt) = self.get_current_vessel_amounts(asset, borrower);
            return compute_cr(current_asset, current_debt, price);
        }

        fn get_pending_asset_rewards(
            self: @ContractState, asset: ContractAddress, borrower: ContractAddress
        ) -> u256 {
            let snapshot_asset = self.reward_snpashots.read((asset, borrower)).asset;
            let reward_per_unit_stakes = self.l_colls.read(asset) - snapshot_asset;

            if (reward_per_unit_stakes == 0 || self.is_vessel_active(asset, borrower)) {
                return 0;
            }

            let stake = self.get_vessel_stake(asset, borrower);
            return stake * reward_per_unit_stakes / DECINMAL_PRECISION;
        }

        fn get_pending_debt_token_rewards(
            self: @ContractState, asset: ContractAddress, borrower: ContractAddress
        ) -> u256 {
            let snapshot_debt = self.reward_snpashots.read((asset, borrower)).debt;
            let reward_per_unit_stakes = self.l_debts.read(asset) - snapshot_debt;

            if (reward_per_unit_stakes == 0 || self.is_vessel_active(asset, borrower)) {
                return 0;
            }

            let stake = self.get_vessel_stake(asset, borrower);
            return stake * reward_per_unit_stakes / DECINMAL_PRECISION;
        }

        fn has_pending_rewards(
            self: @ContractState, asset: ContractAddress, borrower: ContractAddress
        ) -> bool {
            if (!self.is_vessel_active(asset, borrower)) {
                return false;
            }

            return self.reward_snpashots.read((asset, borrower)).asset < self.l_colls.read(asset);
        }

        fn is_vessel_active(
            self: @ContractState, asset: ContractAddress, borrower: ContractAddress
        ) -> bool {
            return match self.vessels.read((asset, borrower)).status {
                Status::non_existent => false,
                Status::active => true,
                Status::closed_by_owner => false,
                Status::closed_by_liquidation => false,
                Status::closed_by_redemption => false,
            };
        }

        fn get_tcr(self: @ContractState, asset: ContractAddress, price: u256) -> u256 {
            let (current_asset, current_debt) = self.get_current_vessel_amounts(asset, borrower);
            return current_asset * DECINMAL_PRECISION / current_debt;
        }

        fn get_vessel_status(
            self: @ContractState, asset: ContractAddress, borrower: ContractAddress
        ) -> Status {
            return self.vessels.read((asset, borrower)).status;
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn int_redeem_close_vessel(
            ref self: ContractState,
            asset: ContractAddress,
            borrower: ContractAddress,
            debt_token_amount: u256,
            asset_amount: u256
        ) -> () {
            let debt_token = IDebtTokenDispatcher {
                contract_address: self.address_provider.read().get_address(AddressesKey::debt_token)
            };
            let active_pool = IActivePoolDispatcher {
                contract_address: self
                    .address_provider
                    .read()
                    .get_address(AddressesKey::active_pool)
            };
            let collateral_surplus_pool = ICollateralSurplusPoolDispatcher {
                contract_address: self
                    .address_provider
                    .read()
                    .get_address(AddressesKey::coll_surplus_pool)
            };
            debt_token.burn(borrower, debt_token_amount);
            // Update Active Pool, and send asset to account
            active_pool.decrease_debt(asset, debt_token_amount);
            // send asset from Active Pool to CollSurplus Pool
            collateral_surplus_pool.account_surplus(asset, borrower, asset_amount);
            active_pool.send_asset(asset, collateral_surplus_pool.contract_address, asset_amount);
        }

        fn int_move_pending_vessel_rewards_to_active_pool(
            ref self: ContractState, asset: ContractAddress, debt_token_amount: u256, asset_amount: u256
        ) -> () {
            let default_pool = IDefaultPoolDispatcher {
                contract_address: self
                    .address_provider
                    .read()
                    .get_address(AddressesKey::default_pool)
            };
            let active_pool = IActivePoolDispatcher {
                contract_address: self
                    .address_provider
                    .read()
                    .get_address(AddressesKey::active_pool)
            };

            default_pool.decrease_debt(asset, debt_token_amount);
            active_pool.increase_debt(asset, debt_token_amount);
            default_pool.send_asset_to_active_pool(asset, asset_amount);
        }

        fn int_remove_stake(
            ref self: ContractState, asset: ContractAddress, borrower: ContractAddress
        ) -> () {
            self.total_stakes.write(asset, 0);
            let mut updated_vessel = self.vessels.read((asset, borrower));
            updated_vessel.stake = 0;
            self.vessels.write((asset, borrower), updated_vessel);
        }

        #[inline(always)]
        fn only_vessel_manager_operations(self: @ContractState) {
            let caller = get_caller_address();
            let vessel_manager_operations = self
                .address_provider
                .read()
                .get_address(AddressesKey::vessel_manager_operations);
            assert(
                caller == vessel_manager_operations, CommunErrors::CommunErrors__CallerNotAuthorized
            );
        }

        #[inline(always)]
        fn only_borrower_operations(self: @ContractState) {
            let caller = get_caller_address();
            let borrower_operations = self
                .address_provider
                .read()
                .get_address(AddressesKey::borrower_operations);
            assert(caller == borrower_operations, CommunErrors::CommunErrors__CallerNotAuthorized);
        }

        #[inline(always)]
        fn only_vessel_manager_or_borrower_operations(self: @ContractState) {
            let caller = get_caller_address();
            let vessel_manager_operations = self
                .address_provider
                .read()
                .get_address(AddressesKey::vessel_manager_operations);
            let borrower_operations = self
                .address_provider
                .read()
                .get_address(AddressesKey::borrower_operations);
            assert(
                caller == vessel_manager_operations || caller == borrower_operations,
                CommunErrors::CommunErrors__CallerNotAuthorized
            );
        }

        // #[inline(always)]
        // fn get_current_vessel_amounts(self: @ContractState, asset: ContractAddress, borrower: ContractAddress) -> (
        //     let pending_collateral_reward = self.get_pending_asset_rewards(asset, borrower);
        // )

        #[inline(always)]
        fn get_current_vessel_amounts(
            self: @ContractState, asset: ContractAddress, borrower: ContractAddress
        ) -> (u256, u256) {
            let pending_collateral_reward = self.get_pending_asset_rewards(asset, borrower);
            let pending_debt_token_reward = self.get_pending_debt_token_rewards(asset, borrower);
            let vessel = self.vessels.read((asset, borrower));
            return (pending_collateral_reward + vessel.collateral, pending_debt_token_reward + vessel.debt);
        }
    }
}
