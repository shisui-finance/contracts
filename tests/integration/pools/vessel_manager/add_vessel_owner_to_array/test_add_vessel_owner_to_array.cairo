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
    vessel_manager::{IVesselManagerDispatcher, IVesselManagerDispatcherTrait},
};
use snforge_std::{
    start_prank, stop_prank, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions,
    start_mock_call, PrintTrait
};
use starknet::{ContractAddress, contract_address_const, get_caller_address};

#[test]
#[should_panic(expected: ('Only borrower operations',))]
fn when_caller_is_not_borrower_operations_it_should_revert() {
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

    let caller = contract_address_const::<'caller'>();
    let borrower = contract_address_const::<'borrower'>();
    start_prank(CheatTarget::One(vessel_manager.contract_address), caller);
    vessel_manager.add_vessel_owner_to_array(asset.contract_address, borrower);
}

#[test]
fn when_caller_is_borrower_operations_it_add_vessel_to_owner_array() {
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

    let caller = contract_address_const::<'caller'>();
    let borrower = contract_address_const::<'borrower'>();
    start_prank(
        CheatTarget::One(vessel_manager.contract_address), borrower_operations.contract_address
    );
    let mut nb_owners = vessel_manager.get_vessel_owners_count(asset.contract_address);
    assert(nb_owners == 0, 'Wrong owner number at init');
    vessel_manager.add_vessel_owner_to_array(asset.contract_address, borrower);
    nb_owners = vessel_manager.get_vessel_owners_count(asset.contract_address);
    assert(nb_owners == 1, 'Wrong owner number');
}
