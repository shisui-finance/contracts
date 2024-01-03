use starknet::ContractAddress;
use snforge_std::{
    PrintTrait, start_prank, stop_prank, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions
};
use shisui::pools::active_pool::{IActivePoolDispatcher, IActivePoolDispatcherTrait, ActivePool};
use shisui::mocks::{
    receive_erc20_mock::{IIsCalledDispatcher, IIsCalledDispatcherTrait},
    erc20_mock::{IERC20MintBurnDispatcher, IERC20MintBurnDispatcherTrait, ERC20Mock},
};
use shisui::core::address_provider::{
    IAddressProviderDispatcher, IAddressProviderDispatcherTrait, AddressesKey
};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use tests::utils::callers::{
    borrower_operations_address, vessel_manager_address, vessel_manager_operations_address,
    stability_pool_address, alice
};
use tests::tests_lib::deploy_receive_erc20_mock;
use shisui::utils::constants::ONE;

use super::super::setup::setup;

const INITIAL_TOKEN_AMOUNT: u256 = 5_000000; // 5e6
const INITIAL_AMOUNT_IN_10E18: u256 = 5_000000000000000000; // 1e18

fn test_setup() -> (IActivePoolDispatcher, IERC20Dispatcher, IIsCalledDispatcher) {
    let (address_provider, active_pool, asset) = setup();
    let receiver_mock_address: ContractAddress = deploy_receive_erc20_mock();
    let receiver_mock: IIsCalledDispatcher = IIsCalledDispatcher {
        contract_address: receiver_mock_address
    };
    address_provider.set_address(AddressesKey::coll_surplus_pool, receiver_mock_address);
    // Mint some tokens for the active pool
    IERC20MintBurnDispatcher { contract_address: asset.contract_address }
        .mint(active_pool.contract_address, INITIAL_TOKEN_AMOUNT);

    // Notify the contract that it has received some tokens
    start_prank(CheatTarget::One(active_pool.contract_address), borrower_operations_address());
    active_pool.received_erc20(asset.contract_address, INITIAL_AMOUNT_IN_10E18);
    stop_prank(CheatTarget::One(active_pool.contract_address));
    assert(
        asset.balance_of(active_pool.contract_address) == INITIAL_TOKEN_AMOUNT,
        'Wrong contract balance'
    );

    // Need to prank asset otherwise tx.origin is used
    start_prank(CheatTarget::One(asset.contract_address), active_pool.contract_address);

    (active_pool, asset, receiver_mock)
}

#[test]
#[should_panic(expected: ('Caller not authorized',))]
fn when_caller_is_neither_borrower_operations_nor_stability_pool_nor_vessel_manager_nor_vessel_manager_operations_it_should_revert() {
    let (active_pool, asset, _) = test_setup();
    active_pool.send_asset(asset.contract_address, alice(), ONE);
}

