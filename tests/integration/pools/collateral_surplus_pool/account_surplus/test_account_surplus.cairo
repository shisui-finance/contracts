use starknet::{ContractAddress, contract_address_const};
use snforge_std::{
    start_prank, start_warp, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions, PrintTrait
};
use shisui::core::address_provider::{IAddressProviderDispatcher, IAddressProviderDispatcherTrait};
use shisui::pools::collateral_surplus_pool::{
    ICollateralSurplusPoolDispatcher, ICollateralSurplusPoolDispatcherTrait, CollateralSurplusPool
};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

use shisui::utils::math::pow;
use shisui::mocks::pragma_oracle_mock::{
    IPragmaOracleMockDispatcher, IPragmaOracleMockDispatcherTrait
};

use tests::utils::callers::{
    active_pool_address, borrower_operation_address, vessel_manager_address, alice
};

use super::super::setup::setup;

fn test_setup() -> (
    IAddressProviderDispatcher, ICollateralSurplusPoolDispatcher, IERC20Dispatcher
) {
    let (address_provider, collateral_surplus_pool, asset) = setup();

    return (address_provider, collateral_surplus_pool, asset);
}

const ONE_USDC: u256 = 1000000;

#[test]
#[should_panic(expected: ('Caller not Vessel Manager',))]
fn when_caller_neither_vesselManager_nor_vesselManagerOperations_it_should_revert() {
    let (_, collateral_surplus_pool, asset) = test_setup();
    collateral_surplus_pool.account_surplus(asset.contract_address, alice(), ONE_USDC);
}


#[test]
fn when_caller_is_vesselManager_or_vesselManagerOperations_it_should_correctly_update() {
    let (_, collateral_surplus_pool, asset) = test_setup();
    start_prank(
        CheatTarget::One(collateral_surplus_pool.contract_address), vessel_manager_address()
    );
    let mut spy = spy_events(SpyOn::One(collateral_surplus_pool.contract_address));

    collateral_surplus_pool.account_surplus(asset.contract_address, alice(), ONE_USDC);

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
                            old_balance: 0,
                            new_balance: ONE_USDC
                        }
                    )
                )
            ]
        );
    assert(spy.events.len() == 0, 'There should be no events');
    assert(
        collateral_surplus_pool.get_collateral(asset.contract_address, alice()) == ONE_USDC,
        'Wrong update'
    );
}

