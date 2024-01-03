use starknet::ContractAddress;


#[derive(Serde, Drop, Copy, starknet::Store, Default)]
struct FeeRecord {
    amount: u256, // refundable fee amount
    from: u64, // timestamp in seconds
    to: u64, // timestamp in seconds
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
    ) -> u256;

    fn collect_fees(
        ref self: TContractState, borrowers: Span<ContractAddress>, assets: Span<ContractAddress>
    );

    fn handle_redemption_fee(ref self: TContractState, asset: ContractAddress, amount: u256);

    fn set_is_route_to_SHVT_staking(ref self: TContractState, is_route_to_SHVT_staking: bool);

    fn get_is_route_to_SHVT_staking(self: @TContractState) -> bool;

    fn get_protocol_revenue_destination(self: @TContractState) -> ContractAddress;

    fn get_fee_record(
        self: @TContractState, borrower: ContractAddress, asset: ContractAddress
    ) -> FeeRecord;

    fn get_min_fee_duration(self: @TContractState) -> u64;

    fn get_fee_expiration_seconds(self: @TContractState) -> u64;

    fn get_min_fee_fraction(self: @TContractState) -> u256;

    fn get_precision(self: @TContractState) -> u256;
}


#[starknet::contract]
mod FeeCollector {
    use core::array::SpanTrait;
    use snforge_std::PrintTrait;
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use shisui::utils::{
        errors::CommunErrors, traits::ContractAddressDefault, asserts::assert_address_non_zero,
        constants::ONE
    };
    use shisui::core::{
        address_provider::{
            IAddressProviderDispatcher, IAddressProviderDispatcherTrait, AddressesKey
        },
        debt_token::{IDebtTokenDispatcher, IDebtTokenDispatcherTrait}
    };

    use shisui::shvt::shvt_staking::{ISHVTStakingDispatcher, ISHVTStakingDispatcherTrait};

    use super::{IFeeCollector, FeeRecord};
    const MIN_FEE_DURATION: u64 = consteval_int!(7 * 24 * 60 * 60); // 7 days
    const ONE_DAY_TIMESTAMP: u64 = consteval_int!(24 * 60 * 60);
    const FEE_EXPIRATION_SECONDS: u64 =
        consteval_int!(175 * 24 * 60 * 60); // ~ 6 months, minus one week (MIN_FEE_DURATION)
    const MIN_FEE_FRACTION: u256 = 38461538000000000; // (1/26)e18 fee divided by 26 weeks
    const PRECISION: u256 = 1_000000000; // 1e9

    mod FeeCollectorErrors {
        const PaybackFractionExceedOne: felt252 = 'Payback fraction exceed 10e18';
        const ArrayMismatch: felt252 = 'Array Mismatch';
    }

    #[storage]
    struct Storage {
        address_provider: IAddressProviderDispatcher,
        // borrower -> asset -> fees
        fee_records: LegacyMap<(ContractAddress, ContractAddress), FeeRecord>,
        // if true, collected fees go to stakers; if false, to the treasury
        is_route_to_SHVT_staking: bool,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        FeeRecordUpdated: FeeRecordUpdated,
        FeeCollected: FeeCollected,
        FeeRefunded: FeeRefunded,
        RedemptionFeeCollected: RedemptionFeeCollected
    }


    #[derive(Drop, starknet::Event)]
    struct FeeRecordUpdated {
        borrower: ContractAddress,
        asset: ContractAddress,
        from: u64,
        to: u64,
        amount: u256
    }

    #[derive(Drop, starknet::Event)]
    struct FeeCollected {
        borrower: ContractAddress,
        asset: ContractAddress,
        collector: ContractAddress,
        amount: u256
    }

    #[derive(Drop, starknet::Event)]
    struct FeeRefunded {
        borrower: ContractAddress,
        asset: ContractAddress,
        amount: u256
    }

    #[derive(Drop, starknet::Event)]
    struct RedemptionFeeCollected {
        asset: ContractAddress,
        amount: u256
    }

    #[constructor]
    fn constructor(ref self: ContractState, address_provider: IAddressProviderDispatcher) {
        assert_address_non_zero(address_provider.contract_address);
        self.address_provider.write(address_provider);
    }


    #[external(v0)]
    impl FeeCollectorImpl of IFeeCollector<ContractState> {
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
        ) {
            self.assert_caller_is_borrower_operations();
            let min_fee_amount = (MIN_FEE_FRACTION * fee_amount) / ONE;
            let refundable_fee_amount = fee_amount - min_fee_amount;
            let fee_to_collect = self
                .create_or_update_fee_record(borrower, asset, refundable_fee_amount);
            InternalFunctions::collect_fee(
                ref self, borrower, asset, min_fee_amount + fee_to_collect
            );
        }

