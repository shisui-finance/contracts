use tests::tests_lib::{deploy_main_contracts};
use super::super::setup::open_vessel;
use shisui::core::{
    address_provider::{IAddressProviderDispatcher, IAddressProviderDispatcherTrait, AddressesKey},
    admin_contract::{IAdminContractDispatcher, IAdminContractDispatcherTrait},
    fee_collector::{IFeeCollectorDispatcher, IFeeCollectorDispatcherTrait},
    debt_token::{IDebtTokenDispatcher, IDebtTokenDispatcherTrait},
    price_feed::{IPriceFeedDispatcher, IPriceFeedDispatcherTrait},
};
use shisui::pools::{
    borrower_operations::{IBorrowerOperationsDispatcher, IBorrowerOperationsDispatcherTrait},
    vessel_manager::{IVesselManagerDispatcher, IVesselManagerDispatcherTrait, Status},
};
use snforge_std::{
    start_prank, stop_prank, load, store, map_entry_address, CheatTarget, spy_events, SpyOn,
    EventSpy, EventAssertions, start_mock_call, PrintTrait
};
use starknet::{ContractAddress, contract_address_const, get_caller_address};


#[test]
fn when_vessel_exists_return_expected_pending_asset_reward() {
    let (
        borrower_operations,
        vessel_manager,
        adress_provider,
        admin_contract,
        fee_collector,
        debt_token,
        price_feed,
        pragma_mock,
        active_pool,
        default_pool,
        asset
    ) =
        deploy_main_contracts();

    let mut asset_price: u256 = 1600_000000000000000000;
    let deposit_amount: u256 = 1_890000000000000000;
    let debt_token_amount: u256 = 2000_000000000000000000;

    let caller = open_vessel(
        asset,
        price_feed,
        admin_contract,
        active_pool,
        default_pool,
        debt_token,
        borrower_operations,
        vessel_manager,
        pragma_mock,
        asset_price,
        deposit_amount,
        debt_token_amount
    );

    store(
        vessel_manager.contract_address,
        map_entry_address(selector!("l_debts"), array![asset.contract_address.into()].span()),
        array![10].span()
    );

    let pending_reward = vessel_manager
        .get_pending_debt_token_reward(asset.contract_address, caller);
    assert(pending_reward == 18, 'Wrong debt pending reward'); //deposit_amount * 10 / precision
}

#[test]
fn when_vessel_is_not_active_should_return_0() {
    let (
        borrower_operations,
        vessel_manager,
        adress_provider,
        admin_contract,
        fee_collector,
        debt_token,
        price_feed,
        pragma_mock,
        active_pool,
        default_pool,
        asset
    ) =
        deploy_main_contracts();

    let mut asset_price: u256 = 1600_000000000000000000;
    let deposit_amount: u256 = 1_890000000000000000;
    let debt_token_amount: u256 = 2000_000000000000000000;

    let caller = open_vessel(
        asset,
        price_feed,
        admin_contract,
        active_pool,
        default_pool,
        debt_token,
        borrower_operations,
        vessel_manager,
        pragma_mock,
        asset_price,
        deposit_amount,
        debt_token_amount
    );

    store(
        vessel_manager.contract_address,
        map_entry_address(selector!("l_debts"), array![asset.contract_address.into()].span()),
        array![10].span()
    );

    start_prank(
        CheatTarget::One(vessel_manager.contract_address), borrower_operations.contract_address
    );
    vessel_manager.set_vessel_status(asset.contract_address, caller, Status::ClosedByLiquidation);
    stop_prank(CheatTarget::One(vessel_manager.contract_address));

    let pending_reward = vessel_manager
        .get_pending_debt_token_reward(asset.contract_address, caller);
    assert(pending_reward == 0, 'Wrong debt pending reward');
}

#[test]
fn when_having_no_reward_per_unit_staked_should_return_0() {
    let (
        borrower_operations,
        vessel_manager,
        adress_provider,
        admin_contract,
        fee_collector,
        debt_token,
        price_feed,
        pragma_mock,
        active_pool,
        default_pool,
        asset
    ) =
        deploy_main_contracts();

    let mut asset_price: u256 = 1600_000000000000000000;
    let deposit_amount: u256 = 1_890000000000000000;
    let debt_token_amount: u256 = 2000_000000000000000000;

    let caller = open_vessel(
        asset,
        price_feed,
        admin_contract,
        active_pool,
        default_pool,
        debt_token,
        borrower_operations,
        vessel_manager,
        pragma_mock,
        asset_price,
        deposit_amount,
        debt_token_amount
    );

    let pending_reward = vessel_manager
        .get_pending_debt_token_reward(asset.contract_address, caller);
    assert(pending_reward == 0, 'Wrong debt pending reward');
}
