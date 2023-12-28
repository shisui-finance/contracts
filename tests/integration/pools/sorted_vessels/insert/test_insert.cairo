use core::{array::{ArrayTrait}, debug::PrintTrait};
use starknet::{ContractAddress, get_caller_address, contract_address_const};
use shisui::{
    core::address_provider::{
        IAddressProviderDispatcher, IAddressProviderDispatcherTrait, AddressesKey
    },
    pools::sorted_vessels::{
        ISortedVesselsDispatcher, ISortedVesselsDispatcherTrait,
        SortedVessels::{Node, Event, NodeAdded}
    }
};
use tests::tests_lib::{deploy_address_provider, deploy_sorted_vessels};
use snforge_std::{
    start_prank, stop_prank, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions,
    start_mock_call
};

fn setup() -> (
    IAddressProviderDispatcher,
    ISortedVesselsDispatcher,
    ContractAddress,
    ContractAddress,
    ContractAddress,
    ContractAddress,
    ContractAddress,
    ContractAddress,
    ContractAddress
) {
    let address_provider = IAddressProviderDispatcher {
        contract_address: deploy_address_provider()
    };
    let sorted_vessels = ISortedVesselsDispatcher {
        contract_address: deploy_sorted_vessels(address_provider.contract_address)
    };
    let borrower_operations = contract_address_const::<'borrower_operations'>();
    let vessel_manager = contract_address_const::<'vessel_manager'>();
    let asset = contract_address_const::<'asset'>();
    let user_1 = contract_address_const::<'user_1'>();
    let user_2 = contract_address_const::<'user_2'>();
    let user_3 = contract_address_const::<'user_3'>();
    let address_zero = contract_address_const::<0>();

    address_provider.set_address(AddressesKey::borrower_operations, borrower_operations);
    address_provider.set_address(AddressesKey::vessel_manager, vessel_manager);

    (
        address_provider,
        sorted_vessels,
        borrower_operations,
        vessel_manager,
        asset,
        user_1,
        user_2,
        user_3,
        address_zero
    )
}

#[test]
#[should_panic(expected: ('Caller is not authorized',))]
fn given_caller_is_not_borrower_operations_nor_vessel_manager_it_should_revert() {
    let (_, sorted_vessels, _, _, asset, user_1, _, _, address_zero) = setup();
    sorted_vessels.insert(asset, user_1, 100, address_zero, address_zero);
}

#[test]
#[should_panic(expected: ('Node already exists',))]
fn given_node_already_exists_it_should_revert() {
    let (_, sorted_vessels, borrower_operations, _, asset, user_1, _, _, address_zero) = setup();
    start_prank(CheatTarget::One(sorted_vessels.contract_address), borrower_operations);
    sorted_vessels.insert(asset, user_1, 100, address_zero, address_zero);
    sorted_vessels.insert(asset, user_1, 100, address_zero, address_zero);
    stop_prank(CheatTarget::One(sorted_vessels.contract_address));
}

#[test]
#[should_panic(expected: ('Address is zero',))]
fn given_id_is_address_zero_it_should_revert() {
    let (_, sorted_vessels, borrower_operations, _, asset, _, _, _, address_zero) = setup();
    start_prank(CheatTarget::One(sorted_vessels.contract_address), borrower_operations);
    sorted_vessels.insert(asset, address_zero, 100, address_zero, address_zero);
    stop_prank(CheatTarget::One(sorted_vessels.contract_address));
}

#[test]
#[should_panic(expected: ('NICR must be positive',))]
fn given_NICR_is_zero_it_should_revert() {
    let (_, sorted_vessels, borrower_operations, _, asset, user_1, _, _, address_zero) = setup();
    start_prank(CheatTarget::One(sorted_vessels.contract_address), borrower_operations);
    sorted_vessels.insert(asset, user_1, 0, address_zero, address_zero);
    stop_prank(CheatTarget::One(sorted_vessels.contract_address));
}

#[test]
fn given_valid_insert_position_it_should_insert_with_empty_list() {
    let (_, sorted_vessels, borrower_operations, _, asset, user_1, _, _, address_zero) = setup();
    start_prank(CheatTarget::One(sorted_vessels.contract_address), borrower_operations);
    let mut spy = spy_events(SpyOn::One(sorted_vessels.contract_address));
    sorted_vessels.insert(asset, user_1, 100, address_zero, address_zero);

    // event check
    spy
        .assert_emitted(
            @array![
                (
                    sorted_vessels.contract_address,
                    Event::NodeAdded(NodeAdded { asset: asset, id: user_1, NICR: 100, })
                )
            ]
        );

    assert(spy.events.len() == 0, 'There should be no events');
    assert(sorted_vessels.is_empty(asset) == false, 'List is empty');
    assert(sorted_vessels.get_size(asset) == 1, 'Invalid list size');
    assert(sorted_vessels.get_first(asset) == user_1, 'Invalid first node');
    assert(sorted_vessels.get_last(asset) == user_1, 'Invalid last node');
    assert(sorted_vessels.get_next(asset, user_1) == address_zero, 'Invalid next node');
    assert(sorted_vessels.get_prev(asset, user_1) == address_zero, 'Invalid prev node');

    stop_prank(CheatTarget::One(sorted_vessels.contract_address));
}

