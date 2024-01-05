use starknet::ContractAddress;
use snforge_std::{start_prank, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions};
use shisui::core::address_provider::{IAddressProviderDispatcher, IAddressProviderDispatcherTrait};
use shisui::pools::default_pool::{IDefaultPoolDispatcher, IDefaultPoolDispatcherTrait, DefaultPool};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use tests::utils::callers::active_pool_address;
use super::super::setup::setup;

const AMOUNT: u256 = 5_000000;

#[test]
#[should_panic(expected: ('Caller is not authorized',))]
fn when_caller_is_neither_borrower_operations_nor_default_pool_it_should_revert() {
    let (_, default_pool, asset, _) = setup();
    default_pool.received_erc20(asset.contract_address, AMOUNT);
}

#[test]
fn when_caller_is_valid_it_should_update_assets_balance() {
    let (_, default_pool, asset, active_pool) = setup();

    start_prank(CheatTarget::One(default_pool.contract_address), active_pool.contract_address);
    let mut spy = spy_events(SpyOn::One(default_pool.contract_address));
    default_pool.received_erc20(asset.contract_address, AMOUNT);
    spy
        .assert_emitted(
            @array![
                (
                    default_pool.contract_address,
                    DefaultPool::Event::DefaultPoolAssetBalanceUpdated(
                        DefaultPool::DefaultPoolAssetBalanceUpdated {
                            asset: asset.contract_address, old_balance: 0, new_balance: AMOUNT
                        }
                    )
                )
            ]
        );
    assert(spy.events.is_empty(), 'There should be no events');

    assert(default_pool.get_asset_balance(asset.contract_address) == AMOUNT, 'Wrong asset balance');
}
