use core::array::ArrayTrait;
use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
use snforge_std::{
    start_prank, stop_prank, start_warp, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions,
    PrintTrait
};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

use shisui::core::{
    debt_token::{IDebtTokenDispatcher, IDebtTokenDispatcherTrait},
    fee_collector::{IFeeCollectorDispatcher, IFeeCollectorDispatcherTrait, FeeCollector}
};
use shisui::utils::constants::ONE;
use tests::utils::{
    callers::{vessel_manager_address, borrower_operations_address, borrower, treasury_address},
    constant::{MIN_FEE_DURATION, FEE_EXPIRATION_SECONDS}, asserts::assert_is_approximately_equal
};

use super::super::setup::{setup, calc_fees, calc_new_duration, calc_expired_amount};

const DEBT_AMOUNT: u256 = 100_000000000000000000; // 100e18
const ERROR_MARGIN: u256 = 1_000_000_000; // 1e9

fn test_setup() -> (IFeeCollectorDispatcher, ContractAddress, ContractAddress, u256, u256) {
    let (_, fee_collector, debt_token_address, asset_address) = setup();
    let (min_fee, max_fee) = calc_fees(DEBT_AMOUNT);
    // Mint some debt tokens to the fee collector
    start_prank(CheatTarget::One(debt_token_address), borrower_operations_address());

    IDebtTokenDispatcher { contract_address: debt_token_address }
        .mint(fee_collector.contract_address, max_fee);
    stop_prank(CheatTarget::One(debt_token_address));

    start_prank(CheatTarget::One(fee_collector.contract_address), borrower_operations_address());
    fee_collector.increase_debt(borrower(), asset_address, max_fee);
    stop_prank(CheatTarget::One(fee_collector.contract_address));

    (fee_collector, debt_token_address, asset_address, min_fee, max_fee)
}


#[test]
#[should_panic(expected: ('Caller not authorized',))]
fn when_caller_is_neither_borrower_operations_nor_vessel_manager_it_should_revert() {
    let (fee_collector, _, asset_address, _, max_fee) = test_setup();
    fee_collector.decrease_debt(borrower(), asset_address, max_fee);
}

#[test]
#[should_panic(expected: ('Value is zero',))]
fn when_caller_is_valid_and_payback_fraction_zero_it_should_revert() {
    let (fee_collector, debt_token_address, asset_address, min_fee, max_fee) = test_setup();
    start_prank(CheatTarget::One(fee_collector.contract_address), borrower_operations_address());

    fee_collector.decrease_debt(borrower(), asset_address, 0);
}

#[test]
#[should_panic(expected: ('Payback fraction exceed 10e18',))]
fn when_caller_is_valid_and_payback_fraction_exceed_100_percent_it_should_revert() {
    let (fee_collector, debt_token_address, asset_address, min_fee, max_fee) = test_setup();
    start_prank(CheatTarget::One(fee_collector.contract_address), borrower_operations_address());
    fee_collector.decrease_debt(borrower(), asset_address, ONE + 1);
}


#[test]
fn when_caller_is_valid_and_current_timestamp_lower_than_record_to_and_payback_fraction_is_10e18_it_should_correctly_burn() {
    let (fee_collector, debt_token_address, asset_address, min_fee, max_fee) = test_setup();
    let mut spy = spy_events(SpyOn::One(fee_collector.contract_address));

    start_prank(CheatTarget::One(fee_collector.contract_address), borrower_operations_address());
    let mut record = fee_collector.get_fee_record(borrower(), asset_address);

    // 50% of the time has passed
    let now = ((record.to - get_block_timestamp()) / 2);
    start_warp(CheatTarget::One(fee_collector.contract_address), now);

    let expected_refundable_amount = fee_collector.simulate_refund(borrower(), asset_address, ONE);
    let expected_collected_fee = record.amount - expected_refundable_amount + min_fee;

    fee_collector.decrease_debt(borrower(), asset_address, ONE);

    spy
        .assert_emitted(
            @array![
                (
                    fee_collector.contract_address,
                    FeeCollector::Event::FeeRecordUpdated(
                        FeeCollector::FeeRecordUpdated {
                            borrower: borrower(), asset: asset_address, from: now, to: 0, amount: 0
                        }
                    )
                ),
                (
                    fee_collector.contract_address,
                    FeeCollector::Event::FeeCollected(
                        FeeCollector::FeeCollected {
                            borrower: borrower(),
                            asset: asset_address,
                            collector: treasury_address(),
                            amount: expected_collected_fee - min_fee
                        }
                    )
                )
            ]
        );
    assert(spy.events.is_empty(), 'There should be no event');
    record = fee_collector.get_fee_record(borrower(), asset_address);
    assert(record.amount.is_zero(), 'Invalid record amount');
    assert(
        IERC20Dispatcher { contract_address: debt_token_address }
            .balance_of(fee_collector.contract_address)
            .is_zero(),
        'Invalid fee collector balance'
    );
    assert(
        IERC20Dispatcher { contract_address: debt_token_address }
            .balance_of(treasury_address()) == expected_collected_fee,
        'Invalid fee collector balance'
    );
}

