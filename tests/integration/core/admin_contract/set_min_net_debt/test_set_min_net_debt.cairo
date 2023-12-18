use starknet::{ContractAddress, contract_address_const};
use snforge_std::{start_prank, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions};
use shisui::core::{
    address_provider::{IAddressProviderDispatcher, IAddressProviderDispatcherTrait, AddressesKey},
    admin_contract::{IAdminContractDispatcher, IAdminContractDispatcherTrait, AdminContract}
};
use shisui::utils::math::pow;
use super::super::setup::setup;

fn test_setup() -> (
    IAddressProviderDispatcher, IAdminContractDispatcher, ContractAddress, ContractAddress
) {
    let (address_provider, admin_contract, timelock_address) = setup();
    let collateral_address = contract_address_const::<'collateral'>();
    admin_contract.add_new_collateral(collateral_address, 1000, 18);

    (address_provider, admin_contract, collateral_address, timelock_address)
}

#[test]
#[should_panic(expected: ('Caller is not Owner',))]
fn given_setup_not_initialized_and_caller_is_not_owner_it_should_revert() {
    let (address_provider, admin_contract, collateral_address, _) = test_setup();
    start_prank(
        CheatTarget::One(admin_contract.contract_address), contract_address_const::<'not_owner'>()
    );
    admin_contract.set_min_net_debt(collateral_address, 0);
}

#[test]
#[should_panic(expected: ('Caller not Timelock',))]
fn given_setup_is_initialized_and_caller_is_not_timelock_it_should_revert() {
    let (address_provider, admin_contract, collateral_address, _) = test_setup();
    admin_contract.set_setup_initialized();
    start_prank(
        CheatTarget::One(admin_contract.contract_address),
        contract_address_const::<'not_timelock'>()
    );
    admin_contract.set_min_net_debt(collateral_address, 0);
}

#[test]
#[should_panic(expected: ('Collateral not active',))]
fn given_valid_caller_and_collateral_not_active_it_should_revert() {
    let (address_provider, admin_contract, collateral_address, _) = test_setup();

    admin_contract.set_min_net_debt(collateral_address, 0);
}

#[test]
#[should_panic(expected: ('Value out of range',))]
fn given_valid_caller_and_value_exceed_max_value_it_should_revert() {
    let (address_provider, admin_contract, collateral_address, _) = test_setup();
    admin_contract.set_is_active(collateral_address, true);
    admin_contract.set_min_net_debt(collateral_address, 2000 * pow(10, 18) + 1);
}


#[test]
fn given_valid_caller_and_value_equal_min_it_should_update_the_min_net_debt_value() {
    let (address_provider, admin_contract, collateral_address, _) = test_setup();
    admin_contract.set_is_active(collateral_address, true);
    let min_value = 0;
    let mut spy = spy_events(SpyOn::One(admin_contract.contract_address));

    admin_contract.set_min_net_debt(collateral_address, min_value);
    // event check
    spy
        .assert_emitted(
            @array![
                (
                    admin_contract.contract_address,
                    AdminContract::Event::MinNetDebtUpdated(
                        AdminContract::MinNetDebtUpdated {
                            collateral: collateral_address,
                            old_min_net_debt: AdminContract::MIN_NET_DEBT_DEFAULT,
                            min_net_debt: min_value
                        }
                    )
                )
            ]
        );
    assert(spy.events.len() == 0, 'There should be no events');
    assert(
        admin_contract.get_min_net_debt(collateral_address) == min_value,
        'MIN_NET_DEBT should be updated'
    );
}

#[test]
fn given_valid_caller_and_value_equal_max_it_should_update_the_min_net_debt_value() {
    let (address_provider, admin_contract, collateral_address, _) = test_setup();
    admin_contract.set_is_active(collateral_address, true);
    let max_value = 2000 * pow(10, 18);
    let mut spy = spy_events(SpyOn::One(admin_contract.contract_address));

    admin_contract.set_min_net_debt(collateral_address, max_value);
    // event check
    spy
        .assert_emitted(
            @array![
                (
                    admin_contract.contract_address,
                    AdminContract::Event::MinNetDebtUpdated(
                        AdminContract::MinNetDebtUpdated {
                            collateral: collateral_address,
                            old_min_net_debt: AdminContract::MIN_NET_DEBT_DEFAULT,
                            min_net_debt: max_value
                        }
                    )
                )
            ]
        );
    assert(spy.events.len() == 0, 'There should be no events');
    assert(
        admin_contract.get_min_net_debt(collateral_address) == max_value,
        'MIN_NET_DEBT should be updated'
    );
}

#[test]
fn given_valid_caller_and_value_it_should_update_the_min_net_debt_value() {
    let (address_provider, admin_contract, collateral_address, _) = test_setup();
    admin_contract.set_is_active(collateral_address, true);
    let new_value = 1000 * pow(10, 18);
    let mut spy = spy_events(SpyOn::One(admin_contract.contract_address));

    admin_contract.set_min_net_debt(collateral_address, new_value);
    // event check
    spy
        .assert_emitted(
            @array![
                (
                    admin_contract.contract_address,
                    AdminContract::Event::MinNetDebtUpdated(
                        AdminContract::MinNetDebtUpdated {
                            collateral: collateral_address,
                            old_min_net_debt: AdminContract::MIN_NET_DEBT_DEFAULT,
                            min_net_debt: new_value
                        }
                    )
                )
            ]
        );
    assert(spy.events.len() == 0, 'There should be no events');
    assert(
        admin_contract.get_min_net_debt(collateral_address) == new_value,
        'MIN_NET_DEBT should be updated'
    );
}

