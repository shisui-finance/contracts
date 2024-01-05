use starknet::ContractAddress;
use snforge_std::{start_prank, CheatTarget};
use shisui::core::address_provider::{IAddressProviderDispatcher, IAddressProviderDispatcherTrait};
use shisui::pools::collateral_surplus_pool::{
    ICollateralSurplusPoolDispatcher, ICollateralSurplusPoolDispatcherTrait
};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use tests::utils::callers::active_pool_address;
use super::super::setup::setup;

const AMOUNT: u256 = 5;

#[test]
#[should_panic(expected: ('Caller not Active Pool',))]
fn when_caller_is_not_active_pool_it_should_revert() {
    let (_, collateral_surplus_pool, asset) = setup();
    collateral_surplus_pool.received_erc20(asset.contract_address, AMOUNT);
}

#[test]
fn when_caller_is_active_pool_it_should_correctly_update_asset_balance() {
    let (_, collateral_surplus_pool, asset) = setup();
    start_prank(CheatTarget::One(collateral_surplus_pool.contract_address), active_pool_address());
    collateral_surplus_pool.received_erc20(asset.contract_address, AMOUNT);
    assert(
        collateral_surplus_pool.get_asset_balance(asset.contract_address) == AMOUNT,
        'Wrong asset balance'
    );
}
