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
    callers::{alice, borrower_operations_address, borrower, treasury_address},
    constant::{MIN_FEE_DURATION, FEE_EXPIRATION_SECONDS}, asserts::assert_is_approximately_equal
};

use super::super::setup::{setup, calc_fees, calc_new_duration, calc_expired_amount};

const DEBT_AMOUNT: u256 = 100_000000000000000000; // 100e18


fn test_setup() -> (IFeeCollectorDispatcher, ContractAddress, ContractAddress, u256, u256) {
    let (_, fee_collector, debt_token_address, asset_address) = setup();
    let (min_fee, max_fee) = calc_fees(DEBT_AMOUNT);
    // Mint some debt tokens to the fee collector
    start_prank(CheatTarget::One(debt_token_address), borrower_operations_address());

    IDebtTokenDispatcher { contract_address: debt_token_address }
        .mint(fee_collector.contract_address, max_fee * 2);
    stop_prank(CheatTarget::One(debt_token_address));

    start_prank(CheatTarget::One(fee_collector.contract_address), borrower_operations_address());
    fee_collector.increase_debt(borrower(), asset_address, max_fee);
    stop_prank(CheatTarget::One(fee_collector.contract_address));

    (fee_collector, debt_token_address, asset_address, min_fee, max_fee)
}


#[test]
#[should_panic(expected: ('Array Mismatch',))]
fn when_borrower_array_is_empty_it_sould_revert() {
    let (fee_collector, _, asset_address, _, _) = test_setup();
    fee_collector.collect_fees(array![].span(), array![].span());
}

#[test]
#[should_panic(expected: ('Array Mismatch',))]
fn when_borrower_array_length_not_equal_to_assets_array_length_it_should_revert() {
    let (fee_collector, _, asset_address, _, _) = test_setup();
    fee_collector.collect_fees(array![borrower(), borrower()].span(), array![asset_address].span());
}

#[test]
fn when_input_valid_and_partially_collected_and_then_after_they_expired_it_should_correctly_collect_fees() {
    let (fee_collector, debt_token_address, asset_address, min_fee, max_fee) = test_setup();
    let fees_left = max_fee - min_fee;
    start_prank(CheatTarget::One(fee_collector.contract_address), borrower_operations_address());
    let borrower_record = fee_collector.get_fee_record(borrower(), asset_address);

    // 25% of the time has passed and add alice as new borrower
    let mut now = ((borrower_record.to - get_block_timestamp()) / 4);
    start_warp(CheatTarget::One(fee_collector.contract_address), now);
    start_prank(CheatTarget::One(fee_collector.contract_address), borrower_operations_address());
    fee_collector.increase_debt(alice(), asset_address, max_fee);
    stop_prank(CheatTarget::One(fee_collector.contract_address));

    let alice_record = fee_collector.get_fee_record(alice(), asset_address);

    // move to 50% of the time has passed for borrower
    now = ((borrower_record.to - get_block_timestamp()) / 2);
    start_warp(CheatTarget::One(fee_collector.contract_address), now);

    let expected_borrower_amount = fee_collector.simulate_refund(borrower(), asset_address, ONE);
    let expected_borrower_fee_collected = fees_left - expected_borrower_amount;
    let expected_alice_amount = fee_collector.simulate_refund(alice(), asset_address, ONE);
    let expected_alice_fee_collected = fees_left - expected_alice_amount;
    let total_fee_expected = expected_borrower_fee_collected
        + expected_alice_fee_collected
        + min_fee * 2;
    let expected_fee_collector_balance = max_fee * 2 - total_fee_expected;

    let mut spy = spy_events(SpyOn::One(fee_collector.contract_address));

    fee_collector
        .collect_fees(
            array![borrower(), alice()].span(), array![asset_address, asset_address].span()
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
                            to: borrower_record.to,
                            amount: expected_borrower_amount
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
                            amount: expected_borrower_fee_collected
                        }
                    )
                ),
                (
                    fee_collector.contract_address,
                    FeeCollector::Event::FeeRecordUpdated(
                        FeeCollector::FeeRecordUpdated {
                            borrower: alice(),
                            asset: asset_address,
                            from: now,
                            to: alice_record.to,
                            amount: expected_alice_amount
                        }
                    )
                ),
                (
                    fee_collector.contract_address,
                    FeeCollector::Event::FeeCollected(
                        FeeCollector::FeeCollected {
                            borrower: alice(),
                            asset: asset_address,
                            collector: treasury_address(),
                            amount: expected_alice_fee_collected
                        }
                    )
                )
            ]
        );
    assert(spy.events.is_empty(), 'There should be no event');

    assert(
        IERC20Dispatcher { contract_address: debt_token_address }
            .balance_of(fee_collector.contract_address) == expected_fee_collector_balance,
        'Invalid fee collector balance'
    );

    assert(
        IERC20Dispatcher { contract_address: debt_token_address }
            .balance_of(treasury_address()) == total_fee_expected,
        'Invalid treasury balance'
    );

    // move after expiration
    now = alice_record.to + 1;
    start_warp(CheatTarget::One(fee_collector.contract_address), now);

    fee_collector
        .collect_fees(
            array![borrower(), alice()].span(), array![asset_address, asset_address].span()
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
                            to: borrower_record.to,
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
                            amount: expected_borrower_amount
                        }
                    )
                ),
                (
                    fee_collector.contract_address,
                    FeeCollector::Event::FeeRecordUpdated(
                        FeeCollector::FeeRecordUpdated {
                            borrower: alice(),
                            asset: asset_address,
                            from: now,
                            to: alice_record.to,
                            amount: 0
                        }
                    )
                ),
                (
                    fee_collector.contract_address,
                    FeeCollector::Event::FeeCollected(
                        FeeCollector::FeeCollected {
                            borrower: alice(),
                            asset: asset_address,
                            collector: treasury_address(),
                            amount: expected_alice_amount
                        }
                    )
                )
            ]
        );
    assert(spy.events.is_empty(), 'There should be no event');

    assert(
        IERC20Dispatcher { contract_address: debt_token_address }
            .balance_of(fee_collector.contract_address)
            .is_zero(),
        'Invalid fee collector balance'
    );

    assert(
        IERC20Dispatcher { contract_address: debt_token_address }
            .balance_of(treasury_address()) == max_fee
            * 2,
        'Invalid treasury balance'
    );
}

#[test]
fn when_input_valid_and_no_fees_to_collect_it_should_do_nothing() {
    let (fee_collector, debt_token_address, asset_address, min_fee, max_fee) = test_setup();

    let fee_collector_balance = IERC20Dispatcher { contract_address: debt_token_address }
        .balance_of(fee_collector.contract_address);
    let treasury_balance = IERC20Dispatcher { contract_address: debt_token_address }
        .balance_of(treasury_address());

    fee_collector.collect_fees(array![borrower()].span(), array![asset_address].span());

    assert(
        IERC20Dispatcher { contract_address: debt_token_address }
            .balance_of(fee_collector.contract_address) == fee_collector_balance,
        'Invalid fee collector balance'
    );

    assert(
        IERC20Dispatcher { contract_address: debt_token_address }
            .balance_of(treasury_address()) == treasury_balance,
        'Invalid treasury balance'
    );
}
