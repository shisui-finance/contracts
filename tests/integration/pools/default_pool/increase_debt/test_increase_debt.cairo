use starknet::ContractAddress;
use snforge_std::{
    start_prank, stop_prank, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions
};
use shisui::core::address_provider::{IAddressProviderDispatcher, IAddressProviderDispatcherTrait};
use shisui::pools::default_pool::{IDefaultPoolDispatcher, IDefaultPoolDispatcherTrait, DefaultPool};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use tests::utils::callers::vessel_manager_address;
use super::super::setup::setup;

const AMOUNT: u256 = 5_000000;

#[test]
#[should_panic(expected: ('Caller not authorized',))]
fn when_caller_is_not_vessel_manager_it_should_revert() {
    let (_, default_pool, asset, active_pool) = setup();
    default_pool.increase_debt(asset.contract_address, AMOUNT);
}

#[test]
fn when_caller_is_valid_it_should_update_debt_token_balance() {
    let (_, default_pool, asset, active_pool) = setup();
    // Check vessel_manager allowed to increase debt
    start_prank(CheatTarget::One(default_pool.contract_address), vessel_manager_address());
    let mut spy = spy_events(SpyOn::One(default_pool.contract_address));
    default_pool.increase_debt(asset.contract_address, AMOUNT);
    spy
        .assert_emitted(
            @array![
                (
                    default_pool.contract_address,
                    DefaultPool::Event::DefaultPoolDebtUpdated(
                        DefaultPool::DefaultPoolDebtUpdated {
                            asset: asset.contract_address, old_balance: 0, new_balance: AMOUNT
                        }
                    )
                )
            ]
        );
    assert(spy.events.is_empty(), 'There should be no events');
    assert(
        default_pool.get_debt_token_balance(asset.contract_address) == AMOUNT, 'Wrong inscrease'
    );
}
