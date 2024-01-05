use starknet::ContractAddress;
use snforge_std::{
    start_prank, stop_prank, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions
};
use shisui::core::address_provider::{IAddressProviderDispatcher, IAddressProviderDispatcherTrait};
use shisui::pools::active_pool::{IActivePoolDispatcher, IActivePoolDispatcherTrait, ActivePool};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use tests::utils::callers::{borrower_operations_address, vessel_manager_address};
use super::super::setup::setup;

const AMOUNT: u256 = 5_000000;

#[test]
#[should_panic(expected: ('Caller is not authorized',))]
fn when_caller_is_neither_borrower_operations_nor_vessel_manager_it_should_revert() {
    let (_, active_pool, asset) = setup();
    active_pool.increase_debt(asset.contract_address, AMOUNT);
}

#[test]
fn when_caller_is_valid_it_should_update_debt_token_balance() {
    let (_, active_pool, asset) = setup();
    // Check borrower_operations allowed to increase debt
    start_prank(CheatTarget::One(active_pool.contract_address), borrower_operations_address());
    let mut spy = spy_events(SpyOn::One(active_pool.contract_address));
    active_pool.increase_debt(asset.contract_address, AMOUNT);
    spy
        .assert_emitted(
            @array![
                (
                    active_pool.contract_address,
                    ActivePool::Event::ActivePoolDebtUpdated(
                        ActivePool::ActivePoolDebtUpdated {
                            asset: asset.contract_address, old_balance: 0, new_balance: AMOUNT
                        }
                    )
                )
            ]
        );
    assert(spy.events.is_empty(), 'There should be no events');
    assert(
        active_pool.get_debt_token_balance(asset.contract_address) == AMOUNT,
        'Wrong borrower inscrease'
    );
    stop_prank(CheatTarget::One(active_pool.contract_address));

    // Check vessel_manager allowed to increase debt
    start_prank(CheatTarget::One(active_pool.contract_address), vessel_manager_address());
    active_pool.increase_debt(asset.contract_address, AMOUNT);
    assert(
        active_pool.get_debt_token_balance(asset.contract_address) == AMOUNT * 2,
        'Wrong vessel manager increase'
    );
}
