use starknet::ContractAddress;
use snforge_std::{
    PrintTrait, start_prank, stop_prank, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions
};
use shisui::pools::default_pool::{IDefaultPoolDispatcher, IDefaultPoolDispatcherTrait, DefaultPool};
use shisui::mocks::{
    receive_erc20_mock::{IIsCalledDispatcher, IIsCalledDispatcherTrait},
    erc20_mock::{IERC20MintBurnDispatcher, IERC20MintBurnDispatcherTrait, ERC20Mock},
};
use shisui::core::address_provider::{
    IAddressProviderDispatcher, IAddressProviderDispatcherTrait, AddressesKey
};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use tests::utils::callers::vessel_manager_address;
use shisui::utils::constants::ONE;

use super::super::setup::setup;

const INITIAL_TOKEN_AMOUNT: u256 = 5_000000; // 5e6
const INITIAL_AMOUNT_IN_10E18: u256 = 5_000000000000000000; // 1e18

fn test_setup() -> (IDefaultPoolDispatcher, IERC20Dispatcher, IIsCalledDispatcher) {
    let (address_provider, default_pool, asset, active_pool) = setup();

    // Mint some tokens for the default pool
    IERC20MintBurnDispatcher { contract_address: asset.contract_address }
        .mint(default_pool.contract_address, INITIAL_TOKEN_AMOUNT);

    // Notify the contract that it has received some tokens
    start_prank(CheatTarget::One(default_pool.contract_address), active_pool.contract_address);
    default_pool.received_erc20(asset.contract_address, INITIAL_AMOUNT_IN_10E18);
    stop_prank(CheatTarget::One(default_pool.contract_address));
    assert(
        asset.balance_of(default_pool.contract_address) == INITIAL_TOKEN_AMOUNT,
        'Wrong contract balance'
    );

    // Need to prank asset otherwise tx.origin is used
    start_prank(CheatTarget::One(asset.contract_address), default_pool.contract_address);

    (default_pool, asset, active_pool)
}

#[test]
#[should_panic(expected: ('Caller not authorized',))]
fn when_caller_is_not_the_active_pool_it_should_revert() {
    let (default_pool, asset, _) = test_setup();
    default_pool.send_asset_to_active_pool(asset.contract_address, ONE);
}

#[test]
fn when_caller_is_valid_it_should_send_asset_amount() {
    let (default_pool, asset, active_pool) = test_setup();

    let token_amount_send = 1_000000; // 1e6

    start_prank(CheatTarget::One(default_pool.contract_address), vessel_manager_address());
    let mut expected_asset_balance = INITIAL_AMOUNT_IN_10E18 - ONE;
    let mut expected_contract_balance = INITIAL_TOKEN_AMOUNT - token_amount_send;
    let mut expected_active_pool_balance = token_amount_send;
    let mut spy = spy_events(SpyOn::One(default_pool.contract_address));

    default_pool.send_asset_to_active_pool(asset.contract_address, ONE);
    spy
        .assert_emitted(
            @array![
                (
                    default_pool.contract_address,
                    DefaultPool::Event::DefaultPoolAssetBalanceUpdated(
                        DefaultPool::DefaultPoolAssetBalanceUpdated {
                            asset: asset.contract_address,
                            old_balance: INITIAL_AMOUNT_IN_10E18,
                            new_balance: expected_asset_balance
                        }
                    )
                ),
                (
                    default_pool.contract_address,
                    DefaultPool::Event::AssetSent(
                        DefaultPool::AssetSent {
                            account: active_pool.contract_address,
                            asset: asset.contract_address,
                            amount: token_amount_send
                        }
                    )
                )
            ]
        );
    assert(spy.events.is_empty(), 'There should be no events');
    assert(
        default_pool.get_asset_balance(asset.contract_address) == expected_asset_balance,
        'Wrong asset balance'
    );
    assert(
        asset.balance_of(active_pool.contract_address) == expected_active_pool_balance,
        'Wrong active pool balance'
    );
    assert(
        asset.balance_of(default_pool.contract_address) == expected_contract_balance,
        'Wrong contract balance '
    );
}


#[test]
fn when_amount_scale_to_zero_it_should_do_nothing() {
    let (default_pool, asset, active_pool) = test_setup();

    start_prank(CheatTarget::One(default_pool.contract_address), vessel_manager_address());
    default_pool.send_asset_to_active_pool(asset.contract_address, 0);

    assert(
        default_pool.get_asset_balance(asset.contract_address) == INITIAL_AMOUNT_IN_10E18,
        'Wrong asset balance'
    );
    assert(asset.balance_of(active_pool.contract_address) == 0, 'Wrong alice balance');
    assert(
        asset.balance_of(default_pool.contract_address) == INITIAL_TOKEN_AMOUNT,
        'Wrong contract balance'
    );
}

#[test]
fn when_account_is_erc20_deposit_it_should_call_it() {
    let (default_pool, asset, active_pool) = test_setup();
    assert(!active_pool.is_called(), 'Must be FALSE');

    start_prank(CheatTarget::One(default_pool.contract_address), vessel_manager_address());

    default_pool.send_asset_to_active_pool(asset.contract_address, ONE);

    assert(active_pool.is_called(), 'Must be TRUE');
}
