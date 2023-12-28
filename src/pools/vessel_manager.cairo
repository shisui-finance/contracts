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

    fn get_pending_rewards(
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
    ) -> felt252;

    fn get_vessel_stake(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> u256;

    fn get_vessel_debt(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> u256;

    fn get_vessel_collateral(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> u256;

    fn get_tcr(self: @TContractState, asset: ContractAddress, borrower: ContractAddress) -> u256;

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
    use shisui::{core::{address_provider::{
                IAddressProviderDispatcher, IAddressProviderDispatcherTrait, AddressesKey
            },
            debt_token::{
                IDebtTokenDispatcher, IDebtTokenDispatcherTrait
            },
            },
            utils::errors::CommunErrors
            };
    use starknet::{ContractAddress, get_caller_address};

    const MINUTE_DECAY: u256 = 999037758833783000;

    enum VesselManagerOperation {
        apply_pending_rewards,
        liquidate_in_normal_mode,
        liquidate_in_recovery_mode,
        redeem_collateral
    }

    #[derive(Drop)]
    struct Vessel {
        debt: u256,
        collateral: ContractAddress,
        stake: u256,
        operation: VesselManagerOperation
    }

    #[storage]
    struct Storage {
        address_provider: IAddressProviderDispatcher,
        vessels: LegacyMap<(ContractAddress, ContractAddress), Vessel>,
        total_stakes: LegacyMap<ContractAddress, u256>
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
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn int_redeem_close_vessel(
            ref self: ContractState, asset: ContractAddress, liquidator: ContractAddress, debt_token_amount: u256, asset_amount: u256
        ) -> () {
            self.execute_partial_redemption(asset, borrower, amount);
            self.close_vessel(asset, borrower);
        }

        fn int_remove_stake(ref self: ContractState, asset: ContractAddress, borrower: ContractAddress) -> () {
            self.total_stakes.write(asset, 0);
            let mut updated_vessel = self.vessels.read((asset, borrower));
            updated_vessel.stake = 0;
            self.vessels.write((asset, borrower), updated_vessel);
        }

        #[inline(always)]
        fn only_vessel_manager_operations(self: @ContractState) {
            let caller = get_caller_address();
            let vessel_manager_operations = self.address_provider.read().get_address(AddressesKey::vessel_manager_operations);
            assert(caller == vessel_manager_operations, CommunErrors::CommunErrors__CallerNotAuthorized);
        }

        #[inline(always)]
        fn only_borrower_operations(self: @ContractState) {
            let caller = get_caller_address();
            let borrower_operations = self.address_provider.read().get_address(AddressesKey::borrower_operations);
            assert(caller == borrower_operations, CommunErrors::CommunErrors__CallerNotAuthorized);
        }

        #[inline(always)]
        fn only_vessel_manager_or_borrower_operations(self: @ContractState) {
            let caller = get_caller_address();
            let vessel_manager_operations = self.address_provider.read().get_address(AddressesKey::vessel_manager_operations);
            let borrower_operations = self.address_provider.read().get_address(AddressesKey::borrower_operations);
            assert(caller == vessel_manager_operations || caller == borrower_operations, CommunErrors::CommunErrors__CallerNotAuthorized);
        }
    }
}