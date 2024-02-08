use tests::tests_lib::{deploy_main_contracts};
use core::integer::BoundedU256;
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
    vessel_manager::{IVesselManagerDispatcher, IVesselManagerDispatcherTrait},
};
use snforge_std::{
    start_prank, stop_prank, store, map_entry_address, CheatTarget, spy_events, SpyOn, EventSpy,
    EventAssertions, start_mock_call, PrintTrait
};
use starknet::{ContractAddress, contract_address_const, get_caller_address};


#[test]
fn when_asset_exists_as_collateral_tcr_is_correctly_calculated() {
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
        asset,
        vessel_manager_operations_address
    ) =
        deploy_main_contracts();

    let mut asset_price: u256 = 1600_000000000000000000;
    let deposit_amount: u256 = 1_890000000000000000;
    let debt_token_amount: u256 = 2000_000000000000000000;

    let borrower = open_vessel(
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

    start_mock_call(active_pool.contract_address, 'get_asset_balance', deposit_amount);
    start_mock_call(default_pool.contract_address, 'get_asset_balance', 0_u256);
    start_mock_call(active_pool.contract_address, 'get_debt_token_balance', debt_token_amount);
    start_mock_call(default_pool.contract_address, 'get_debt_token_balance', 0_u256);

    let tcr = vessel_manager.get_tcr(asset.contract_address, asset_price);
    assert(tcr == 1_512000000000000000, 'Wrong tcr');
}

#[test]
fn when_asset_is_not_existing_as_collateral_it_should_return_max_value() {
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
        asset,
        vessel_manager_operations_address
    ) =
        deploy_main_contracts();

    let mut asset_price: u256 = 1600_000000000000000000;
    let deposit_amount: u256 = 1_890000000000000000;
    let debt_token_amount: u256 = 2000_000000000000000000;

    // let borrower = open_vessel(
    //     asset,
    //     price_feed,
    //     admin_contract,
    //     active_pool,
    //     default_pool,
    //     debt_token,
    //     borrower_operations,
    //     vessel_manager,
    //     pragma_mock,
    //     asset_price,
    //     deposit_amount,
    //     debt_token_amount
    // );

    start_mock_call(active_pool.contract_address, 'get_asset_balance', 0_u256);
    start_mock_call(default_pool.contract_address, 'get_asset_balance', 0_u256);
    start_mock_call(active_pool.contract_address, 'get_debt_token_balance', 0_u256);
    start_mock_call(default_pool.contract_address, 'get_debt_token_balance', 0_u256);

    let tcr = vessel_manager.get_tcr(asset.contract_address, asset_price);
    assert(tcr == BoundedU256::max(), 'Wrong tcr');
}

