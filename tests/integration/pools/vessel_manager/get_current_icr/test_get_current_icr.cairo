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
fn when_vessel_exists_current_icr_is_correctly_calculated() {
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

    let icr = vessel_manager.get_current_icr(asset.contract_address, caller, asset_price);
    assert(icr >= 1_500000000000000000 && icr <= 1_505000000000000000, 'Wrong icr');

    // simulate price change
    asset_price = 2000_000000000000000000; //price increase from 1600 to 2000
    let new_icr = vessel_manager.get_current_icr(asset.contract_address, caller, asset_price);
    assert(new_icr >= 1_880000000000000000 && new_icr <= 1_881000000000000000, 'Wrong icr');
}
