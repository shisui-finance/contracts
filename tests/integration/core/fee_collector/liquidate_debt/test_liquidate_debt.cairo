use starknet::{ContractAddress, contract_address_const};
use snforge_std::{
    start_prank, stop_prank, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions, PrintTrait
};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

use shisui::core::{
    debt_token::{IDebtTokenDispatcher, IDebtTokenDispatcherTrait},
    fee_collector::{IFeeCollectorDispatcher, IFeeCollectorDispatcherTrait, FeeCollector}
};
use tests::utils::callers::{
    vessel_manager_address, borrower_operations_address, borrower, treasury_address
};


use super::super::setup::{setup, calc_fees};

const DEBT_AMOUNT: u256 = 100_000000000000000000; // 10e18

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
fn when_caller_is_not_vessel_manager_it_should_revert() {
    let (fee_collector, _, asset_address, _, _) = test_setup();
    fee_collector.liquidate_debt(borrower(), asset_address);
}

#[test]
fn when_caller_is_valid_and_amount_is_zero_it_should_do_nothing() {
    let (fee_collector, debt_token_address, _, _, _) = test_setup();
    let no_amount_asset = contract_address_const::<'asset_2'>();
    let fee_collector_balance = IERC20Dispatcher { contract_address: debt_token_address }
        .balance_of(fee_collector.contract_address);

    start_prank(CheatTarget::One(fee_collector.contract_address), vessel_manager_address());
    fee_collector.liquidate_debt(borrower(), no_amount_asset);

    assert(
        IERC20Dispatcher { contract_address: debt_token_address }
            .balance_of(fee_collector.contract_address) == fee_collector_balance,
        'Wrong fee collector balance'
    );
}


#[test]
fn when_caller_is_valid_and_amount_is_not_zero_it_should_correctly_collect_fee() {
    let (fee_collector, debt_token_address, asset_address, min_fee, max_fee) = test_setup();
    let mut spy = spy_events(SpyOn::One(fee_collector.contract_address));

    start_prank(CheatTarget::One(fee_collector.contract_address), vessel_manager_address());
    fee_collector.liquidate_debt(borrower(), asset_address);
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
    let record = fee_collector.get_fee_record(borrower(), asset_address);
    assert(record.amount.is_zero(), 'Invalid record amount');

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
