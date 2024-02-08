use starknet::{ContractAddress, contract_address_const, get_caller_address};
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
use tests::tests_lib::{deploy_main_contracts};
use snforge_std::{
    start_prank, stop_prank, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions,
    start_mock_call, PrintTrait
};


#[test]
fn when_borrowing_fee_is_defined_for_asset_should_return_fee_based_on_debt() {
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

    let debt_token_amount: u256 = 2000_000000000000000000;

    admin_contract.add_new_collateral(asset.contract_address, 1000, 18);

    let fee = vessel_manager.get_borrowing_fee(asset.contract_address, debt_token_amount);
    assert(fee == 1_0000000000000000000, 'Wrong fee');
}

#[test]
fn when_borrowing_fee_is_not_defined_for_asset_should_return_0() {
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

    let debt_token_amount: u256 = 2000_000000000000000000;

    let fee = vessel_manager.get_borrowing_fee(asset.contract_address, debt_token_amount);
    assert(fee == 0, 'Wrong fee');
}
