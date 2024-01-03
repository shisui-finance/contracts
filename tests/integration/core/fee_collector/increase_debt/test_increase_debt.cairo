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

    (fee_collector, debt_token_address, asset_address, min_fee, max_fee)
}


#[test]
#[should_panic(expected: ('Caller not authorized',))]
fn when_caller_is_not_borrower_operations_it_should_revert() {
    let (fee_collector, _, asset_address, _, max_fee) = test_setup();
    fee_collector.increase_debt(borrower(), asset_address, max_fee);
}

#[test]
fn when_caller_is_borrower_operations_and_first_increase_it_should_create_fee_record() {
    let (fee_collector, debt_token_address, asset_address, min_fee, max_fee) = test_setup();
    let mut spy = spy_events(SpyOn::One(fee_collector.contract_address));
    let expected_amount = max_fee - min_fee;

    let now = get_block_timestamp();

    start_prank(CheatTarget::One(fee_collector.contract_address), borrower_operations_address());
    fee_collector.increase_debt(borrower(), asset_address, max_fee);

    spy
        .assert_emitted(
            @array![
                (
                    fee_collector.contract_address,
                    FeeCollector::Event::FeeRecordUpdated(
                        FeeCollector::FeeRecordUpdated {
                            borrower: borrower(),
                            asset: asset_address,
                            from: now + MIN_FEE_DURATION,
                            to: now + MIN_FEE_DURATION + FEE_EXPIRATION_SECONDS,
                            amount: expected_amount
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
                            amount: min_fee
                        }
                    )
                )
            ]
        );
    assert(spy.events.is_empty(), 'There should be no events');

    let record = IFeeCollectorDispatcher { contract_address: fee_collector.contract_address }
        .get_fee_record(borrower(), asset_address);

    assert(record.amount == expected_amount, 'Wrong record amount');
    assert(record.from == now + MIN_FEE_DURATION, 'Wrong record from');
    assert(record.to == now + MIN_FEE_DURATION + FEE_EXPIRATION_SECONDS, 'Wrong record to');

    assert(
        IERC20Dispatcher { contract_address: debt_token_address }
            .balance_of(fee_collector.contract_address) == expected_amount,
        'Wrong fee collector balance'
    );
    assert(
        IERC20Dispatcher { contract_address: debt_token_address }
            .balance_of(treasury_address()) == min_fee,
        'Invalid treasury balance'
    );
}

#[test]
fn when_caller_is_borrower_operations_and_not_the_first_increase_but_current_timestamp_greater_than_record_to_it_should_create_new_fee_record() {
    let (fee_collector, debt_token_address, asset_address, min_fee, max_fee) = test_setup();
    start_prank(CheatTarget::One(fee_collector.contract_address), borrower_operations_address());

    fee_collector.increase_debt(borrower(), asset_address, max_fee);
    let mut record = IFeeCollectorDispatcher { contract_address: fee_collector.contract_address }
        .get_fee_record(borrower(), asset_address);

    // Warp to the end of the first record
    start_warp(CheatTarget::One(fee_collector.contract_address), record.to + 1);
    let now = record.to + 1;

    // mint some debt tokens to the fee collector
    start_prank(CheatTarget::One(debt_token_address), borrower_operations_address());
    IDebtTokenDispatcher { contract_address: debt_token_address }
        .mint(fee_collector.contract_address, max_fee);
    stop_prank(CheatTarget::One(debt_token_address));
    let mut spy = spy_events(SpyOn::One(fee_collector.contract_address));
    let expected_amount = max_fee - min_fee;

    fee_collector.increase_debt(borrower(), asset_address, max_fee);

    spy
        .assert_emitted(
            @array![
                (
                    fee_collector.contract_address,
                    FeeCollector::Event::FeeRecordUpdated(
                        FeeCollector::FeeRecordUpdated {
                            borrower: borrower(),
                            asset: asset_address,
                            from: now + MIN_FEE_DURATION,
                            to: now + MIN_FEE_DURATION + FEE_EXPIRATION_SECONDS,
                            amount: expected_amount
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
                            amount: max_fee
                        }
                    )
                )
            ]
        );
    assert(spy.events.is_empty(), 'There should be no events');
    record = IFeeCollectorDispatcher { contract_address: fee_collector.contract_address }
        .get_fee_record(borrower(), asset_address);

    assert(record.amount == expected_amount, 'Wrong record amount');
    assert(record.from == now + MIN_FEE_DURATION, 'Wrong record from');
    assert(record.to == now + MIN_FEE_DURATION + FEE_EXPIRATION_SECONDS, 'Wrong record to');

    assert(
        IERC20Dispatcher { contract_address: debt_token_address }
            .balance_of(fee_collector.contract_address) == expected_amount,
        'Wrong fee collector balance'
    );
    assert(
        IERC20Dispatcher { contract_address: debt_token_address }
            .balance_of(treasury_address()) == min_fee
            + max_fee,
        'Invalid treasury balance'
    );
}

