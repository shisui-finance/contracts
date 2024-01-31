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
    start_prank, stop_prank, store, map_entry_address, CheatTarget, spy_events, SpyOn, EventSpy,
    EventAssertions, start_mock_call, PrintTrait
};
use starknet::{ContractAddress, contract_address_const, get_caller_address};


#[test]
fn when_vessel_is_active_return_true() {
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

    assert(vessel_manager.is_vessel_active(asset.contract_address, borrower), 'Wrong status');
}

#[test]
fn when_vessel_is_not_active_return_false() {
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

    start_prank(
        CheatTarget::One(vessel_manager.contract_address), borrower_operations.contract_address
    );
    vessel_manager.set_vessel_status(asset.contract_address, borrower, Status::NonExistent);
    stop_prank(CheatTarget::One(vessel_manager.contract_address));
    assert(
        !vessel_manager.is_vessel_active(asset.contract_address, borrower),
        'Wrong status for NonExistent'
    );

    start_prank(
        CheatTarget::One(vessel_manager.contract_address), borrower_operations.contract_address
    );
    vessel_manager.set_vessel_status(asset.contract_address, borrower, Status::ClosedByOwner);
    stop_prank(CheatTarget::One(vessel_manager.contract_address));
    assert(
        !vessel_manager.is_vessel_active(asset.contract_address, borrower),
        'Wrong status for ClosedByOwner'
    );

    start_prank(
        CheatTarget::One(vessel_manager.contract_address), borrower_operations.contract_address
    );
    vessel_manager.set_vessel_status(asset.contract_address, borrower, Status::ClosedByLiquidation);
    stop_prank(CheatTarget::One(vessel_manager.contract_address));
    assert(
        !vessel_manager.is_vessel_active(asset.contract_address, borrower),
        'Wrong stat. ClosedByLiquidation'
    );

    start_prank(
        CheatTarget::One(vessel_manager.contract_address), borrower_operations.contract_address
    );
    vessel_manager.set_vessel_status(asset.contract_address, borrower, Status::ClosedByRedemption);
    stop_prank(CheatTarget::One(vessel_manager.contract_address));
    assert(
        !vessel_manager.is_vessel_active(asset.contract_address, borrower),
        'Wrong stat. ClosedByRedemption'
    );
}

#[test]
fn when_vessel_is_not_existing_return_false() {
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

    let borrower = contract_address_const::<'borrower'>();

    assert(!vessel_manager.is_vessel_active(asset.contract_address, borrower), 'Wrong status');
}

