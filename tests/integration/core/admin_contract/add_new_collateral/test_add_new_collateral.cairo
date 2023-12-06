use starknet::{ContractAddress, contract_address_const};
use snforge_std::{start_prank, CheatTarget};
use shisui::core::address_provider::{IAddressProviderDispatcher, IAddressProviderDispatcherTrait};

fn setup() -> (IAddressProviderDispatcher, ContractAddress) {
    let contract_address: ContractAddress = tests::tests_lib::deploy_address_provider();
    let address_provider: IAddressProviderDispatcher = IAddressProviderDispatcher {
        contract_address
    };
    (address_provider, contract_address)
}


// This tests check that not owner can't call the function
// It calls address_provider.set_addresses()
// The test expects the call to revert
#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn given_caller_is_not_owner_it_should_revert() {
    let (address_provider, address_provider_address) = setup();
    let addresses: Span<ContractAddress> = array![
        contract_address_const::<0x1>(),
        contract_address_const::<0x2>(),
        contract_address_const::<0x3>(),
        contract_address_const::<0x4>(),
        contract_address_const::<0x5>(),
        contract_address_const::<0x6>(),
        contract_address_const::<0x7>(),
        contract_address_const::<0x8>(),
        contract_address_const::<0x9>(),
        contract_address_const::<0x10>(),
        contract_address_const::<0x11>(),
        contract_address_const::<0x12>(),
        contract_address_const::<0x13>(),
        contract_address_const::<0x14>(),
    ]
        .span();
    start_prank(
        CheatTarget::One(address_provider_address), contract_address_const::<'not_owner'>()
    );

    address_provider.set_addresses(addresses);
}

// This tests check that contract owner can't call twice the function
// It calls address_provider.set_addresses()
// The test expects the call to revert
#[test]
#[should_panic(expected: ('Protocol addresses already set',))]
fn given_caller_is_owner_and_addresses_already_set_it_should_revert() {
    let (address_provider, address_provider_address) = setup();
    let addresses: Span<ContractAddress> = array![
        contract_address_const::<0x1>(),
        contract_address_const::<0x2>(),
        contract_address_const::<0x3>(),
        contract_address_const::<0x4>(),
        contract_address_const::<0x5>(),
        contract_address_const::<0x6>(),
        contract_address_const::<0x7>(),
        contract_address_const::<0x8>(),
        contract_address_const::<0x9>(),
        contract_address_const::<0x10>(),
        contract_address_const::<0x11>(),
        contract_address_const::<0x12>(),
        contract_address_const::<0x13>(),
        contract_address_const::<0x14>(),
        contract_address_const::<0x15>(),
    ]
        .span();

    address_provider.set_addresses(addresses);
    address_provider.set_addresses(addresses);
}

// This tests check that 15 addresses are required
// It calls address_provider.set_addresses()
// The test expects the call to revert
#[test]
#[should_panic(expected: ('Expected 15 addresses',))]
fn given_caller_is_owner_and_addresses_length_not_15_it_should_revert() {
    let (address_provider, address_provider_address) = setup();
    let addresses: Span<ContractAddress> = array![
        contract_address_const::<0x1>(),
        contract_address_const::<0x2>(),
        contract_address_const::<0x3>(),
        contract_address_const::<0x4>(),
        contract_address_const::<0x5>(),
        contract_address_const::<0x6>(),
        contract_address_const::<0x7>(),
        contract_address_const::<0x8>(),
        contract_address_const::<0x9>(),
        contract_address_const::<0x10>(),
        contract_address_const::<0x11>(),
        contract_address_const::<0x12>(),
        contract_address_const::<0x13>(),
        contract_address_const::<0x14>(),
    ]
        .span();

    address_provider.set_addresses(addresses);
}

// This tests check that no address zero is allowed
// It calls address_provider.set_addresses()
// The test expects the call to revert
#[test]
#[should_panic(expected: ('Address is zero',))]
fn given_caller_is_owner_and_at_least_one_address_is_zero_it_should_revert() {
    let (address_provider, address_provider_address) = setup();
    let addresses: Span<ContractAddress> = array![
        contract_address_const::<0x1>(),
        contract_address_const::<0x2>(),
        contract_address_const::<0x3>(),
        contract_address_const::<0x4>(),
        contract_address_const::<0x5>(),
        contract_address_const::<0x6>(),
        contract_address_const::<0x7>(),
        contract_address_const::<0x8>(),
        contract_address_const::<0x9>(),
        contract_address_const::<0x0>(),
        contract_address_const::<0x11>(),
        contract_address_const::<0x12>(),
        contract_address_const::<0x13>(),
        contract_address_const::<0x14>(),
        contract_address_const::<0x15>(),
    ]
        .span();

    address_provider.set_addresses(addresses);
}

// This tests check that contract owner can set addresses
// It calls address_provider.set_addresses()
#[test]
fn given_caller_is_owner_it_should_set_addresses() {
    let (address_provider, address_provider_address) = setup();
    let addresses: Span<ContractAddress> = array![
        contract_address_const::<0x1>(),
        contract_address_const::<0x2>(),
        contract_address_const::<0x3>(),
        contract_address_const::<0x4>(),
        contract_address_const::<0x5>(),
        contract_address_const::<0x6>(),
        contract_address_const::<0x7>(),
        contract_address_const::<0x8>(),
        contract_address_const::<0x9>(),
        contract_address_const::<0x10>(),
        contract_address_const::<0x11>(),
        contract_address_const::<0x12>(),
        contract_address_const::<0x13>(),
        contract_address_const::<0x14>(),
        contract_address_const::<0x15>(),
    ]
        .span();

    address_provider.set_addresses(addresses);
    assert(address_provider.get_active_pool() == *addresses[0], 'active_pool not correct');
    assert(address_provider.get_admin_contract() == *addresses[1], 'admin_contract not correct');
    assert(
        address_provider.get_borrower_operations() == *addresses[2],
        'borrower_operations not correct'
    );
    assert(
        address_provider.get_coll_surplus_pool() == *addresses[3], 'coll_surplus_pool not correct'
    );
    assert(address_provider.get_debt_token() == *addresses[4], 'debt_token not correct');
    assert(address_provider.get_default_pool() == *addresses[5], 'default_pool not correct');
    assert(address_provider.get_fee_collector() == *addresses[6], 'fee_collector not correct');
    assert(
        address_provider.get_gas_pool_address() == *addresses[7], 'gas_pool_address not correct'
    );
    assert(address_provider.get_price_feed() == *addresses[8], 'price_feed not correct');
    assert(address_provider.get_sorted_vessels() == *addresses[9], 'sorted_vessels not correct');
    assert(address_provider.get_stability_pool() == *addresses[10], 'stability_pool not correct');
    assert(
        address_provider.get_timelock_address() == *addresses[11], 'timelock_address not correct'
    );
    assert(
        address_provider.get_treasury_address() == *addresses[12], 'treasury_address not correct'
    );
    assert(address_provider.get_vessel_manager() == *addresses[13], 'vessel_manager not correct');
    assert(
        address_provider.get_vessel_manager_operations() == *addresses[14],
        'vesselM_operations not correct'
    );
}

