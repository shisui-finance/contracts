use starknet::{ContractAddress, contract_address_const};
use snforge_std::{start_prank, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions};
use shisui::core::address_provider::{
    IAddressProviderDispatcher, IAddressProviderDispatcherTrait, AddressesKey, AddressProvider
};
use shisui::utils::traits::ContractAddressDefault;

fn setup() -> (IAddressProviderDispatcher, ContractAddress) {
    let contract_address: ContractAddress = tests::tests_lib::deploy_address_provider();
    let address_provider: IAddressProviderDispatcher = IAddressProviderDispatcher {
        contract_address
    };
    (address_provider, contract_address)
}


#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn given_caller_is_not_owner_on_new_address_set_it_should_revert() {
    let (address_provider, address_provider_address) = setup();
    start_prank(
        CheatTarget::One(address_provider_address), contract_address_const::<'not_owner'>()
    );
    address_provider
        .set_address(AddressesKey::active_pool, contract_address_const::<'active_pool'>());
}

#[test]
#[should_panic(expected: ('Address is zero',))]
fn given_caller_is_owner_setting_new_address_zero_it_should_revert() {
    let (address_provider, address_provider_address) = setup();

    address_provider.set_address(AddressesKey::active_pool, contract_address_const::<0x00>());
}


#[test]
#[should_panic(expected: ('Caller not Timelock',))]
fn given_caller_is_owner_and_key_already_has_an_address_it_should_revert() {
    let (address_provider, address_provider_address) = setup();
    address_provider
        .set_address(AddressesKey::active_pool, contract_address_const::<'active_pool'>());

    address_provider
        .set_address(AddressesKey::active_pool, contract_address_const::<'new_active_pool'>());
}

#[test]
fn given_caller_is_owner_it_should_set_new_address() {
    let (address_provider, address_provider_address) = setup();
    let active_pool_address = contract_address_const::<'active_pool'>();
    let mut spy = spy_events(SpyOn::One(address_provider.contract_address));

    address_provider.set_address(AddressesKey::active_pool, active_pool_address);

    // event check
    spy
        .assert_emitted(
            @array![
                (
                    address_provider.contract_address,
                    AddressProvider::Event::NewAddressRegistered(
                        AddressProvider::NewAddressRegistered {
                            key: 'active_pool',
                            old_address: Default::default(),
                            new_address: active_pool_address,
                        }
                    )
                )
            ]
        );
    assert(spy.events.len() == 0, 'There should be no events');
    assert(
        address_provider.get_address(AddressesKey::active_pool) == active_pool_address,
        'Wrong address'
    );
}

#[test]
#[should_panic(expected: ('Caller not Timelock',))]
fn given_caller_is_not_timelock_and_updating_address_of_key_it_should_revert() {
    let (address_provider, address_provider_address) = setup();
    address_provider
        .set_address(AddressesKey::active_pool, contract_address_const::<'active_pool'>());

    start_prank(
        CheatTarget::One(address_provider_address), contract_address_const::<'not_timelock'>()
    );

    address_provider
        .set_address(AddressesKey::active_pool, contract_address_const::<'new_active_pool'>());
}

#[test]
#[should_panic(expected: ('Address is zero',))]
fn given_caller_is_timelock_updating_key_by_address_zero_it_should_revert() {
    let (address_provider, address_provider_address) = setup();
    address_provider
        .set_address(AddressesKey::active_pool, contract_address_const::<'active_pool'>());

    address_provider.set_address(AddressesKey::active_pool, contract_address_const::<0x00>());
}

#[test]
fn given_caller_is_timelock_it_should_update_key_address() {
    let (address_provider, address_provider_address) = setup();
    let timelock_address = contract_address_const::<'timelock'>();
    let new_active_pool_address = contract_address_const::<'new_active_pool'>();
    let first_active_pool_address = contract_address_const::<'active_pool'>();
    address_provider.set_address(AddressesKey::active_pool, first_active_pool_address);

    address_provider.set_address(AddressesKey::timelock, timelock_address);

    start_prank(CheatTarget::One(address_provider_address), timelock_address);

    let mut spy = spy_events(SpyOn::One(address_provider.contract_address));

    address_provider.set_address(AddressesKey::active_pool, new_active_pool_address);

    // event check
    spy
        .assert_emitted(
            @array![
                (
                    address_provider.contract_address,
                    AddressProvider::Event::NewAddressRegistered(
                        AddressProvider::NewAddressRegistered {
                            key: 'active_pool',
                            old_address: first_active_pool_address,
                            new_address: new_active_pool_address,
                        }
                    )
                )
            ]
        );
    assert(spy.events.len() == 0, 'There should be no events');
    assert(
        address_provider.get_address(AddressesKey::active_pool) == new_active_pool_address,
        'Wrong address'
    );
}
