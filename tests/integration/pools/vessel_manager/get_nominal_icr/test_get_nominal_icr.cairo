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
    start_prank, stop_prank, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions,
    start_mock_call, PrintTrait
};
use starknet::{ContractAddress, contract_address_const, get_caller_address};


#[test]
fn when_vessel_exists_nominal_icr_is_correctly_calculated() {
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

    let nicr = vessel_manager.get_nominal_icr(asset.contract_address, caller);

    assert(
        nicr >= 9_4000000000000000 && nicr <= 9_5000000000000000, 'Wrong nicr'
    ); //9.4e16 && 9.5e16 = 1.89 * NCIR_PRECISION / 2000
}

#[test]
fn when_vessel_not_exist_it_should_return_max_value() {
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
    let caller = contract_address_const::<'caller'>();
    let nicr = vessel_manager.get_nominal_icr(asset.contract_address, caller);
    assert(nicr == BoundedU256::max(), 'Wrong nicr');
}