        /// Triggered when a vessel is adjusted or closed (and the borrower has paid back/decreased his loan).
        fn decrease_debt(
            ref self: ContractState,
            borrower: ContractAddress,
            asset: ContractAddress,
            payback_fraction: u256
        ) {
            self.assert_caller_is_borrower_operations_or_vessel_manager();
            InternalFunctions::decrease_debt(ref self, borrower, asset, payback_fraction);
        }

        /// Triggered when a debt is paid in full.
        fn close_debt(ref self: ContractState, borrower: ContractAddress, asset: ContractAddress) {
            self.assert_caller_is_borrower_operations_or_vessel_manager();
            InternalFunctions::decrease_debt(ref self, borrower, asset, ONE);
        }

        /// Triggered when a vessel is liquidated; in that case, all remaining fees are collected by the platform,
        /// and no refunds are generated.
        fn liquidate_debt(
            ref self: ContractState, borrower: ContractAddress, asset: ContractAddress
        ) {
            self.assert_caller_is_vessel_manager();
            let record = self.fee_records.read((borrower, asset));
            if record.amount.is_non_zero() {
                InternalFunctions::close_expired_or_liquidated_fee_record(
                    ref self, borrower, asset, record.amount
                );
            }
        }

        /// Simulates the refund due -if- vessel would be closed at this moment (helper function used by the UI).
        fn simulate_refund(
            self: @ContractState,
            borrower: ContractAddress,
            asset: ContractAddress,
            payback_fraction: u256
        ) -> u256 {
            assert(payback_fraction <= ONE, FeeCollectorErrors::PaybackFractionExceedOne);
            assert(payback_fraction.is_non_zero(), CommunErrors::CantBeZero);
            let mut record = self.fee_records.read((borrower, asset));
            if (record.amount.is_zero() || record.to < get_block_timestamp()) {
                return 0;
            }
            let expired_amount = InternalFunctions::calc_expired_amount(
                self, record.from, record.to, record.amount
            );
            if (payback_fraction == ONE) {
                // full payback
                return record.amount - expired_amount;
            }
            // calc refund amount proportional to the payment
            return ((record.amount - expired_amount) * payback_fraction) / ONE;
        }

        /// Batch collect fees from an array of borrowers/assets.
        fn collect_fees(
            ref self: ContractState,
            mut borrowers: Span<ContractAddress>,
            mut assets: Span<ContractAddress>
        ) {
            assert(
                borrowers.len() == assets.len() && !borrowers.is_empty(),
                FeeCollectorErrors::ArrayMismatch
            );
            let now = get_block_timestamp();

            loop {
                match borrowers.pop_front() {
                    Option::Some(borrower) => {
                        let asset = assets.pop_front().unwrap();
                        let mut record = self.fee_records.read((*borrower, *asset));
                        let expired_amount = InternalFunctions::calc_expired_amount(
                            @self, record.from, record.to, record.amount
                        );
                        if expired_amount.is_non_zero() {
                            let updated_amount = record.amount - expired_amount;
                            record.amount = updated_amount;
                            record.from = now;
                            InternalFunctions::collect_fee(
                                ref self, *borrower, *asset, expired_amount
                            );
                            self.fee_records.write((*borrower, *asset), record);
                            self
                                .emit(
                                    FeeRecordUpdated {
                                        borrower: *borrower,
                                        asset: *asset,
                                        from: now,
                                        to: record.to,
                                        amount: updated_amount
                                    }
                                );
                        }
                    },
                    Option::None => { break; }
                }
            };
        }

        // Triggered by VesselManager.finalize_redemption(); assumes amount of asset has been already transferred to
        //  get_protocol_revenue_destination().
        fn handle_redemption_fee(ref self: ContractState, asset: ContractAddress, amount: u256) {
            self.assert_caller_is_vessel_manager();
            if self.is_route_to_shvt_staking() {
                ISHVTStakingDispatcher {
                    contract_address: self
                        .address_provider
                        .read()
                        .get_address(AddressesKey::shvt_staking)
                }
                    .increase_fee_asset(asset, amount);
            }
            self.emit(RedemptionFeeCollected { asset, amount });
        }

        fn get_protocol_revenue_destination(self: @ContractState) -> ContractAddress {
            let address_provider = self.address_provider.read();
            if self.is_route_to_shvt_staking() {
                return address_provider.get_address(AddressesKey::shvt_staking);
            }
            return address_provider.get_address(AddressesKey::treasury);
        }

