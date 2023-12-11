use starknet::ContractAddress;


#[derive(Serde, Drop, Copy, starknet::Store, Default)]
struct FeeRecord {
    from: u256, // timestamp in seconds
    to: u256, // timestamp in seconds
    amount: u256, // refundable fee amount
}

#[starknet::interface]
trait IFeeCollector<TContractState> {
    fn increase_debt(
        ref self: TContractState,
        borrower: ContractAddress,
        asset: ContractAddress,
        fee_amount: u256
    );

    fn decrease_debt(
        ref self: TContractState,
        borrower: ContractAddress,
        asset: ContractAddress,
        payback_fraction: u256
    );

    fn close_debt(ref self: TContractState, borrower: ContractAddress, asset: ContractAddress);

    fn liquidate_debt(ref self: TContractState, borrower: ContractAddress, asset: ContractAddress);

    fn simulate_refund(
        self: @TContractState,
        borrower: ContractAddress,
        asset: ContractAddress,
        payback_fraction: u256
    );

    fn collect_fees(
        ref self: TContractState, borrowers: Span<ContractAddress>, assets: Span<ContractAddress>
    );

    fn handle_redemption_fee(ref self: TContractState, asset: ContractAddress, amount: u256);

    fn set_route_to_SHVT_staking(ref self: TContractState, route_to_SHVT_staking: bool);

    fn get_protocol_revenue_destination(self: @TContractState) -> ContractAddress;

    fn get_fee_record(
        self: @TContractState, borrower: ContractAddress, asset: ContractAddress
    ) -> FeeRecord;
}


#[starknet::contract]
mod FeeCollector {
    use starknet::ContractAddress;
    use shisui::utils::traits::ContractAddressDefault;

    use super::FeeRecord;

    const MIN_FEE_DAYS: u256 = 7;
    const MIN_FEE_FRACTION: u256 = 38461538000000000; // (1/26)e18 fee divided by 26 weeks
    const ONE_DAY_TIMESTAMP: u256 = consteval_int!(24 * 60 * 60);
    const FEE_EXPIRATION_SECONDS: u256 =
        consteval_int!(175 * 24 * 60 * 60); // ~ 6 months, minus one week (MIN_FEE_DAYS)


    mod Errors {
        const FeeCollector__ArrayMismatch: felt252 = 'Array Mismatch';
        const FeeCollector__InvalidSHVTStakingAddress: felt252 = 'Invalid SHVT Staking Address';
    }

    #[storage]
    struct Storage {
        address_provider: ContractAddress,
        // borrower -> asset -> fees
        fee_records: LegacyMap<(ContractAddress, ContractAddress), FeeRecord>,
        // if true, collected fees go to stakers; if false, to the treasury
        route_to_SHVT_staking: bool,
    }

    #[constructor]
    fn constructor(ref self: ContractState, address_provider: ContractAddress) {}


    #[external(v0)]
    impl FeeCollectorImpl of super::IFeeCollector<ContractState> {
        /// Triggered when a vessel is created and again whenever the borrower acquires additional loans.
        /// Collects the minimum fee to the platform, for which there is no refund; holds on to the remaining fees until
        /// debt is paid, liquidated, or expired.
        ///
        /// Attention: this method assumes that (debt token) fee_amount has already been minted and transferred to this contract.
        fn increase_debt(
            ref self: ContractState,
            borrower: ContractAddress,
            asset: ContractAddress,
            fee_amount: u256
        ) {}

        /// Triggered when a vessel is adjusted or closed (and the borrower has paid back/decreased his loan).
        fn decrease_debt(
            ref self: ContractState,
            borrower: ContractAddress,
            asset: ContractAddress,
            payback_fraction: u256
        ) {}

        /// Triggered when a debt is paid in full.
        fn close_debt(ref self: ContractState, borrower: ContractAddress, asset: ContractAddress) {}

        /// Triggered when a vessel is liquidated; in that case, all remaining fees are collected by the platform,
        /// and no refunds are generated.
        fn liquidate_debt(
            ref self: ContractState, borrower: ContractAddress, asset: ContractAddress
        ) {}

        /// Simulates the refund due -if- vessel would be closed at this moment (helper function used by the UI).
        fn simulate_refund(
            self: @ContractState,
            borrower: ContractAddress,
            asset: ContractAddress,
            payback_fraction: u256
        ) {}

        /// Batch collect fees from an array of borrowers/assets.
        fn collect_fees(
            ref self: ContractState, borrowers: Span<ContractAddress>, assets: Span<ContractAddress>
        ) {}

        fn handle_redemption_fee(ref self: ContractState, asset: ContractAddress, amount: u256) {}

        fn get_protocol_revenue_destination(self: @ContractState) -> ContractAddress {
            return Default::default();
        }

        fn get_fee_record(
            self: @ContractState, borrower: ContractAddress, asset: ContractAddress
        ) -> FeeRecord {
            return Default::default();
        }

        fn set_route_to_SHVT_staking(ref self: ContractState, route_to_SHVT_staking: bool) {}
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _decrease_debt(
            ref self: ContractState,
            borrowers: ContractAddress,
            assets: ContractAddress,
            payback_fraction: u256
        ) {}

        fn _create_or_update_fee_record(
            ref self: ContractState, borrower: ContractAddress, asset: ContractAddress, amount: u256
        ) {}
        fn _create_fee_record(
            ref self: ContractState,
            borrower: ContractAddress,
            asset: ContractAddress,
            fee_amount: u256,
            s_record: FeeRecord
        ) {}

        fn _update_fee_record(
            ref self: ContractState,
            borrower: ContractAddress,
            asset: ContractAddress,
            added_amount: u256,
            s_record: FeeRecord
        ) {}
        fn _close_expired_or_liquidated_fee_record(
            ref self: ContractState, borrower: ContractAddress, asset: ContractAddress, amount: u256
        ) {}

        fn _calc_expired_amount(
            self: @ContractState, from: ContractAddress, to: ContractAddress, amount: u256
        ) -> u256 {
            return 0;
        }
        fn _calc_new_duration(
            self: @ContractState,
            remaining_amount: u256,
            remaining_time_to_live: u256,
            added_amount: u256
        ) -> u256 {
            return 0;
        }

        fn _collect_fee(ref self: ContractState, asset: ContractAddress, fee_amount: u256) {}
        fn _refund_fee(
            ref self: ContractState,
            borrower: ContractAddress,
            asset: ContractAddress,
            refund_amount: u256
        ) {}

        fn _route_to_grvt_staking(self: @ContractState) -> bool {
            return false;
        }
        fn _only_timelock(self: @ContractState) {}
        fn _only_borrower_operations(self: @ContractState) {}
        fn _only_vessel_manager(self: @ContractState) {}
        fn _only_borrower_operations_or_vessel_manager(self: @ContractState) {}
    }
}