#[test]
fn when_caller_is_valid_it_should_send_asset_to_alice() {
    let (active_pool, asset, _) = test_setup();

    let token_amount_send = 1_000000; // 1e6

    // Check borrower_operations allowed to send asset
    start_prank(CheatTarget::One(active_pool.contract_address), borrower_operations_address());
    let mut expected_asset_balance = INITIAL_AMOUNT_IN_10E18 - ONE;
    let mut expected_contract_balance = INITIAL_TOKEN_AMOUNT - token_amount_send;
    let mut expected_alice_balance = token_amount_send;
    let mut spy = spy_events(SpyOn::One(active_pool.contract_address));

    active_pool.send_asset(asset.contract_address, alice(), ONE);
    spy
        .assert_emitted(
            @array![
                (
                    active_pool.contract_address,
                    ActivePool::Event::ActivePoolAssetBalanceUpdated(
                        ActivePool::ActivePoolAssetBalanceUpdated {
                            asset: asset.contract_address,
                            old_balance: INITIAL_AMOUNT_IN_10E18,
                            new_balance: expected_asset_balance
                        }
                    )
                ),
                (
                    active_pool.contract_address,
                    ActivePool::Event::AssetSent(
                        ActivePool::AssetSent {
                            account: alice(),
                            asset: asset.contract_address,
                            amount: token_amount_send
                        }
                    )
                )
            ]
        );
    assert(spy.events.is_empty(), 'There should be no events');
    assert(
        active_pool.get_asset_balance(asset.contract_address) == expected_asset_balance,
        'Wrong asset balance 1'
    );
    assert(asset.balance_of(alice()) == expected_alice_balance, 'Wrong alice balance 1');
    assert(
        asset.balance_of(active_pool.contract_address) == expected_contract_balance,
        'Wrong contract balance 1'
    );
    stop_prank(CheatTarget::One(active_pool.contract_address));

    // Check stability_pool allowed to send asset
    start_prank(CheatTarget::One(active_pool.contract_address), stability_pool_address());
    expected_asset_balance = expected_asset_balance - ONE;
    expected_contract_balance = expected_contract_balance - token_amount_send;
    expected_alice_balance = expected_alice_balance + token_amount_send;
    active_pool.send_asset(asset.contract_address, alice(), ONE);
    assert(
        active_pool.get_asset_balance(asset.contract_address) == expected_asset_balance,
        'Wrong asset balance 2'
    );
    assert(asset.balance_of(alice()) == expected_alice_balance, 'Wrong alice balance 2');
    assert(
        asset.balance_of(active_pool.contract_address) == expected_contract_balance,
        'Wrong contract balance 2'
    );
    stop_prank(CheatTarget::One(active_pool.contract_address));

    // Check vessel_manager allowed to send asset
    start_prank(CheatTarget::One(active_pool.contract_address), vessel_manager_address());
    expected_asset_balance = expected_asset_balance - ONE;
    expected_contract_balance = expected_contract_balance - token_amount_send;
    expected_alice_balance = expected_alice_balance + token_amount_send;
    active_pool.send_asset(asset.contract_address, alice(), ONE);
    assert(
        active_pool.get_asset_balance(asset.contract_address) == expected_asset_balance,
        'Wrong asset balance 3'
    );
    assert(asset.balance_of(alice()) == expected_alice_balance, 'Wrong alice balance 3');
    assert(
        asset.balance_of(active_pool.contract_address) == expected_contract_balance,
        'Wrong contract balance 3'
    );
    stop_prank(CheatTarget::One(active_pool.contract_address));

    // Check vessel_manager operations allowed to send asset
    start_prank(
        CheatTarget::One(active_pool.contract_address), vessel_manager_operations_address()
    );
    expected_asset_balance = expected_asset_balance - ONE;
    expected_contract_balance = expected_contract_balance - token_amount_send;
    expected_alice_balance = expected_alice_balance + token_amount_send;
    active_pool.send_asset(asset.contract_address, alice(), ONE);
    assert(
        active_pool.get_asset_balance(asset.contract_address) == expected_asset_balance,
        'Wrong asset balance 4'
    );
    assert(asset.balance_of(alice()) == expected_alice_balance, 'Wrong alice balance 4');
    assert(
        asset.balance_of(active_pool.contract_address) == expected_contract_balance,
        'Wrong contract balance 4'
    );
}


#[test]
fn when_amount_scale_to_zero_it_should_do_nothing() {
    let (active_pool, asset, _) = test_setup();

    start_prank(CheatTarget::One(active_pool.contract_address), borrower_operations_address());
    active_pool.send_asset(asset.contract_address, alice(), 0);

    assert(
        active_pool.get_asset_balance(asset.contract_address) == INITIAL_AMOUNT_IN_10E18,
        'Wrong asset balance'
    );
    assert(asset.balance_of(alice()) == 0, 'Wrong alice balance');
    assert(
        asset.balance_of(active_pool.contract_address) == INITIAL_TOKEN_AMOUNT,
        'Wrong contract balance'
    );
}

#[test]
fn when_account_is_erc20_deposit_it_should_call_it() {
    let (active_pool, asset, receiver_mock) = test_setup();
    assert(!receiver_mock.is_called(), 'Must be FALSE');

    start_prank(CheatTarget::One(active_pool.contract_address), borrower_operations_address());

    active_pool.send_asset(asset.contract_address, receiver_mock.contract_address, ONE);

    assert(receiver_mock.is_called(), 'Must be TRUE');
}