#[test]
fn when_caller_is_valid_and_current_timestamp_lower_than_record_to_and_payback_fraction_is_lower_than_10e18_it_should_correctly_refund() {
    let (fee_collector, debt_token_address, asset_address, min_fee, max_fee) = test_setup();
    let mut spy = spy_events(SpyOn::One(fee_collector.contract_address));

    start_prank(CheatTarget::One(fee_collector.contract_address), borrower_operations_address());
    let mut record = fee_collector.get_fee_record(borrower(), asset_address);
    let from1 = record.from;
    let to1 = record.to;
    let amount1 = record.amount;

    // 50% of the time has passed
    let now = ((record.to - get_block_timestamp()) / 2);
    start_warp(CheatTarget::One(fee_collector.contract_address), now);

    // 50% refund
    let expected_refundable_amount = fee_collector
        .simulate_refund(borrower(), asset_address, ONE / 2);
    let expected_collected_fee = calc_expired_amount(now, from1, to1, amount1);
    let expected_record = amount1 - expected_refundable_amount - expected_collected_fee;
    fee_collector.decrease_debt(borrower(), asset_address, ONE / 2);
    spy
        .assert_emitted(
            @array![
                (
                    fee_collector.contract_address,
                    FeeCollector::Event::FeeRecordUpdated(
                        FeeCollector::FeeRecordUpdated {
                            borrower: borrower(),
                            asset: asset_address,
                            from: now,
                            to: to1,
                            amount: expected_record
                        }
                    )
                ),
                (
                    fee_collector.contract_address,
                    FeeCollector::Event::FeeCollected(
                        FeeCollector::FeeCollected {
                            borrower: borrower(),
                            asset: asset_address,
                            collector: treasury_address(),
                            amount: expected_collected_fee
                        }
                    )
                ),
                (
                    fee_collector.contract_address,
                    FeeCollector::Event::FeeRefunded(
                        FeeCollector::FeeRefunded {
                            borrower: borrower(),
                            asset: asset_address,
                            amount: expected_refundable_amount
                        }
                    )
                )
            ]
        );
    assert(spy.events.is_empty(), 'There should be no event');

    record = fee_collector.get_fee_record(borrower(), asset_address);

    assert(record.amount == expected_record, 'Invalid record amount');
    assert(
        IERC20Dispatcher { contract_address: debt_token_address }
            .balance_of(fee_collector.contract_address) == expected_record,
        'Invalid fee collector balance'
    );
    assert(
        IERC20Dispatcher { contract_address: debt_token_address }
            .balance_of(borrower()) == expected_refundable_amount,
        'Invalid borrowrer redund'
    );

    assert(
        IERC20Dispatcher { contract_address: debt_token_address }
            .balance_of(treasury_address()) == expected_collected_fee
            + min_fee,
        'Invalid treasury balance'
    );
}

#[test]
fn when_caller_is_valid_and_current_timestamp_higher_than_record_to_it_should_correctly_delete_record() {
    let (fee_collector, debt_token_address, asset_address, min_fee, max_fee) = test_setup();
    let mut spy = spy_events(SpyOn::One(fee_collector.contract_address));

    start_prank(CheatTarget::One(fee_collector.contract_address), borrower_operations_address());
    let mut record = fee_collector.get_fee_record(borrower(), asset_address);

    let now = (record.to + 1);
    start_warp(CheatTarget::One(fee_collector.contract_address), now);

    // what ever the payback fraction is, it will be 100% of the record amount
    fee_collector.decrease_debt(borrower(), asset_address, ONE / 2);
    spy
        .assert_emitted(
            @array![
                (
                    fee_collector.contract_address,
                    FeeCollector::Event::FeeRecordUpdated(
                        FeeCollector::FeeRecordUpdated {
                            borrower: borrower(), asset: asset_address, from: now, to: 0, amount: 0
                        }
                    )
                ),
                (
                    fee_collector.contract_address,
                    FeeCollector::Event::FeeCollected(
                        FeeCollector::FeeCollected {
                            borrower: borrower(),
                            asset: asset_address,
                            collector: treasury_address(),
                            amount: max_fee - min_fee
                        }
                    )
                )
            ]
        );
    assert(spy.events.is_empty(), 'There should be no event');

    record = fee_collector.get_fee_record(borrower(), asset_address);

    assert(record.amount.is_zero(), 'Invalid record amount');
    assert(record.to.is_zero(), 'Invalid to value');
    assert(record.from.is_zero(), 'Invalid from value');
    assert(
        IERC20Dispatcher { contract_address: debt_token_address }
            .balance_of(fee_collector.contract_address)
            .is_zero(),
        'Invalid fee collector balance'
    );

    assert(
        IERC20Dispatcher { contract_address: debt_token_address }
            .balance_of(treasury_address()) == max_fee,
        'Invalid treasury balance'
    );
}
