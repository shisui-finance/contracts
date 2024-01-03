use starknet::{ContractAddress, get_block_timestamp};
use snforge_std::{
    start_prank, stop_prank, start_warp, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions,
    PrintTrait
};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

use shisui::core::{
    debt_token::{IDebtTokenDispatcher, IDebtTokenDispatcherTrait},
    fee_collector::{IFeeCollectorDispatcher, IFeeCollectorDispatcherTrait, FeeCollector}
};
use tests::utils::callers::{
    vessel_manager_address, borrower_operations_address, borrower, treasury_address
};
use tests::utils::asserts::assert_is_approximately_equal;

use super::super::setup::{setup, calc_fees};

const DEBT_AMOUNT: u256 = 100_000000000000000000; // 10e18
const ERROR_MARGIN: u256 = 1000000000; // 1e9
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
    let (fee_collector, _, asset_address, _, _) = test_setup();
    fee_collector.close_debt(borrower(), asset_address);
}

#[test]
fn when_caller_is_valid_and_current_timestamp_greater_than_record_to_it_should_send_debt_token_to_right_protocol_revenue_destination() {
    let (fee_collector, debt_token_address, asset_address, min_fee, max_fee) = test_setup();
    let mut spy = spy_events(SpyOn::One(fee_collector.contract_address));

    let record = fee_collector.get_fee_record(borrower(), asset_address);
    start_warp(CheatTarget::One(fee_collector.contract_address), record.to + 1);

    start_prank(CheatTarget::One(fee_collector.contract_address), borrower_operations_address());
    fee_collector.close_debt(borrower(), asset_address);

    spy
        .assert_emitted(
            @array![
                (
                    fee_collector.contract_address,
                    FeeCollector::Event::FeeRecordUpdated(
                        FeeCollector::FeeRecordUpdated {
                            borrower: borrower(),
                            asset: asset_address,
                            from: record.to + 1,
                            to: 0,
                            amount: 0
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
    assert(spy.events.is_empty(), 'There should be no events');

    assert(
        IERC20Dispatcher { contract_address: debt_token_address }
            .balance_of(treasury_address()) == max_fee,
        'Invalid treasury balance'
    );
    assert(
        IERC20Dispatcher { contract_address: debt_token_address }
            .balance_of(fee_collector.contract_address)
            .is_zero(),
        'Invalid fee collector balance'
    );
}

#[test]
fn when_caller_is_valid_and_current_timestamp_lower_than_one_week_it_should_take_the_minium_of_fee() {
    let (fee_collector, debt_token_address, asset_address, min_fee, _) = test_setup();
    let mut spy = spy_events(SpyOn::One(fee_collector.contract_address));
    let now = get_block_timestamp();

    let record = fee_collector.get_fee_record(borrower(), asset_address);

    start_prank(CheatTarget::One(fee_collector.contract_address), vessel_manager_address());
    fee_collector.close_debt(borrower(), asset_address);

    spy
        .assert_emitted(
            @array![
                (
                    fee_collector.contract_address,
                    FeeCollector::Event::FeeRecordUpdated(
                        FeeCollector::FeeRecordUpdated {
                            borrower: borrower(), asset: asset_address, from: 0, to: 0, amount: 0
                        }
                    )
                )
            ]
        );
    assert(spy.events.is_empty(), 'There should be no events');
    assert(
        IERC20Dispatcher { contract_address: debt_token_address }
            .balance_of(treasury_address()) == min_fee,
        'Invalid treasury balance'
    );
    assert(
        IERC20Dispatcher { contract_address: debt_token_address }
            .balance_of(fee_collector.contract_address)
            .is_zero(),
        'Invalid fee collector balance'
    );
}

#[test]
fn when_caller_is_valid_and_current_timestamp_greater_than_record_from_it_should_take_the_right_amount() {
    let (fee_collector, debt_token_address, asset_address, min_fee, max_fee) = test_setup();
    let mut spy = spy_events(SpyOn::One(fee_collector.contract_address));
    let record = fee_collector.get_fee_record(borrower(), asset_address);

    // 50% of the time has passed
    let now = ((record.to - get_block_timestamp()) / 2);
    start_warp(CheatTarget::One(fee_collector.contract_address), now);

    start_prank(CheatTarget::One(fee_collector.contract_address), vessel_manager_address());

    fee_collector.close_debt(borrower(), asset_address);

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
                )
            ]
        );
    assert(spy.events.len() == 1, 'There should be one event');
    assert_is_approximately_equal(
        IERC20Dispatcher { contract_address: debt_token_address }.balance_of(treasury_address()),
        max_fee / 2,
        ERROR_MARGIN,
        'Invalid treasury balance'
    );

    assert(
        IERC20Dispatcher { contract_address: debt_token_address }
            .balance_of(fee_collector.contract_address)
            .is_zero(),
        'Invalid fee collector balance'
    );
}