        fn get_fee_record(
            self: @ContractState, borrower: ContractAddress, asset: ContractAddress
        ) -> FeeRecord {
            return self.fee_records.read((borrower, asset));
        }

        fn set_is_route_to_SHVT_staking(ref self: ContractState, is_route_to_SHVT_staking: bool) {
            self.assert_caller_is_timelock();
            self.is_route_to_SHVT_staking.write(is_route_to_SHVT_staking);
        }

        fn get_is_route_to_SHVT_staking(self: @ContractState) -> bool {
            return self.is_route_to_SHVT_staking.read();
        }

        fn get_min_fee_duration(self: @ContractState) -> u64 {
            return MIN_FEE_DURATION;
        }

        fn get_fee_expiration_seconds(self: @ContractState) -> u64 {
            return FEE_EXPIRATION_SECONDS;
        }

        fn get_min_fee_fraction(self: @ContractState) -> u256 {
            return MIN_FEE_FRACTION;
        }

        fn get_precision(self: @ContractState) -> u256 {
            return PRECISION;
        }
    }
    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        #[inline(always)]
        fn decrease_debt(
            ref self: ContractState,
            borrower: ContractAddress,
            asset: ContractAddress,
            payback_fraction: u256
        ) {
            assert(payback_fraction <= ONE, FeeCollectorErrors::PaybackFractionExceedOne);
            assert(payback_fraction.is_non_zero(), CommunErrors::CantBeZero);
            let mut record: FeeRecord = self.fee_records.read((borrower, asset));
            if record.amount.is_zero() {
                return;
            }
            let now = get_block_timestamp();
            if (record.to <= now) {
                self.close_expired_or_liquidated_fee_record(borrower, asset, record.amount);
            } else {
                // collect expired refund
                let expired_amount = self
                    .calc_expired_amount(record.from, record.to, record.amount);

                self.collect_fee(borrower, asset, expired_amount);

                if (payback_fraction == ONE) {
                    // on a full payback, there's no refund; refund amount is discounted from final payment
                    let refund_amount = record.amount - expired_amount;
                    IDebtTokenDispatcher {
                        contract_address: self
                            .address_provider
                            .read()
                            .get_address(AddressesKey::debt_token)
                    }
                        .burn_from_whitelisted_contract(refund_amount);
                    record.amount = 0;
                    self.emit(FeeRecordUpdated { borrower, asset, from: now, to: 0, amount: 0 });
                } else {
                    // refund amount proportional to the payment
                    let refund_amount = ((record.amount - expired_amount) * payback_fraction) / ONE;

                    self.refund_fee(borrower, asset, refund_amount);
                    let updated_amount = record.amount - expired_amount - refund_amount;
                    record.amount = updated_amount;
                    record.from = now;

                    self
                        .emit(
                            FeeRecordUpdated {
                                borrower, asset, from: now, to: record.to, amount: updated_amount
                            }
                        );
                }
                self.fee_records.write((borrower, asset), record);
            }
        }

        #[inline(always)]
        fn create_or_update_fee_record(
            ref self: ContractState, borrower: ContractAddress, asset: ContractAddress, amount: u256
        ) -> u256 {
            let mut record = self.fee_records.read((borrower, asset));
            if (record.amount.is_zero() || record.to <= get_block_timestamp()) {
                let fee_to_collect = record.amount;
                self.create_fee_record(borrower, asset, amount, ref record);
                return fee_to_collect;
            }
            return self.update_fee_record(borrower, asset, amount, ref record);
        }

        #[inline(always)]
        fn create_fee_record(
            ref self: ContractState,
            borrower: ContractAddress,
            asset: ContractAddress,
            fee_amount: u256,
            ref record: FeeRecord
        ) {
            let from = get_block_timestamp() + MIN_FEE_DURATION;
            let to = from + FEE_EXPIRATION_SECONDS;
            record.amount = fee_amount;
            record.from = from;
            record.to = to;
            self.fee_records.write((borrower, asset), record);
            self.emit(FeeRecordUpdated { borrower, asset, from, to, amount: fee_amount });
        }

        #[inline(always)]
        fn update_fee_record(
            ref self: ContractState,
            borrower: ContractAddress,
            asset: ContractAddress,
            added_amount: u256,
            ref record: FeeRecord
        ) -> u256 {
            let mut now = get_block_timestamp();

            if (now < record.from) {
                // loan is still in its first week (MIN_FEE_DAYS)
                now = record.from;
            }
            let expired_amount = self.calc_expired_amount(record.from, record.to, record.amount);
            let remaining_amount = record.amount - expired_amount;
            let remaining_time = record.to - now;
            let updated_amount = remaining_amount + added_amount;
            let update_to = now
                + self.calc_new_duration(remaining_amount, remaining_time, added_amount);
            record.amount = updated_amount;
            record.from = now;
            record.to = update_to;
            self.fee_records.write((borrower, asset), record);
            self
                .emit(
                    FeeRecordUpdated {
                        borrower, asset, from: now, to: update_to, amount: updated_amount
                    }
                );

            return expired_amount;
        }

        #[inline(always)]
        fn close_expired_or_liquidated_fee_record(
            ref self: ContractState, borrower: ContractAddress, asset: ContractAddress, amount: u256
        ) {
            self.collect_fee(borrower, asset, amount);
            self.fee_records.write((borrower, asset), Default::default());
            self
                .emit(
                    FeeRecordUpdated {
                        borrower, asset, from: get_block_timestamp(), to: 0, amount: 0
                    }
                )
        }

        #[inline(always)]
        fn calc_expired_amount(self: @ContractState, from: u64, to: u64, amount: u256) -> u256 {
            let now = get_block_timestamp();
            if (from > now) {
                return 0;
            }
            if (now >= to) {
                return amount;
            }
            let decay_rate = (amount * PRECISION) / (to - from).into();
            return ((now - from).into() * decay_rate) / PRECISION;
        }

        #[inline(always)]
        fn calc_new_duration(
            self: @ContractState,
            remaining_amount: u256,
            remaining_time_to_live: u64,
            added_amount: u256
        ) -> u64 {
            let prev_weight = remaining_amount * remaining_time_to_live.into();
            let next_weight = added_amount * FEE_EXPIRATION_SECONDS.into();
            return ((prev_weight + next_weight) / (remaining_amount + added_amount))
                .try_into()
                .unwrap();
        }

        #[inline(always)]
        fn collect_fee(
            ref self: ContractState,
            borrower: ContractAddress,
            asset: ContractAddress,
            fee_amount: u256
        ) {
            if fee_amount.is_non_zero() {
                let collector = self.get_protocol_revenue_destination_internal();
                IERC20Dispatcher {
                    contract_address: self
                        .address_provider
                        .read()
                        .get_address(AddressesKey::debt_token)
                }
                    .transfer(collector, fee_amount);
                if self.is_route_to_shvt_staking() {
                    ISHVTStakingDispatcher {
                        contract_address: self
                            .address_provider
                            .read()
                            .get_address(AddressesKey::shvt_staking)
                    }
                        .increase_fee_debt_token(fee_amount);
                }

                self.emit(FeeCollected { borrower, asset, collector, amount: fee_amount });
            }
        }


        #[inline(always)]
        fn get_protocol_revenue_destination_internal(self: @ContractState) -> ContractAddress {
            let address_provider = self.address_provider.read();
            if self.is_route_to_shvt_staking() {
                return address_provider.get_address(AddressesKey::shvt_staking);
            }
            return address_provider.get_address(AddressesKey::treasury);
        }


        #[inline(always)]
        fn refund_fee(
            ref self: ContractState,
            borrower: ContractAddress,
            asset: ContractAddress,
            refund_amount: u256
        ) {
            if refund_amount.is_non_zero() {
                IERC20Dispatcher {
                    contract_address: self
                        .address_provider
                        .read()
                        .get_address(AddressesKey::debt_token)
                }
                    .transfer(borrower, refund_amount);
                self.emit(FeeRefunded { borrower, asset, amount: refund_amount });
            }
        }

        #[inline(always)]
        fn is_route_to_shvt_staking(self: @ContractState) -> bool {
            return self.is_route_to_SHVT_staking.read();
        }

        #[inline(always)]
        fn assert_caller_is_timelock(self: @ContractState) {
            let caller = get_caller_address();
            let address_provider = self.address_provider.read();
            assert(
                caller == address_provider.get_address(AddressesKey::timelock),
                CommunErrors::CallerNotAuthorized
            );
        }

        #[inline(always)]
        fn assert_caller_is_borrower_operations(self: @ContractState) {
            let caller = get_caller_address();
            let address_provider = self.address_provider.read();
            assert(
                caller == address_provider.get_address(AddressesKey::borrower_operations),
                CommunErrors::CallerNotAuthorized
            );
        }

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
        fn assert_caller_is_borrower_operations_or_vessel_manager(self: @ContractState) {
            let caller = get_caller_address();
            let address_provider = self.address_provider.read();
            assert(
                caller == address_provider.get_address(AddressesKey::borrower_operations)
                    || caller == address_provider.get_address(AddressesKey::vessel_manager),
                CommunErrors::CallerNotAuthorized
            );
        }
    }
}
