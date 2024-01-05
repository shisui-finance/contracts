use starknet::{ContractAddress, contract_address_const};
use snforge_std::{
    start_prank, stop_prank, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions
};
use shisui::core::address_provider::{IAddressProviderDispatcher, IAddressProviderDispatcherTrait};
use shisui::pools::collateral_surplus_pool::{
    ICollateralSurplusPoolDispatcher, ICollateralSurplusPoolDispatcherTrait, CollateralSurplusPool
};
use openzeppelin::token::erc20::{
    interface::{IERC20Dispatcher, IERC20DispatcherTrait}, erc20::ERC20Component
};

use shisui::mocks::erc20_mock::{IERC20MintBurnDispatcher, IERC20MintBurnDispatcherTrait, ERC20Mock};
use tests::utils::callers::{
    active_pool_address, borrower_operation_address, vessel_manager_address, alice
};

use super::super::setup::setup;


const ONE_10E18: u256 = 1_000000000000000000;
const ONE_10E6: u256 = 1_000000;
const INITIAL_BALANCE: u256 = 100_000000;
const TRANSFER_AMOUNT: u256 = 5;

fn test_setup() -> (
    IAddressProviderDispatcher, ICollateralSurplusPoolDispatcher, IERC20Dispatcher
) {
    let (address_provider, collateral_surplus_pool, asset) = setup();

    IERC20MintBurnDispatcher { contract_address: asset.contract_address }
        .mint(alice(), INITIAL_BALANCE);

    start_prank(CheatTarget::One(asset.contract_address), alice());
    asset.transfer(collateral_surplus_pool.contract_address, TRANSFER_AMOUNT * ONE_10E6);
    stop_prank(CheatTarget::One(asset.contract_address));

    start_prank(
        CheatTarget::One(collateral_surplus_pool.contract_address), vessel_manager_address()
    );
    collateral_surplus_pool
        .account_surplus(asset.contract_address, alice(), TRANSFER_AMOUNT * ONE_10E18);

    start_prank(CheatTarget::One(collateral_surplus_pool.contract_address), active_pool_address());
    collateral_surplus_pool.received_erc20(asset.contract_address, TRANSFER_AMOUNT * ONE_10E6);

    return (address_provider, collateral_surplus_pool, asset);
}

#[test]
#[should_panic(expected: ('Caller not Borrower Operation',))]
fn when_caller_is_not_borrower_operation_it_should_revert() {
    let (_, collateral_surplus_pool, asset) = test_setup();
    collateral_surplus_pool.claim_coll(asset.contract_address, alice());
}

#[test]
#[should_panic(expected: ('No collateral to claim',))]
fn when_caller_is_borrower_operation__and_claim_amount_is_zero_it_should_revert() {
    let (_, collateral_surplus_pool, asset) = test_setup();
    start_prank(
        CheatTarget::One(collateral_surplus_pool.contract_address), borrower_operation_address()
    );

    collateral_surplus_pool
        .claim_coll(asset.contract_address, contract_address_const::<'not-user'>());
}

#[test]
fn when_caller_is_borrower_operation_it_should_correctly_claim() {
    let (_, collateral_surplus_pool, asset) = test_setup();
    let mut spy = spy_events(SpyOn::One(collateral_surplus_pool.contract_address));

    start_prank(
        CheatTarget::One(collateral_surplus_pool.contract_address), borrower_operation_address()
    );

    collateral_surplus_pool.claim_coll(asset.contract_address, alice());

    // event check
    spy
        .assert_emitted(
            @array![
                (
                    collateral_surplus_pool.contract_address,
                    CollateralSurplusPool::Event::CollBalanceUpdated(
                        CollateralSurplusPool::CollBalanceUpdated {
                            account: alice(),
                            asset: asset.contract_address,
                            old_balance: TRANSFER_AMOUNT * ONE_10E18,
                            new_balance: 0
                        }
                    )
                ),
                (
                    collateral_surplus_pool.contract_address,
                    CollateralSurplusPool::Event::AssetSent(
                        CollateralSurplusPool::AssetSent {
                            account: alice(),
                            asset: asset.contract_address,
                            amount: TRANSFER_AMOUNT * ONE_10E6,
                        }
                    )
                )
            ]
        );
    assert(spy.events.is_empty(), 'There should be no events');

    assert(
        collateral_surplus_pool.get_collateral(asset.contract_address, alice()).is_zero(),
        'Wrong alice coll'
    );
    assert(
        collateral_surplus_pool.get_asset_balance(asset.contract_address).is_zero(),
        'Wrong asset balance'
    );

    assert(
        asset.balance_of(collateral_surplus_pool.contract_address).is_zero(),
        'Wrong contract balance'
    );

    assert(asset.balance_of(alice()) == INITIAL_BALANCE, 'Wrong alice balance');
}