#[test]
fn given_valid_insert_point_it_should_insert_first() {
    let (_, sorted_vessels, borrower_operations, _, asset, user_1, user_2, _, address_zero) =
        setup();
    start_prank(CheatTarget::One(sorted_vessels.contract_address), borrower_operations);
    sorted_vessels.insert(asset, user_1, 100, address_zero, address_zero);
    sorted_vessels.insert(asset, user_2, 50, address_zero, user_1);

    assert(sorted_vessels.is_empty(asset) == false, 'List is empty');
    assert(sorted_vessels.get_size(asset) == 2, 'Invalid list size');
    assert(sorted_vessels.get_first(asset) == user_2, 'Invalid first node');
    assert(sorted_vessels.get_last(asset) == user_1, 'Invalid last node');
    assert(sorted_vessels.get_next(asset, user_2) == user_1, 'Invalid next node');
    assert(sorted_vessels.get_prev(asset, user_2) == address_zero, 'Invalid prev node');
    assert(sorted_vessels.get_next(asset, user_1) == address_zero, 'Invalid next node');
    assert(sorted_vessels.get_prev(asset, user_1) == user_2, 'Invalid prev node');

    stop_prank(CheatTarget::One(sorted_vessels.contract_address));
}

#[test]
fn given_valid_insert_point_it_should_insert_last() {
    let (_, sorted_vessels, borrower_operations, _, asset, user_1, user_2, _, address_zero) =
        setup();
    start_prank(CheatTarget::One(sorted_vessels.contract_address), borrower_operations);
    sorted_vessels.insert(asset, user_1, 100, address_zero, address_zero);
    sorted_vessels.insert(asset, user_2, 150, user_1, address_zero);

    assert(sorted_vessels.is_empty(asset) == false, 'List is empty');
    assert(sorted_vessels.get_size(asset) == 2, 'Invalid list size');
    assert(sorted_vessels.get_first(asset) == user_1, 'Invalid first node');
    assert(sorted_vessels.get_last(asset) == user_2, 'Invalid last node');
    assert(sorted_vessels.get_next(asset, user_1) == user_2, 'Invalid next node');
    assert(sorted_vessels.get_prev(asset, user_1) == address_zero, 'Invalid prev node');
    assert(sorted_vessels.get_next(asset, user_2) == address_zero, 'Invalid next node');
    assert(sorted_vessels.get_prev(asset, user_2) == user_1, 'Invalid prev node');

    stop_prank(CheatTarget::One(sorted_vessels.contract_address));
}

#[test]
fn given_valid_insert_point_it_should_insert_middle() {
    let (_, sorted_vessels, borrower_operations, _, asset, user_1, user_2, user_3, address_zero) =
        setup();
    start_prank(CheatTarget::One(sorted_vessels.contract_address), borrower_operations);
    sorted_vessels.insert(asset, user_1, 100, address_zero, address_zero);
    sorted_vessels.insert(asset, user_3, 150, user_1, address_zero);
    let mut spy = spy_events(SpyOn::One(sorted_vessels.contract_address));
    sorted_vessels.insert(asset, user_2, 125, user_1, user_3);

    assert(sorted_vessels.is_empty(asset) == false, 'List is empty');
    assert(sorted_vessels.get_size(asset) == 3, 'Invalid list size');
    assert(sorted_vessels.get_first(asset) == user_1, 'Invalid first node');
    assert(sorted_vessels.get_last(asset) == user_3, 'Invalid last node');
    assert(sorted_vessels.get_next(asset, user_1) == user_2, 'Invalid next node');
    assert(sorted_vessels.get_prev(asset, user_1) == address_zero, 'Invalid prev node');
    assert(sorted_vessels.get_next(asset, user_2) == user_3, 'Invalid next node');
    assert(sorted_vessels.get_prev(asset, user_2) == user_1, 'Invalid prev node');
    assert(sorted_vessels.get_next(asset, user_3) == address_zero, 'Invalid next node');
    assert(sorted_vessels.get_prev(asset, user_3) == user_2, 'Invalid prev node');

    stop_prank(CheatTarget::One(sorted_vessels.contract_address));
}

#[test]
fn given_invalid_insert_position_it_should_find_correct_position_and_insert() {
    let (_, sorted_vessels, borrower_operations, _, asset, user_1, user_2, user_3, address_zero) =
        setup();

    start_prank(CheatTarget::One(sorted_vessels.contract_address), borrower_operations);

    sorted_vessels.insert(asset, user_1, 100, address_zero, address_zero);
    sorted_vessels.insert(asset, user_3, 150, user_1, address_zero);
    sorted_vessels.insert(asset, user_2, 125, user_1, address_zero);

    assert(sorted_vessels.is_empty(asset) == false, 'List is empty');
    assert(sorted_vessels.get_size(asset) == 3, 'Invalid list size');
    assert(sorted_vessels.get_first(asset) == user_1, 'Invalid first node');
    assert(sorted_vessels.get_last(asset) == user_3, 'Invalid last node');
    assert(sorted_vessels.get_next(asset, user_1) == user_2, 'Invalid next node');
    assert(sorted_vessels.get_prev(asset, user_1) == address_zero, 'Invalid prev node');
    assert(sorted_vessels.get_next(asset, user_2) == user_3, 'Invalid next node');
    assert(sorted_vessels.get_prev(asset, user_2) == user_1, 'Invalid prev node');
    assert(sorted_vessels.get_next(asset, user_3) == address_zero, 'Invalid next node');
    assert(sorted_vessels.get_prev(asset, user_3) == user_2, 'Invalid prev node');

    stop_prank(CheatTarget::One(sorted_vessels.contract_address));
}
