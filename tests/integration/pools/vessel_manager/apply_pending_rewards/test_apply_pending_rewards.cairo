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
    start_prank, stop_prank, store, map_entry_address, CheatTarget, spy_events, SpyOn, EventSpy,
    EventAssertions, start_mock_call, PrintTrait
};
use starknet::{ContractAddress, contract_address_const, get_caller_address};

#[test]
#[should_panic(expected: ('Only vessel mngr op or borrower',))]
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

    let caller = contract_address_const::<'caller'>();
    let borrower = contract_address_const::<'borrower'>();
    start_prank(CheatTarget::One(vessel_manager.contract_address), caller);
    vessel_manager.apply_pending_rewards(asset.contract_address, borrower);
    stop_prank(CheatTarget::One(vessel_manager.contract_address));
}

#[test]
fn when_vessel_has_no_pending_reward_it_should_not_update_vessel() {
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

    let coll = vessel_manager.get_vessel_coll(asset.contract_address, borrower);
    let debt = vessel_manager.get_vessel_debt(asset.contract_address, borrower);
    let stake = vessel_manager.get_vessel_stake(asset.contract_address, borrower);

    // update vessel status to siulate vessel has no pending reward
    start_prank(
        CheatTarget::One(vessel_manager.contract_address), borrower_operations.contract_address
    );
    vessel_manager.set_vessel_status(asset.contract_address, borrower, Status::NonExistent);
    stop_prank(CheatTarget::One(vessel_manager.contract_address));

    let rewards: u8 = 10;

    store(
        vessel_manager.contract_address,
        map_entry_address(selector!("l_colls"), array![asset.contract_address.into()].span()),
        array![rewards.into()].span()
    );

    store(
        vessel_manager.contract_address,
        map_entry_address(selector!("l_debts"), array![asset.contract_address.into()].span()),
        array![rewards.into()].span()
    );

    let mut spy = spy_events(SpyOn::One(vessel_manager.contract_address));
    start_prank(
        CheatTarget::One(vessel_manager.contract_address), vessel_manager_operations_address
    );
    vessel_manager.apply_pending_rewards(asset.contract_address, borrower);
    stop_prank(CheatTarget::One(vessel_manager.contract_address));

    let asset_address = asset.contract_address;

    // event check
    spy
        .assert_not_emitted(
            @array![
                (
                    vessel_manager.contract_address,
                    VesselManager::Event::VesselUpdated(
                        VesselManager::VesselUpdated {
                            asset: asset_address,
                            borrower,
                            debt,
                            coll,
                            stake,
                            operation: VesselManagerOperation::ApplyPendingRewards
                        }
                    )
                ),
                (
                    vessel_manager.contract_address,
                    VesselManager::Event::VesselSnapshotsUpdated(
                        VesselManager::VesselSnapshotsUpdated {
                            asset: asset_address,
                            borrower,
                            l_coll: rewards.into(),
                            l_debt: rewards.into()
                        }
                    )
                )
            ]
        );

    let new_coll = vessel_manager.get_vessel_coll(asset.contract_address, borrower);
    let new_debt = vessel_manager.get_vessel_debt(asset.contract_address, borrower);

    assert(new_coll == coll, 'Wrong coll');
    assert(new_debt == debt, 'Wrong debt');
}

#[test]
fn when_vessel_has_pending_reward_it_should_update_vessel() {
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

    let rewards: u8 = 10;

    store(
        vessel_manager.contract_address,
        map_entry_address(selector!("l_colls"), array![asset.contract_address.into()].span()),
        array![rewards.into()].span()
    );

    store(
        vessel_manager.contract_address,
        map_entry_address(selector!("l_debts"), array![asset.contract_address.into()].span()),
        array![rewards.into()].span()
    );

    let coll = vessel_manager.get_vessel_coll(asset.contract_address, borrower);
    let debt = vessel_manager.get_vessel_debt(asset.contract_address, borrower);
    let stake = vessel_manager.get_vessel_stake(asset.contract_address, borrower);

    start_prank(
        CheatTarget::One(vessel_manager.contract_address), vessel_manager_operations_address
    );
    let mut spy = spy_events(SpyOn::One(vessel_manager.contract_address));
    vessel_manager.apply_pending_rewards(asset.contract_address, borrower);
    stop_prank(CheatTarget::One(vessel_manager.contract_address));

    let new_debt = debt + 18; // deposit_amount * rewards / precision=18
    let new_coll = coll + 18; // deposit_amount * rewards / precision=18

    assert(
        new_coll == vessel_manager.get_vessel_coll(asset.contract_address, borrower), 'Wrong coll'
    );
    assert(
        new_debt == vessel_manager.get_vessel_debt(asset.contract_address, borrower), 'Wrong debt'
    );

    let asset_address = asset.contract_address;

    // event check
    spy
        .assert_emitted(
            @array![
                (
                    vessel_manager.contract_address,
                    VesselManager::Event::VesselUpdated(
                        VesselManager::VesselUpdated {
                            asset: asset_address,
                            borrower,
                            debt: new_debt,
                            coll: new_coll,
                            stake,
                            operation: VesselManagerOperation::ApplyPendingRewards
                        }
                    )
                ),
                (
                    vessel_manager.contract_address,
                    VesselManager::Event::VesselSnapshotsUpdated(
                        VesselManager::VesselSnapshotsUpdated {
                            asset: asset_address,
                            borrower,
                            l_coll: rewards.into(),
                            l_debt: rewards.into()
                        }
                    )
                )
            ]
        );
}