#[test]
fn when_caller_is_borrower_operations_and_not_the_first_increase_and_current_timestamp_lower_than_record_to_it_should_update_fee_record() {
    let (fee_collector, debt_token_address, asset_address, min_fee, max_fee) = test_setup();
    start_prank(CheatTarget::One(fee_collector.contract_address), borrower_operations_address());
    fee_collector.increase_debt(borrower(), asset_address, max_fee);
    let mut record = IFeeCollectorDispatcher { contract_address: fee_collector.contract_address }
        .get_fee_record(borrower(), asset_address);
    let to1 = record.to;
    let from1 = record.from;
    let amount1 = record.amount;

    // 50% of the time has passed
    let now = ((record.to - get_block_timestamp()) / 2);
    start_warp(CheatTarget::One(fee_collector.contract_address), now);

    // mint some debt tokens to the fee collector
    start_prank(CheatTarget::One(debt_token_address), borrower_operations_address());
    IDebtTokenDispatcher { contract_address: debt_token_address }
        .mint(fee_collector.contract_address, max_fee);
    stop_prank(CheatTarget::One(debt_token_address));
    let mut spy = spy_events(SpyOn::One(fee_collector.contract_address));

    fee_collector.increase_debt(borrower(), asset_address, max_fee);

    let expected_expired_amount = calc_expired_amount(now, from1, to1, amount1);

    let expected_remaining_amount = amount1 - expected_expired_amount;
    let expected_treasury_balance = (max_fee / 2) + min_fee;
    let expected_fee_collector_balance = expected_remaining_amount + (max_fee - min_fee);

    let expected_new_duration = calc_new_duration(
        expected_remaining_amount, to1 - now, max_fee - min_fee
    );

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
                            to: now + expected_new_duration,
                            amount: expected_remaining_amount + (max_fee - min_fee)
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
                            amount: min_fee + expected_expired_amount
                        }
                    )
                )
            ]
        );
    assert(spy.events.is_empty(), 'There should be no events');
    record = IFeeCollectorDispatcher { contract_address: fee_collector.contract_address }
        .get_fee_record(borrower(), asset_address);

    assert_is_approximately_equal(
        record.amount, expected_fee_collector_balance, ERROR_MARGIN, 'Invalid record amount'
    );
    assert(record.from == now, 'Wrong record from');
    assert(record.to == now + expected_new_duration, 'Wrong record to');

    assert_is_approximately_equal(
        IERC20Dispatcher { contract_address: debt_token_address }
            .balance_of(fee_collector.contract_address),
        expected_fee_collector_balance,
        ERROR_MARGIN,
        'Wrong fee collector balance'
    );

    assert_is_approximately_equal(
        IERC20Dispatcher { contract_address: debt_token_address }.balance_of(treasury_address()),
        expected_treasury_balance,
        ERROR_MARGIN,
        'Invalid treasury balance'
    );
}
