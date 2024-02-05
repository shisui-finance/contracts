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
    start_prank, stop_prank, store, map_entry_address, CheatTarget, spy_events, SpyOn, EventSpy,
    EventAssertions, start_mock_call, PrintTrait
};
use starknet::{ContractAddress, contract_address_const, get_caller_address};


#[test]
#[should_panic(expected: ('Only borrower operations',))]
fn when_caller_is_not_borrower_operation_it_should_revert() {
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

    let borrower = contract_address_const::<'borrower'>();

    vessel_manager.decrease_vessel_coll(asset.contract_address, borrower, 10);
}

#[test]
fn when_caller_is_borrower_it_should_update_vessel_coll() {
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

    let coll_increment = 10;
    let coll = vessel_manager.get_vessel_coll(asset.contract_address, borrower);
    assert(coll == deposit_amount, 'Wrong initital coll');
    start_prank(
        CheatTarget::One(vessel_manager.contract_address), borrower_operations.contract_address
    );
    let new_coll = vessel_manager
        .decrease_vessel_coll(asset.contract_address, borrower, coll_increment);
    stop_prank(CheatTarget::One(vessel_manager.contract_address));
    assert(new_coll == deposit_amount - coll_increment, 'Wrong new coll');
    let current_debt = vessel_manager.get_vessel_coll(asset.contract_address, borrower);
    assert(current_debt == deposit_amount - coll_increment, 'Wrong vessel coll');
}

