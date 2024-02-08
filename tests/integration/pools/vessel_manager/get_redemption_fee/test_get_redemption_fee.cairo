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
    vessel_manager::{
        IVesselManagerDispatcher, IVesselManagerDispatcherTrait, VesselManager,
        VesselManagerOperation, Status
    },
};
use snforge_std::{
    start_prank, stop_prank, start_warp, store, map_entry_address, CheatTarget, spy_events, SpyOn,
    EventSpy, EventAssertions, start_mock_call, PrintTrait
};
use starknet::{ContractAddress, contract_address_const, get_caller_address};

#[test]
fn when_base_rate_is_defined_should_return_redemption_fee() {
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

    admin_contract.add_new_collateral(asset.contract_address, 1000, 18);

    start_prank(
        CheatTarget::One(vessel_manager.contract_address), borrower_operations.contract_address
    );
    vessel_manager.set_base_rate(asset.contract_address, 100000000000000000); // 1e17
    stop_prank(CheatTarget::One(vessel_manager.contract_address));

    let fee = vessel_manager.get_redemption_fee(asset.contract_address, 10);
    assert(fee == 1, 'Wrong redemption fee');
}

#[test]
#[should_panic(expected: ('Fee bigger than assert draw',))]
fn when_base_rate_is_defined_and_redemption_fee_is_below_asset_draw_should_revert() {
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

    admin_contract.add_new_collateral(asset.contract_address, 1000, 18);

    start_prank(
        CheatTarget::One(vessel_manager.contract_address), borrower_operations.contract_address
    );
    vessel_manager.set_base_rate(asset.contract_address, 1000000000000000000); // 1e18
    stop_prank(CheatTarget::One(vessel_manager.contract_address));

    vessel_manager.get_redemption_fee_with_decay(asset.contract_address, 10);
}

