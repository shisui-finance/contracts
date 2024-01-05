use starknet::ContractAddress;
use snforge_std::{
    start_prank, stop_prank, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions
};
use shisui::core::address_provider::{IAddressProviderDispatcher, IAddressProviderDispatcherTrait};
use shisui::pools::default_pool::{IDefaultPoolDispatcher, IDefaultPoolDispatcherTrait, DefaultPool};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use tests::utils::callers::{stability_pool_address, vessel_manager_address};
use super::super::setup::setup;

const BASE_AMOUNT: u256 = 10_000000;

fn test_setup() -> (IDefaultPoolDispatcher, IERC20Dispatcher) {
    let (_, default_pool, asset, active_pool) = setup();

    start_prank(CheatTarget::One(default_pool.contract_address), vessel_manager_address());
    default_pool.increase_debt(asset.contract_address, BASE_AMOUNT);
    stop_prank(CheatTarget::One(default_pool.contract_address));

    (default_pool, asset)
}

#[test]
#[should_panic(expected: ('Caller is not authorized',))]
fn when_caller_is_not_vessel_manager_it_should_revert() {
    let (default_pool, asset) = test_setup();
    default_pool.decrease_debt(asset.contract_address, BASE_AMOUNT);
}

#[test]
fn when_caller_is_valid_it_should_correctly_update_debt_token_balance() {
    let (default_pool, asset) = test_setup();
    let decrease_amount: u256 = 2_000000;
    let expected_amount: u256 = 8_000000;

    // Check vessel_manager is allowed to decrease debt
    start_prank(CheatTarget::One(default_pool.contract_address), vessel_manager_address());
    let mut spy = spy_events(SpyOn::One(default_pool.contract_address));
    default_pool.decrease_debt(asset.contract_address, decrease_amount);
    spy
        .assert_emitted(
            @array![
                (
                    default_pool.contract_address,
                    DefaultPool::Event::DefaultPoolDebtUpdated(
                        DefaultPool::DefaultPoolDebtUpdated {
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
        default_pool.get_debt_token_balance(asset.contract_address) == expected_amount,
        'Wrong decrease'
    );
    stop_prank(CheatTarget::One(default_pool.contract_address));
}

#[test]
fn when_caller_is_valid_and_decreased_amount_equal_to_balance_it_should_set_debt_token_balance_at_zero() {
    let (default_pool, asset) = test_setup();

    start_prank(CheatTarget::One(default_pool.contract_address), vessel_manager_address());
    let mut spy = spy_events(SpyOn::One(default_pool.contract_address));
    default_pool.decrease_debt(asset.contract_address, BASE_AMOUNT);
    spy
        .assert_emitted(
            @array![
                (
                    default_pool.contract_address,
                    DefaultPool::Event::DefaultPoolDebtUpdated(
                        DefaultPool::DefaultPoolDebtUpdated {
                            asset: asset.contract_address, old_balance: BASE_AMOUNT, new_balance: 0
                        }
                    )
                )
            ]
        );
    assert(spy.events.is_empty(), 'There should be no events');

    assert(
        default_pool.get_debt_token_balance(asset.contract_address).is_zero(),
        'Debt balance should be zero'
    );
}

#[test]
#[should_panic(expected: ('u256_sub Overflow',))]
fn when_caller_is_valid_and_decreased_amount_greater_than_balance_it_should_revert() {
    let (default_pool, asset) = test_setup();
    start_prank(CheatTarget::One(default_pool.contract_address), vessel_manager_address());
    default_pool.decrease_debt(asset.contract_address, 10_000001);
}
