use starknet::ContractAddress;
use snforge_std::{
    start_prank, stop_prank, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions
};
use shisui::core::address_provider::{IAddressProviderDispatcher, IAddressProviderDispatcherTrait};
use shisui::pools::active_pool::{IActivePoolDispatcher, IActivePoolDispatcherTrait, ActivePool};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use tests::utils::callers::{
    borrower_operations_address, stability_pool_address, vessel_manager_address
};
use super::super::setup::setup;

const BASE_AMOUNT: u256 = 10_000000;

fn test_setup() -> (IActivePoolDispatcher, IERC20Dispatcher) {
    let (_, active_pool, asset) = setup();

    start_prank(CheatTarget::One(active_pool.contract_address), borrower_operations_address());
    active_pool.increase_debt(asset.contract_address, BASE_AMOUNT);
    stop_prank(CheatTarget::One(active_pool.contract_address));

    (active_pool, asset)
}

#[test]
#[should_panic(expected: ('Caller is not authorized',))]
fn when_caller_is_neither_borrower_operations_nor_vessel_manager_it_should_revert() {
    let (active_pool, asset) = test_setup();
    active_pool.decrease_debt(asset.contract_address, BASE_AMOUNT);
}

#[test]
fn when_caller_is_valid_it_should_correctly_update_debt_token_balance() {
    let (active_pool, asset) = test_setup();
    let decrease_amount: u256 = 2_000000;
    let expected_amount: u256 = 8_000000;

    // Check borrower_operations is allowed to decrease debt
    start_prank(CheatTarget::One(active_pool.contract_address), borrower_operations_address());
    let mut spy = spy_events(SpyOn::One(active_pool.contract_address));
    active_pool.decrease_debt(asset.contract_address, decrease_amount);
    spy
        .assert_emitted(
            @array![
                (
                    active_pool.contract_address,
                    ActivePool::Event::ActivePoolDebtUpdated(
                        ActivePool::ActivePoolDebtUpdated {
                            asset: asset.contract_address,
                            old_balance: BASE_AMOUNT,
                            new_balance: expected_amount
                        }
                    )
                )
            ]
        );
    assert(spy.events.is_empty(), 'There should be no events');
    assert(
        active_pool.get_debt_token_balance(asset.contract_address) == expected_amount,
        'Wrong borrower op decrease'
    );
    stop_prank(CheatTarget::One(active_pool.contract_address));

    // Check vessel_manager is allowed to decrease debt
    start_prank(CheatTarget::One(active_pool.contract_address), vessel_manager_address());
    active_pool.decrease_debt(asset.contract_address, decrease_amount);
    assert(
        active_pool.get_debt_token_balance(asset.contract_address) == expected_amount
            - decrease_amount,
        'Wrong vessel decrease'
    );
}

#[test]
fn when_caller_is_valid_and_decreased_amount_equal_to_balance_it_should_set_debt_token_balance_at_zero() {
    let (active_pool, asset) = test_setup();

    start_prank(CheatTarget::One(active_pool.contract_address), borrower_operations_address());
    let mut spy = spy_events(SpyOn::One(active_pool.contract_address));
    active_pool.decrease_debt(asset.contract_address, BASE_AMOUNT);
    spy
        .assert_emitted(
            @array![
                (
                    active_pool.contract_address,
                    ActivePool::Event::ActivePoolDebtUpdated(
                        ActivePool::ActivePoolDebtUpdated {
                            asset: asset.contract_address, old_balance: BASE_AMOUNT, new_balance: 0
                        }
                    )
                )
            ]
        );
    assert(spy.events.is_empty(), 'There should be no events');

    assert(
        active_pool.get_debt_token_balance(asset.contract_address).is_zero(),
        'Debt balance should be zero'
    );
}

#[test]
#[should_panic(expected: ('u256_sub Overflow',))]
fn when_caller_is_valid_and_decreased_amount_greater_than_balance_it_should_revert() {
    let (active_pool, asset) = test_setup();
    start_prank(CheatTarget::One(active_pool.contract_address), borrower_operations_address());
    active_pool.decrease_debt(asset.contract_address, 10_000001);
}
