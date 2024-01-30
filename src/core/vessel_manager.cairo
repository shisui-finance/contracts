use starknet::ContractAddress;


// *************************************************************************
//                              ENUM
// *************************************************************************
#[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
enum Status {
    #[default]
    NonExistent,
    Active,
    ClosedByOwner,
    ClosedByLiquidation,
    ClosedByRedemption
}

#[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
enum VesselManagerOperation {
    ApplyPendingRewards,
    LiquidateInNormalMode,
    LiquidateInRecoveryMode,
    RedeemCollateral
}

// *************************************************************************
//                              STRUCT
// *************************************************************************
#[derive(Copy, Drop, Serde, starknet::Store)]
struct Vessel {
    debt: u256,
    coll: u256,
    stake: u256,
    status: Status,
    array_index: u32
}

// Object containing the asset and debt token snapshots for a given active vessel
#[derive(Copy, Drop, Serde, Default, starknet::Store)]
struct RewardSnapshot {
    asset: u256,
    debt: u256
}


#[starknet::interface]
trait IVesselManager<TContractState> {
    fn get_address_provider(self: @TContractState) -> ContractAddress;
    // Return the nominal collateral ratio (ICR) of a given Vessel, without the price. Takes a vessel's pending coll and debt rewards from redistributions into account.
    fn get_nominal_icr(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> u256;
    // Return the current collateral ratio (ICR) of a given Vessel. Takes a vessel's pending coll and debt rewards from redistributions into account.
    fn get_current_icr(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress, price: u256
    ) -> u256;
    // Get the borrower's pending accumulated asset reward, earned by their stake
    fn get_pending_asset_reward(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> u256;
    // Get the borrower's pending accumulated debt token reward, earned by their stake
    fn get_pending_debt_token_reward(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> u256;
    fn has_pending_rewards(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> bool;
    //return debt,coll,pending_debt_reward, pending_coll_reward
    fn get_entire_debt_and_coll(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> (u256, u256, u256, u256);

    fn is_vessel_active(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> bool;

    fn get_tcr(self: @TContractState, asset: ContractAddress, price: u256) -> u256;
    fn check_recovery_mode(self: @TContractState, asset: ContractAddress, price: u256) -> bool;
    fn get_borrowing_rate(self: @TContractState, asset: ContractAddress) -> u256;
    fn get_borrowing_fee(self: @TContractState, asset: ContractAddress, debt: u256) -> u256;
    fn get_redemption_fee(self: @TContractState, asset: ContractAddress, asset_draw: u256) -> u256;
    fn get_redemption_fee_with_decay(
        self: @TContractState, asset: ContractAddress, asset_draw: u256
    ) -> u256;
    fn get_redemption_rate(self: @TContractState, asset: ContractAddress) -> u256;
    fn get_redemption_rate_with_decay(self: @TContractState, asset: ContractAddress) -> u256;
    fn add_vessel_owner_to_array(
        ref self: TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> u256;
    fn execute_full_redemption(
        ref self: TContractState, asset: ContractAddress, borrower: ContractAddress, new_coll: u256
    );
    fn execute_partial_redemption(
        ref self: TContractState,
        asset: ContractAddress,
        borrower: ContractAddress,
        new_debt: u256,
        new_coll: u256,
        new_nicr: u256,
        upper_partial_redemption_hint: ContractAddress,
        low_partal_redemption_hint: ContractAddress
    );
    fn finalize_redemption(
        ref self: TContractState,
        asset: ContractAddress,
        receiver: ContractAddress,
        debt_token_to_redeem: u256,
        asset_fee_amount: u256,
        asset_redeemed_amount: u256
    );
    fn update_base_rate_from_redemption(
        ref self: TContractState,
        asset: ContractAddress,
        asset_drawn: u256,
        price: u256,
        total_debt_token_supply: u256
    ) -> u256;
    fn apply_pending_rewards(
        ref self: TContractState, asset: ContractAddress, borrower: ContractAddress
    );
    // Move a Vessel's pending debt and collateral rewards from distributions, from the Default Pool to the Active Pool
    fn move_pending_vessel_rewards_to_active_pool(
        ref self: TContractState, asset: ContractAddress, debt: u256, asset_amount: u256
    );
    // Update borrower's snapshots of L_Colls and L_Debts to reflect the current values
    fn update_vessel_reward_snapshots(
        ref self: TContractState, asset: ContractAddress, borrower: ContractAddress
    );
    fn update_stake_and_total_stakes(
        ref self: TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> u256;

    fn remove_stake(ref self: TContractState, asset: ContractAddress, borrower: ContractAddress);
    fn redistribute_debt_and_coll(
        ref self: TContractState,
        asset: ContractAddress,
        debt: u256,
        coll: u256,
        debt_to_offset: u256,
        coll_to_sent_to_stability_pool: u256
    );
    fn update_system_snapshots_exclude_coll_remainder(
        ref self: TContractState, asset: ContractAddress, coll_remainder: u256
    );
    fn close_vessel(
        ref self: TContractState,
        asset: ContractAddress,
        borrower: ContractAddress,
        closed_status: Status
    );
    fn close_vessel_liquidation(
        ref self: TContractState, asset: ContractAddress, borrower: ContractAddress
    );
    fn send_gas_compensation(
        ref self: TContractState,
        asset: ContractAddress,
        liquidator: ContractAddress,
        debt_token_amount: u256,
        asset_amount: u256
    );
    fn get_vessel_status(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> Status;
    fn get_vessel_stake(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> u256;
    fn get_vessel_debt(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> u256;
    fn get_vessel_coll(
        self: @TContractState, asset: ContractAddress, borrower: ContractAddress
    ) -> u256;
    fn get_vessel_owners_count(self: @TContractState, asset: ContractAddress) -> u32;
    fn get_vessel_from_vessel_owners_array(
        self: @TContractState, asset: ContractAddress, index: u32
    ) -> Option<ContractAddress>;
    fn set_vessel_status(
        ref self: TContractState, asset: ContractAddress, borrower: ContractAddress, status: Status
    );
    fn increase_vessel_coll(
        ref self: TContractState,
        asset: ContractAddress,
        borrower: ContractAddress,
        coll_increase: u256
    ) -> u256;
    fn decrease_vessel_coll(
        ref self: TContractState,
        asset: ContractAddress,
        borrower: ContractAddress,
        coll_decrease: u256
    ) -> u256;
    fn increase_vessel_debt(
        ref self: TContractState,
        asset: ContractAddress,
        borrower: ContractAddress,
        debt_increase: u256
    ) -> u256;
    fn decrease_vessel_debt(
        ref self: TContractState,
        asset: ContractAddress,
        borrower: ContractAddress,
        debt_decrease: u256
    ) -> u256;
}

#[starknet::contract]
mod VesselManager {
    use core::traits::Into;
    use openzeppelin::security::reentrancyguard::ReentrancyGuardComponent::InternalTrait;
    use starknet::{
        ContractAddress, contract_address_const, get_caller_address, get_contract_address,
        get_block_timestamp, call_contract_syscall
    };
    use shisui::core::address_provider::{
        IAddressProviderDispatcher, IAddressProviderDispatcherTrait, AddressesKey
    };
    use shisui::core::admin_contract::{IAdminContractDispatcher, IAdminContractDispatcherTrait,};
    use shisui::core::debt_token::{IDebtTokenDispatcher, IDebtTokenDispatcherTrait,};
    use shisui::core::fee_collector::{IFeeCollectorDispatcher, IFeeCollectorDispatcherTrait,};
    use shisui::core::vessel_manager::IVesselManager;
    use shisui::utils::{shisui_math, shisui_base, constants::DECIMAL_PRECISION};
    use super::{RewardSnapshot, Vessel, Status, VesselManagerOperation};
    use openzeppelin::security::reentrancyguard::ReentrancyGuardComponent;
    use alexandria_storage::list::{List, ListTrait};
    use core::cmp::{min, max};
    use snforge_std::{PrintTrait};


    // *************************************************************************
    //                              COMPONENTS
    // *************************************************************************
    component!(
        path: ReentrancyGuardComponent, storage: reentrancy_guard, event: ReentrancyGuardEvent
    );
    impl ReentrancyGuardInternalImpl = ReentrancyGuardComponent::InternalImpl<ContractState>;

    // *************************************************************************
    //                              CONSTANTS
    // *************************************************************************
    const SECONDS_IN_ONE_MINUTE: u8 = 60;

    // Half-life of 12h. 12h = 720 min
    // (1/2) = d^720 => d = (1/2)^(1/720)
    const MINUTE_DECAY_FACTOR: u256 = 999037758833783000;

    // BETA: 18 digit decimal. Parameter by which to divide the redeemed fraction, in order to calc the new base rate from a redemption.
    // Corresponds to (1 / ALPHA) in the white paper.
    const BETA: u8 = 2;

    // *************************************************************************
    //                              ERRORS
    // *************************************************************************
    mod Errors {
        const VesselManager__FeeBiggerThanAssetDraw: felt252 = 'Fee bigger than assert draw';
        const VesselManager__OnlyOneVessel: felt252 = 'Only one vessel';
        const VesselManager__OnlyVesselManagerOperations: felt252 =
            'Only vessel manager operations';
        const VesselManager__OnlyBorrowerOperations: felt252 = 'Only borrower operations';
        const VesselManager__OnlyVesselManagerOperationsOrBorrowerOperations: felt252 =
            'Only vessel mngr op or borrower';
        const VesselManager__WrongVesselStatusWhenClosing: felt252 =
            'Wrong vessel status.Cant close';
        const VesselManager__WrongVesselStatusWhenRemoving: felt252 = 'Wrong vessel status.Cant rm';
        const VesselManager__VesselNotFound: felt252 = 'Vessel not found';
        const VesselManager__BaseRateBelowZero: felt252 = 'Base rate below zero';
        const VesselManager__AssetStakesIsZero: felt252 = 'Asset stake is zero';
    }

    // *************************************************************************
    //                              STORAGE
    // *************************************************************************

    #[storage]
    struct Storage {
        #[substorage(v0)]
        reentrancy_guard: ReentrancyGuardComponent::Storage,
        base_rate: LegacyMap::<ContractAddress, u256>,
        // The timestamp of the latest fee operation (redemption or new debt token issuance)
        last_fee_operation_time: LegacyMap::<ContractAddress, u256>,
        // Vessels[borrower address][Collateral address]
        vessels: LegacyMap::<(ContractAddress, ContractAddress), super::Vessel>,
        total_stakes: LegacyMap::<ContractAddress, u256>,
        // Snapshot of the value of totalStakes, taken immediately after the latest liquidation
        total_stakes_snapshot: LegacyMap::<ContractAddress, u256>,
        // Snapshot of the total collateral across the ActivePool and DefaultPool, immediately after the latest liquidation.
        total_collateral_snapshot: LegacyMap::<ContractAddress, u256>,
        // L_Colls and L_Debts track the sums of accumulated liquidation rewards per unit staked. During its lifetime, each stake earns:
        //
        // An asset gain of ( stake * [L_Colls - L_Colls(0)] )
        // A debt increase of ( stake * [L_Debts - L_Debts(0)] )
        //
        // Where L_Colls(0) and L_Debts(0) are snapshots of L_Colls and L_Debts for the active Vessel taken at the instant the stake was made
        l_colls: LegacyMap::<ContractAddress, u256>,
        l_debts: LegacyMap::<ContractAddress, u256>,
        // Map addresses with active vessels to their RewardSnapshot
        reward_snapshots: LegacyMap::<(ContractAddress, ContractAddress), RewardSnapshot>,
        // Array of all active vessel addresses - used to to compute an approximate hint off-chain, for the sorted list insertion
        vessel_owners: LegacyMap::<ContractAddress, List<ContractAddress>>,
        // Error trackers for the vessel redistribution calculation
        last_coll_error_redistribution: LegacyMap::<ContractAddress, u256>,
        last_debt_error_redistribution: LegacyMap::<ContractAddress, u256>,
        is_setup_initialized: bool,
        address_provider: IAddressProviderDispatcher,
        admin_contract: IAdminContractDispatcher,
        debt_token: IDebtTokenDispatcher,
        fee_collector: IFeeCollectorDispatcher
    }

    // *************************************************************************
    //                              EVENT
    // *************************************************************************
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ReentrancyGuardEvent: ReentrancyGuardComponent::Event,
        VesselIndexUpdated: VesselIndexUpdated,
        VesselUpdated: VesselUpdated,
        BaseRateUpdated: BaseRateUpdated,
        LastFeeOpTimeUpdated: LastFeeOpTimeUpdated,
        VesselSnapshotsUpdated: VesselSnapshotsUpdated,
        TotalStakesUpdated: TotalStakesUpdated,
        SystemSnapshotsUpdated: SystemSnapshotsUpdated,
        LTermsUpdated: LTermsUpdated
    }

    #[derive(Drop, starknet::Event)]
    struct VesselIndexUpdated {
        #[key]
        asset: ContractAddress,
        borrower: ContractAddress,
        new_index: u32
    }

    #[derive(Drop, starknet::Event)]
    struct VesselUpdated {
        #[key]
        asset: ContractAddress,
        #[key]
        borrower: ContractAddress,
        debt: u256,
        coll: u256,
        stake: u256,
        operation: VesselManagerOperation,
    }

    #[derive(Drop, starknet::Event)]
    struct BaseRateUpdated {
        #[key]
        asset: ContractAddress,
        base_rate: u256
    }

    #[derive(Drop, starknet::Event)]
    struct LastFeeOpTimeUpdated {
        #[key]
        asset: ContractAddress,
        last_fee_op_time: u64
    }

    #[derive(Drop, starknet::Event)]
    struct VesselSnapshotsUpdated {
        #[key]
        asset: ContractAddress,
        borrower: ContractAddress,
        l_coll: u256,
        l_debt: u256
    }

    #[derive(Drop, starknet::Event)]
    struct TotalStakesUpdated {
        #[key]
        asset: ContractAddress,
        new_total_stakes: u256
    }

    #[derive(Drop, starknet::Event)]
    struct SystemSnapshotsUpdated {
        #[key]
        asset: ContractAddress,
        total_stakes_snapshot: u256,
        total_collateral_snapshot: u256
    }

    #[derive(Drop, starknet::Event)]
    struct LTermsUpdated {
        #[key]
        asset: ContractAddress,
        l_coll: u256,
        l_debt: u256
    }


    // *************************************************************************
    //                              CONSTRUCTOR
    // *************************************************************************
    #[constructor]
    fn constructor(
        ref self: ContractState,
        address_provider: ContractAddress,
        admin_contract: ContractAddress,
        debt_token: ContractAddress,
        fee_collector: ContractAddress
    ) {
        self
            .address_provider
            .write(IAddressProviderDispatcher { contract_address: address_provider });

        self.admin_contract.write(IAdminContractDispatcher { contract_address: admin_contract });
        self.debt_token.write(IDebtTokenDispatcher { contract_address: debt_token });
        self.fee_collector.write(IFeeCollectorDispatcher { contract_address: fee_collector });
    }

    // *************************************************************************
    //                              EXTERNAL FUNCTIONS
    // *************************************************************************
    #[external(v0)]
    impl VesselManagerImpl of super::IVesselManager<ContractState> {
        fn get_address_provider(self: @ContractState) -> ContractAddress {
            return self.address_provider.read().contract_address;
        }

        // Return the nominal collateral ratio (ICR) of a given Vessel, without the price. Takes a vessel's pending coll and debt rewards from redistributions into account.
        fn get_nominal_icr(
            self: @ContractState, asset: ContractAddress, borrower: ContractAddress
        ) -> u256 {
            let (current_coll, current_debt) = self.get_current_vessel_amounts(asset, borrower);
            shisui_math::compute_nominal_cr(current_coll, current_debt)
        }

        // Return the current collateral ratio (ICR) of a given Vessel. Takes a vessel's pending coll and debt rewards from redistributions into account.
        fn get_current_icr(
            self: @ContractState, asset: ContractAddress, borrower: ContractAddress, price: u256
        ) -> u256 {
            let (current_coll, current_debt) = self.get_current_vessel_amounts(asset, borrower);
            let icr: u256 = shisui_math::compute_cr(current_coll, current_debt, price);
            icr
        }

        // Get the borrower's pending accumulated asset reward, earned by their stake
        fn get_pending_asset_reward(
            self: @ContractState, asset: ContractAddress, borrower: ContractAddress
        ) -> u256 {
            let snapshot_asset = self.reward_snapshots.read((borrower, asset)).asset;
            let reward_per_unit_staked = self.l_colls.read(asset) - snapshot_asset;
            if reward_per_unit_staked == 0 || !self.is_vessel_active(asset, borrower) {
                return 0;
            }
            let stake = self.vessels.read((borrower, asset)).stake;
            (stake * reward_per_unit_staked) / DECIMAL_PRECISION
        }

        // Get the borrower's pending accumulated debt token reward, earned by their stake
        fn get_pending_debt_token_reward(
            self: @ContractState, asset: ContractAddress, borrower: ContractAddress
        ) -> u256 {
            let snapshot_debt = self.reward_snapshots.read((borrower, asset)).debt;
            let reward_per_unit_staked = self.l_debts.read(asset) - snapshot_debt;
            if reward_per_unit_staked == 0 || !self.is_vessel_active(asset, borrower) {
                return 0;
            }
            let stake = self.vessels.read((borrower, asset)).stake;
            (stake * reward_per_unit_staked) / DECIMAL_PRECISION
        }

        fn has_pending_rewards(
            self: @ContractState, asset: ContractAddress, borrower: ContractAddress
        ) -> bool {
            if self.is_vessel_active(asset, borrower) {
                return false;
            }

            self.reward_snapshots.read((borrower, asset)).asset < self.l_colls.read(asset)
        }
        //return debt,coll,pending_debt_reward, pending_coll_reward
        fn get_entire_debt_and_coll(
            self: @ContractState, asset: ContractAddress, borrower: ContractAddress
        ) -> (u256, u256, u256, u256) {
            let pending_debt_reward = self.get_pending_debt_token_reward(asset, borrower);
            let pending_coll_reward = self.get_pending_asset_reward(asset, borrower);
            let vessel = self.vessels.read((borrower, asset));
            let debt = vessel.debt + pending_debt_reward;
            let coll = vessel.coll + pending_coll_reward;

            (debt, coll, pending_debt_reward, pending_coll_reward)
        }

        fn is_vessel_active(
            self: @ContractState, asset: ContractAddress, borrower: ContractAddress
        ) -> bool {
            let status = self.get_vessel_status(asset, borrower);
            status == Status::Active
        }

        fn get_tcr(self: @ContractState, asset: ContractAddress, price: u256) -> u256 {
            shisui_base::get_TCR(self.address_provider.read(), asset, price)
        }

        fn check_recovery_mode(self: @ContractState, asset: ContractAddress, price: u256) -> bool {
            shisui_base::check_recovery_mode(self.address_provider.read(), asset, price)
        }

        fn get_borrowing_rate(self: @ContractState, asset: ContractAddress) -> u256 {
            self.admin_contract.read().get_borrowing_fee(asset)
        }

        fn get_borrowing_fee(self: @ContractState, asset: ContractAddress, debt: u256) -> u256 {
            (self.admin_contract.read().get_borrowing_fee(asset) * debt) / DECIMAL_PRECISION
        }

        fn get_redemption_fee(
            self: @ContractState, asset: ContractAddress, asset_draw: u256
        ) -> u256 {
            self.calc_redemption_fee(self.get_redemption_rate(asset), asset_draw)
        }

        fn get_redemption_fee_with_decay(
            self: @ContractState, asset: ContractAddress, asset_draw: u256
        ) -> u256 {
            self.calc_redemption_fee(self.get_redemption_rate_with_decay(asset), asset_draw)
        }

        fn get_redemption_rate(self: @ContractState, asset: ContractAddress) -> u256 {
            self.calc_redemption_rate(asset, self.base_rate.read(asset))
        }

        fn get_redemption_rate_with_decay(self: @ContractState, asset: ContractAddress) -> u256 {
            self.calc_redemption_rate(asset, self.calc_decayed_base_rate(asset))
        }

        fn add_vessel_owner_to_array(
            ref self: ContractState, asset: ContractAddress, borrower: ContractAddress
        ) -> u256 {
            self.only_borrower_operations();
            let mut asset_owners = self.vessel_owners.read(asset);
            asset_owners.append(borrower);
            let index = asset_owners.len() - 1;
            let mut vessel = self.vessels.read((borrower, asset));
            vessel.array_index = index.into();
            self.vessels.write((borrower, asset), vessel);
            index.into()
        }

        fn execute_full_redemption(
            ref self: ContractState,
            asset: ContractAddress,
            borrower: ContractAddress,
            new_coll: u256
        ) {
            self.remove_stake_internal(asset, borrower);
            self.close_vessel_internal(asset, borrower, Status::ClosedByRedemption);
            self
                .redeem_close_vessel(
                    asset,
                    borrower,
                    self.admin_contract.read().get_debt_token_gas_compensation(asset),
                    new_coll
                );
            self.fee_collector.read().close_debt(borrower, asset);
            self
                .emit(
                    VesselUpdated {
                        asset,
                        borrower,
                        debt: 0,
                        coll: 0,
                        stake: 0,
                        operation: VesselManagerOperation::RedeemCollateral
                    }
                );
        }

        //TODO call ISortedVessels(sortedVessels).reInsert()
        fn execute_partial_redemption(
            ref self: ContractState,
            asset: ContractAddress,
            borrower: ContractAddress,
            new_debt: u256,
            new_coll: u256,
            new_nicr: u256,
            upper_partial_redemption_hint: ContractAddress,
            low_partal_redemption_hint: ContractAddress
        ) {
            //call ISortedVessels(sortedVessels).reInsert()

            let mut vessel = self.vessels.read((borrower, asset));
            let payback_fraction = ((vessel.debt - new_debt) * shisui_math::dec_pow(10, 18))
                / vessel.debt;
            if payback_fraction != 0 {
                self.fee_collector.read().decrease_debt(borrower, asset, payback_fraction);
            }
            // update vessel
            vessel.debt = new_debt;
            vessel.coll = new_coll;
            self.vessels.write((borrower, asset), vessel);

            self.update_stake_and_total_stakes_internal(asset, borrower);
            self
                .emit(
                    VesselUpdated {
                        asset,
                        borrower,
                        debt: new_debt,
                        coll: new_coll,
                        stake: vessel.stake,
                        operation: VesselManagerOperation::RedeemCollateral
                    }
                );
        }

        fn finalize_redemption(
            ref self: ContractState,
            asset: ContractAddress,
            receiver: ContractAddress,
            debt_token_to_redeem: u256,
            asset_fee_amount: u256,
            asset_redeemed_amount: u256
        ) {
            self.only_vessel_manager_operations();
            // Send the asset fee
            if asset_fee_amount != 0 {
                let destination = self.fee_collector.read().get_protocol_revenue_destination();
                // TODO IActivePool(activePool).sendAsset(_asset, destination, _assetFeeAmount);
                self.fee_collector.read().handle_redemption_fee(asset, asset_fee_amount);
            }
            // Burn the total debt tokens that is cancelled with debt, and send the redeemed asset to msg.sender
            self.debt_token.read().burn(receiver, debt_token_to_redeem);
            // Update Active Pool, and send asset to account
            let coll_to_send_to_redeemer = asset_redeemed_amount - asset_fee_amount;
        // TODO IActivePool(activePool).decreaseDebt(_asset, _debtToRedeem);
        // TODO IActivePool(activePool).sendAsset(_asset, _receiver, collToSendToRedeemer);
        }

        fn update_base_rate_from_redemption(
            ref self: ContractState,
            asset: ContractAddress,
            asset_drawn: u256,
            price: u256,
            total_debt_token_supply: u256
        ) -> u256 {
            self.only_vessel_manager_operations();
            let decay_base_rate = self.calc_decayed_base_rate(asset);
            let redeem_debt_fraction = (asset_drawn * price) / total_debt_token_supply;
            let mut new_base_rate = decay_base_rate + (redeem_debt_fraction / BETA.into());
            new_base_rate = min(new_base_rate, DECIMAL_PRECISION);
            assert(new_base_rate != 0, Errors::VesselManager__BaseRateBelowZero);
            self.base_rate.write(asset, new_base_rate);
            self.emit(BaseRateUpdated { asset, base_rate: new_base_rate });
            self.update_last_fee_op_time(asset);
            new_base_rate
        }

        fn apply_pending_rewards(
            ref self: ContractState, asset: ContractAddress, borrower: ContractAddress
        ) {
            self.only_vessel_manager_operations_or_borrower_operations();
            self.reentrancy_guard.start();
            self.apply_pending_rewards_internal(asset, borrower);
            self.reentrancy_guard.end();
        }

        // Move a Vessel's pending debt and collateral rewards from distributions, from the Default Pool to the Active Pool
        fn move_pending_vessel_rewards_to_active_pool(
            ref self: ContractState, asset: ContractAddress, debt: u256, asset_amount: u256
        ) {
            self.only_vessel_manager_operations();
            self.move_pending_vessel_rewards_to_active_pool_internal(asset, debt, asset_amount);
        }

        // Update borrower's snapshots of L_Colls and L_Debts to reflect the current values
        fn update_vessel_reward_snapshots(
            ref self: ContractState, asset: ContractAddress, borrower: ContractAddress
        ) {
            self.only_borrower_operations();
            self.update_vessel_reward_snapshots_internal(asset, borrower);
        }

        fn update_stake_and_total_stakes(
            ref self: ContractState, asset: ContractAddress, borrower: ContractAddress
        ) -> u256 {
            self.only_borrower_operations();
            self.update_stake_and_total_stakes_internal(asset, borrower)
        }

        fn remove_stake(
            ref self: ContractState, asset: ContractAddress, borrower: ContractAddress
        ) {
            self.only_vessel_manager_operations_or_borrower_operations();
            self.remove_stake_internal(asset, borrower);
        }

        // TODO implement IStabilityPool.offset
        // TODO implement IActivePool
        // TODO implement IDefaultPool
        fn redistribute_debt_and_coll(
            ref self: ContractState,
            asset: ContractAddress,
            debt: u256,
            coll: u256,
            debt_to_offset: u256,
            coll_to_sent_to_stability_pool: u256
        ) {
            self.only_vessel_manager_operations();
            self.reentrancy_guard.start();
            // IStabilityPool(stabilityPool).offset(_debtToOffset, _asset, _collToSendToStabilityPool);

            if debt == 0 {
                return;
            }

            // Add distributed coll and debt rewards-per-unit-staked to the running totals. Division uses a "feedback"
            // error correction, to keep the cumulative error low in the running totals L_Colls and L_Debts:
            //
            // 1) Form numerators which compensate for the floor division errors that occurred the last time this
            // function was called.
            // 2) Calculate "per-unit-staked" ratios.
            // 3) Multiply each ratio back by its denominator, to reveal the current floor division error.
            // 4) Store these errors for use in the next correction when this function is called.
            // 5) Note: static analysis tools complain about this "division before multiplication", however, it is intended.
            let coll_numerator = (coll * DECIMAL_PRECISION)
                + self.last_coll_error_redistribution.read(asset);
            let debt_numerator = (debt * DECIMAL_PRECISION)
                + self.last_debt_error_redistribution.read(asset);

            // Get the per-unit-staked terms
            let asset_stakes = self.total_stakes.read(asset);
            let coll_reward_per_unit_staked = coll_numerator / asset_stakes;
            let debt_reward_per_unit_staked = debt_numerator / asset_stakes;

            self
                .last_coll_error_redistribution
                .write(asset, coll_numerator - (coll_reward_per_unit_staked * asset_stakes));
            self
                .last_debt_error_redistribution
                .write(asset, debt_numerator - (debt_reward_per_unit_staked * asset_stakes));

            // Add per-unit-staked terms to the running totals
            let liquidated_coll = self.l_colls.read(asset) + coll_reward_per_unit_staked;
            let liquidated_debt = self.l_debts.read(asset) + debt_reward_per_unit_staked;

            self.l_colls.write(asset, liquidated_coll);
            self.l_debts.write(asset, liquidated_debt);

            self.emit(LTermsUpdated { asset, l_coll: liquidated_coll, l_debt: liquidated_debt });
            // IActivePool(activePool).decreaseDebt(_asset, _debt);
            // IDefaultPool(defaultPool).increaseDebt(_asset, _debt);
            // IActivePool(activePool).sendAsset(_asset, defaultPool, _coll);

            self.reentrancy_guard.end();
        }

        //TODO implement IActivePool,IDefaultPool
        fn update_system_snapshots_exclude_coll_remainder(
            ref self: ContractState, asset: ContractAddress, coll_remainder: u256
        ) {
            self.only_vessel_manager_operations();
            let total_stakes_cached = self.total_stakes.read(asset);
            self.total_stakes_snapshot.write(asset, total_stakes_cached);
        // uint256 activeColl = IActivePool(activePool).getAssetBalance(_asset);
        // uint256 liquidatedColl = IDefaultPool(defaultPool).getAssetBalance(_asset);
        // uint256 _totalCollateralSnapshot = activeColl - _collRemainder + liquidatedColl;
        // totalCollateralSnapshot[_asset] = _totalCollateralSnapshot;
        // emit SystemSnapshotsUpdated(_asset, totalStakesCached, _totalCollateralSnapshot);
        }

        fn close_vessel(
            ref self: ContractState,
            asset: ContractAddress,
            borrower: ContractAddress,
            closed_status: Status
        ) {
            self.only_vessel_manager_operations_or_borrower_operations();
            self.close_vessel_internal(asset, borrower, closed_status);
        }

        fn close_vessel_liquidation(
            ref self: ContractState, asset: ContractAddress, borrower: ContractAddress
        ) {
            self.only_vessel_manager_operations();
            self.close_vessel_internal(asset, borrower, Status::ClosedByLiquidation);
            self.fee_collector.read().liquidate_debt(borrower, asset);
            self
                .emit(
                    VesselUpdated {
                        asset,
                        borrower,
                        debt: 0,
                        coll: 0,
                        stake: 0,
                        operation: VesselManagerOperation::LiquidateInNormalMode
                    }
                );
        }


        // TODO implement IActivePool and call return_from_pool when ready
        fn send_gas_compensation(
            ref self: ContractState,
            asset: ContractAddress,
            liquidator: ContractAddress,
            debt_token_amount: u256,
            asset_amount: u256
        ) {
            self.only_vessel_manager_operations();
            self.reentrancy_guard.start();
            if debt_token_amount != 0 {
                let gas_pool_address = self
                    .address_provider
                    .read()
                    .get_address(AddressesKey::gas_pool);
            // self
            //     .debt_token
            //     .read()
            //     .return_from_pool(gas_pool_address, liquidator, debt_token_amount);
            }

            if asset_amount != 0 { //IActivePool(activePool).sendAsset(_asset, _liquidator, _assetAmount);
            }
            self.reentrancy_guard.end();
        }

        fn get_vessel_status(
            self: @ContractState, asset: ContractAddress, borrower: ContractAddress
        ) -> Status {
            self.vessels.read((borrower, asset)).status
        }

        fn get_vessel_stake(
            self: @ContractState, asset: ContractAddress, borrower: ContractAddress
        ) -> u256 {
            self.vessels.read((borrower, asset)).stake
        }

        fn get_vessel_debt(
            self: @ContractState, asset: ContractAddress, borrower: ContractAddress
        ) -> u256 {
            self.vessels.read((borrower, asset)).debt
        }

        fn get_vessel_coll(
            self: @ContractState, asset: ContractAddress, borrower: ContractAddress
        ) -> u256 {
            self.vessels.read((borrower, asset)).coll
        }

        fn get_vessel_owners_count(self: @ContractState, asset: ContractAddress) -> u32 {
            self.vessel_owners.read(asset).len()
        }

        fn get_vessel_from_vessel_owners_array(
            self: @ContractState, asset: ContractAddress, index: u32
        ) -> Option<ContractAddress> {
            self.vessel_owners.read(asset).get(index)
        }

        fn set_vessel_status(
            ref self: ContractState,
            asset: ContractAddress,
            borrower: ContractAddress,
            status: Status
        ) {
            self.only_borrower_operations();
            let mut vessel = self.vessels.read((borrower, asset));
            vessel.status = status;
            self.vessels.write((borrower, asset), vessel);
        }

        fn increase_vessel_coll(
            ref self: ContractState,
            asset: ContractAddress,
            borrower: ContractAddress,
            coll_increase: u256
        ) -> u256 {
            self.only_borrower_operations();
            let mut vessel = self.vessels.read((borrower, asset));
            let new_coll = vessel.coll + coll_increase;
            vessel.coll = new_coll;
            self.vessels.write((borrower, asset), vessel);
            new_coll
        }

        fn decrease_vessel_coll(
            ref self: ContractState,
            asset: ContractAddress,
            borrower: ContractAddress,
            coll_decrease: u256
        ) -> u256 {
            self.only_borrower_operations();
            let mut vessel = self.vessels.read((borrower, asset));
            let new_coll = vessel.coll - coll_decrease;
            vessel.coll = new_coll;
            self.vessels.write((borrower, asset), vessel);
            new_coll
        }

        fn increase_vessel_debt(
            ref self: ContractState,
            asset: ContractAddress,
            borrower: ContractAddress,
            debt_increase: u256
        ) -> u256 {
            self.only_borrower_operations();
            let mut vessel = self.vessels.read((borrower, asset));
            let new_debt = vessel.debt + debt_increase;
            vessel.debt = new_debt;
            self.vessels.write((borrower, asset), vessel);
            new_debt
        }

        fn decrease_vessel_debt(
            ref self: ContractState,
            asset: ContractAddress,
            borrower: ContractAddress,
            debt_decrease: u256
        ) -> u256 {
            self.only_borrower_operations();
            let mut vessel = self.vessels.read((borrower, asset));
            let old_debt = vessel.debt;
            if debt_decrease == 0 {
                return old_debt; // no changes
            }
            let payback_fraction = (debt_decrease * shisui_math::dec_pow(10, 18)) / old_debt;
            let new_debt = old_debt - debt_decrease;
            vessel.debt = new_debt;
            self.vessels.write((borrower, asset), vessel);
            if payback_fraction != 0 {
                self.fee_collector.read().decrease_debt(borrower, asset, payback_fraction);
            }
            new_debt
        }
    }

    // *************************************************************************
    //                              INTERNAL FUNCTIONS
    // *************************************************************************
    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn only_vessel_manager_operations(self: @ContractState) {
            assert(
                get_caller_address() == self
                    .address_provider
                    .read()
                    .get_address(AddressesKey::vessel_manager_operations),
                Errors::VesselManager__OnlyVesselManagerOperations
            )
        }

        fn only_borrower_operations(self: @ContractState) {
            assert(
                get_caller_address() == self
                    .address_provider
                    .read()
                    .get_address(AddressesKey::borrower_operations),
                Errors::VesselManager__OnlyBorrowerOperations
            )
        }

        fn only_vessel_manager_operations_or_borrower_operations(self: @ContractState) {
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
                caller != vessel_manager_operations && caller != borrower_operations,
                Errors::VesselManager__OnlyVesselManagerOperationsOrBorrowerOperations
            )
        }

        fn get_current_vessel_amounts(
            self: @ContractState, asset: ContractAddress, borrower: ContractAddress
        ) -> (u256, u256) {
            let pending_coll_reward = self.get_pending_asset_reward(asset, borrower);
            let pending_debt_reward = self.get_pending_debt_token_reward(asset, borrower);
            let vessel = self.vessels.read((borrower, asset));
            let coll = vessel.coll + pending_coll_reward;
            let debt = vessel.debt + pending_debt_reward;
            (coll, debt)
        }

        fn remove_stake_internal(
            ref self: ContractState, asset: ContractAddress, borrower: ContractAddress
        ) {
            let mut vessel = self.vessels.read((borrower, asset));
            let new_total_stake = self.total_stakes.read(asset) - vessel.stake;
            self.total_stakes.write(asset, new_total_stake);
            vessel.stake = 0;
        }

        // Update borrower's stake based on their latest collateral value
        fn update_stake_and_total_stakes_internal(
            ref self: ContractState, asset: ContractAddress, borrower: ContractAddress
        ) -> u256 {
            let mut vessel = self.vessels.read((borrower, asset));
            let new_stake = self.compute_new_stake(asset, vessel.coll);
            let old_stake = vessel.stake;
            vessel.stake = new_stake;
            let new_total = self.total_stakes.read(asset) - old_stake + new_stake;
            self.vessels.write((borrower, asset), vessel);
            self.total_stakes.write(asset, new_total);
            self.emit(TotalStakesUpdated { asset, new_total_stakes: new_total });
            new_stake
        }

        // Calculate a new stake based on the snapshots of the totalStakes and totalCollateral taken at the last liquidation
        fn compute_new_stake(self: @ContractState, asset: ContractAddress, coll: u256) -> u256 {
            let asset_coll = self.total_collateral_snapshot.read(asset);
            let mut stake: u256 = 0;
            if asset_coll == 0 {
                return coll;
            } else {
                let asset_stakes = self.total_stakes_snapshot.read(asset);
                // The following assert() holds true because:
                // - The system always contains >= 1 vessel
                // - When we close or liquidate a vessel, we redistribute the pending rewards, so if all vessels were closed/liquidated,
                // rewards would’ve been emptied and totalCollateralSnapshot would be zero too.
                assert(asset_stakes != 0, Errors::VesselManager__AssetStakesIsZero);
                return (coll * asset_stakes) / asset_coll;
            }
        }

        // TODO add check on sortedVessels when contract exist
        fn close_vessel_internal(
            ref self: ContractState,
            asset: ContractAddress,
            borrower: ContractAddress,
            closed_status: Status
        ) {
            assert(
                closed_status != Status::NonExistent && closed_status != Status::Active,
                Errors::VesselManager__WrongVesselStatusWhenClosing
            );
            let vessel_owners_array_length = self.vessel_owners.read(asset).len();
            assert(vessel_owners_array_length > 1, Errors::VesselManager__OnlyOneVessel);

            // update vessel
            let mut vessel = self.vessels.read((borrower, asset));
            vessel.status = closed_status;
            vessel.coll = 0;
            vessel.debt = 0;
            self.vessels.write((borrower, asset), vessel);
            // update reward_snapshot
            let mut snapshot_asset = self.reward_snapshots.read((borrower, asset));
            snapshot_asset.asset = 0;
            snapshot_asset.debt = 0;
            self.reward_snapshots.write((borrower, asset), snapshot_asset);

            self.remove_vessel_owner(asset, borrower, vessel_owners_array_length);
        // TODO remove sorted vessel 
        }

        fn remove_vessel_owner(
            ref self: ContractState,
            asset: ContractAddress,
            borrower: ContractAddress,
            vessel_owners_array_length: u32
        ) {
            let mut vessel = self.vessels.read((borrower, asset));
            assert(
                vessel.status != Status::NonExistent && vessel.status != Status::Active,
                Errors::VesselManager__WrongVesselStatusWhenRemoving
            );

            let index = vessel.array_index;
            let last_index = vessel_owners_array_length - 1;
            assert(index != 0 && index <= last_index.into(), Errors::VesselManager__VesselNotFound);

            let mut vessel_asset_owners = self.vessel_owners.read(asset);
            // Specifically handle case where there is only one vessel_owner
            if index == last_index.into() {
                vessel_asset_owners.pop_front();
                vessel.array_index = 0;
                self.vessels.write((borrower, asset), vessel);
                return;
            }

            let mut last_vessel = vessel_asset_owners.pop_front();
            match last_vessel {
                Option::Some(last_address) => {
                    vessel_asset_owners.set(index, last_address);
                    vessel.array_index = 0;
                    self.vessels.write((borrower, asset), vessel);
                },
                Option::None => {
                    // This case should never happen, because index is always <= length
                    return;
                }
            }

            self.emit(VesselIndexUpdated { asset, borrower, new_index: index });
        }


        fn calc_redemption_rate(
            self: @ContractState, asset: ContractAddress, base_rate: u256
        ) -> u256 {
            min(
                self.admin_contract.read().get_redemption_fee_floor(asset) + base_rate,
                DECIMAL_PRECISION
            )
        }

        fn calc_redemption_fee(
            self: @ContractState, redemption_rate: u256, asset_draw: u256
        ) -> u256 {
            let redemption_fee = (redemption_rate * asset_draw) / DECIMAL_PRECISION;
            assert(redemption_fee < asset_draw, Errors::VesselManager__FeeBiggerThanAssetDraw);
            redemption_fee
        }

        fn calc_decayed_base_rate(self: @ContractState, asset: ContractAddress) -> u256 {
            let minutes_passed = self.minutes_passed_since_last_fee_op(asset);
            let decay_factor = shisui_math::dec_pow(MINUTE_DECAY_FACTOR, minutes_passed);
            (self.base_rate.read(asset) * decay_factor) / DECIMAL_PRECISION
        }

        fn minutes_passed_since_last_fee_op(self: @ContractState, asset: ContractAddress) -> u256 {
            let time_stamp: u256 = get_block_timestamp().into();
            time_stamp - self.last_fee_operation_time.read(asset) / SECONDS_IN_ONE_MINUTE.into()
        }

        // TODO implement function
        fn redeem_close_vessel(
            self: @ContractState,
            asset: ContractAddress,
            borrower: ContractAddress,
            debt_token_amount: u256,
            asset_mount: u256
        ) { //let gas_pool_address = self.address_provider.read().get_address(AddressesKey::gas_pool);
        //self.debt_token.read().burn(gas_pool_address, debt_token_amount);

        }

        //TODO implement function
        fn move_pending_vessel_rewards_to_active_pool_internal(
            ref self: ContractState,
            asset: ContractAddress,
            debt_token_amount: u256,
            asset_amount: u256
        ) { //IDefaultPool(defaultPool).decreaseDebt(_asset, _debtTokenAmount);
        //IActivePool(activePool).increaseDebt(_asset, _debtTokenAmount);
        //IDefaultPool(defaultPool).sendAssetToActivePool(_asset, _assetAmount);
        }

        fn update_vessel_reward_snapshots_internal(
            ref self: ContractState, asset: ContractAddress, borrower: ContractAddress
        ) {
            let liquidated_coll = self.l_colls.read(asset);
            let liquidated_debt = self.l_debts.read(asset);
            let mut snapshot = self.reward_snapshots.read((borrower, asset));
            snapshot.asset = liquidated_coll;
            snapshot.debt = liquidated_debt;
            self.reward_snapshots.write((borrower, asset), snapshot);
            self
                .emit(
                    VesselSnapshotsUpdated {
                        asset, borrower, l_coll: liquidated_coll, l_debt: liquidated_debt
                    }
                );
        }

        // Add the borrowers's coll and debt rewards earned from redistributions, to their Vessel
        fn apply_pending_rewards_internal(
            ref self: ContractState, asset: ContractAddress, borrower: ContractAddress
        ) {
            if !self.has_pending_rewards(asset, borrower) {
                return;
            }

            // Compute pending rewards
            let pending_coll_reward = self.get_pending_asset_reward(asset, borrower);
            let pending_debt_reward = self.get_pending_debt_token_reward(asset, borrower);

            // Apply pending rewards to vessel's state
            let mut vessel = self.vessels.read((borrower, asset));
            vessel.coll = vessel.coll + pending_coll_reward;
            vessel.debt = vessel.debt + pending_debt_reward;
            self.vessels.write((borrower, asset), vessel);

            self.update_vessel_reward_snapshots(asset, borrower);

            // Transfer from DefaultPool to ActivePool
            self
                .move_pending_vessel_rewards_to_active_pool(
                    asset, pending_debt_reward, pending_coll_reward
                );
            self
                .emit(
                    VesselUpdated {
                        asset,
                        borrower,
                        debt: vessel.debt,
                        coll: vessel.debt,
                        stake: vessel.stake,
                        operation: VesselManagerOperation::ApplyPendingRewards
                    }
                );
        }

        fn update_last_fee_op_time(ref self: ContractState, asset: ContractAddress) {
            let time_passed: u256 = get_block_timestamp().into()
                - self.last_fee_operation_time.read(asset);
            if time_passed >= SECONDS_IN_ONE_MINUTE.into() {
                // Update the last fee operation time only if time passed >= decay interval. This prevents base rate griefing.
                self.last_fee_operation_time.write(asset, get_block_timestamp().into());
                self.emit(LastFeeOpTimeUpdated { asset, last_fee_op_time: get_block_timestamp() })
            }
        }
    }
}
