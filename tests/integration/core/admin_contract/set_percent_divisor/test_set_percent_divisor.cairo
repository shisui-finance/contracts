use starknet::{ContractAddress, contract_address_const};
use snforge_std::{start_prank, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions};
use shisui::core::admin_contract::{
    IAdminContractDispatcher, IAdminContractDispatcherTrait, AdminContract
};

use super::super::setup::setup;

fn test_setup() -> (IAdminContractDispatcher, ContractAddress, ContractAddress) {
    let (admin_contract, timelock_address) = setup();
    let collateral_address = contract_address_const::<'collateral'>();
    admin_contract.add_new_collateral(collateral_address, 1000, 18);

    (admin_contract, collateral_address, timelock_address)
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn given_setup_not_initialized_and_caller_is_not_owner_it_should_revert() {
    let (admin_contract, collateral_address, _) = test_setup();
    start_prank(
        CheatTarget::One(admin_contract.contract_address), contract_address_const::<'not_owner'>()
    );
    admin_contract.set_percent_divisor(collateral_address, 0);
}

#[test]
#[should_panic(expected: ('Caller is not Timelock',))]
fn given_setup_is_initialized_and_caller_is_not_timelock_it_should_revert() {
    let (admin_contract, collateral_address, _) = test_setup();
    admin_contract.set_setup_initialized();
    start_prank(
        CheatTarget::One(admin_contract.contract_address),
        contract_address_const::<'not_timelock'>()
    );
    admin_contract.set_percent_divisor(collateral_address, 0);
}

#[test]
#[should_panic(expected: ('Collateral not active',))]
fn given_valid_caller_and_collateral_not_active_it_should_revert() {
    let (admin_contract, collateral_address, _) = test_setup();

    admin_contract.set_percent_divisor(collateral_address, 0);
}

#[test]
#[should_panic(expected: ('Value out of range',))]
fn given_valid_caller_and_value_exceed_max_value_it_should_revert() {
    let (admin_contract, collateral_address, _) = test_setup();
    admin_contract.set_is_active(collateral_address, true);
    admin_contract.set_percent_divisor(collateral_address, 201);
}


#[test]
fn given_valid_caller_and_value_equal_min_it_should_update_the_percent_divisor_value() {
    let (admin_contract, collateral_address, _) = test_setup();
    admin_contract.set_is_active(collateral_address, true);
    let min_value = 2;
    let mut spy = spy_events(SpyOn::One(admin_contract.contract_address));

    admin_contract.set_percent_divisor(collateral_address, min_value);
    // event check
    spy
        .assert_emitted(
            @array![
                (
                    admin_contract.contract_address,
                    AdminContract::Event::PercentDivisorUpdated(
                        AdminContract::PercentDivisorUpdated {
                            collateral: collateral_address,
                            old_percent_divisor: AdminContract::PERCENT_DIVISOR_DEFAULT,
                            percent_divisor: min_value
                        }
                    )
                )
            ]
        );
    assert(spy.events.len() == 0, 'There should be no events');
    assert(
        admin_contract.get_percent_divisor(collateral_address) == min_value,
        'Pct Divisor should be updated'
    );
}

#[test]
fn given_valid_caller_and_value_equal_max_it_should_update_the_percent_divisor_value() {
    let (admin_contract, collateral_address, _) = test_setup();
    admin_contract.set_is_active(collateral_address, true);
    let max_value = 200;
    let mut spy = spy_events(SpyOn::One(admin_contract.contract_address));

    admin_contract.set_percent_divisor(collateral_address, max_value);
    // event check
    spy
        .assert_emitted(
            @array![
                (
                    admin_contract.contract_address,
                    AdminContract::Event::PercentDivisorUpdated(
                        AdminContract::PercentDivisorUpdated {
                            collateral: collateral_address,
                            old_percent_divisor: AdminContract::PERCENT_DIVISOR_DEFAULT,
                            percent_divisor: max_value
                        }
                    )
                )
            ]
        );
    assert(spy.events.len() == 0, 'There should be no events');
    assert(
        admin_contract.get_percent_divisor(collateral_address) == max_value,
        'Pct Divisor should be updated'
    );
}

#[test]
fn given_valid_caller_and_value_it_should_update_the_percent_divisor_value() {
    let (admin_contract, collateral_address, _) = test_setup();
    admin_contract.set_is_active(collateral_address, true);
    let new_value = 100;
    let mut spy = spy_events(SpyOn::One(admin_contract.contract_address));

    admin_contract.set_percent_divisor(collateral_address, new_value);
    // event check
    spy
        .assert_emitted(
            @array![
                (
                    admin_contract.contract_address,
                    AdminContract::Event::PercentDivisorUpdated(
                        AdminContract::PercentDivisorUpdated {
                            collateral: collateral_address,
                            old_percent_divisor: AdminContract::PERCENT_DIVISOR_DEFAULT,
                            percent_divisor: new_value
                        }
                    )
                )
            ]
        );
    assert(spy.events.len() == 0, 'There should be no events');
    assert(
        admin_contract.get_percent_divisor(collateral_address) == new_value,
        'Pct Divisor should be updated'
    );
}

#[test]
fn given_setup_is_initialized_and_caller_is_timelock_it_should_correctly_update_the_percent_divisor_value() {
    let (admin_contract, collateral_address, timelock_address) = test_setup();
    admin_contract.set_is_active(collateral_address, true);
    admin_contract.set_setup_initialized();

    let new_value = 100;

    let mut spy = spy_events(SpyOn::One(admin_contract.contract_address));
    start_prank(CheatTarget::One(admin_contract.contract_address), timelock_address);

    admin_contract.set_percent_divisor(collateral_address, new_value);
    // event check
    spy
        .assert_emitted(
            @array![
                (
                    admin_contract.contract_address,
                    AdminContract::Event::PercentDivisorUpdated(
                        AdminContract::PercentDivisorUpdated {
                            collateral: collateral_address,
                            old_percent_divisor: AdminContract::PERCENT_DIVISOR_DEFAULT,
                            percent_divisor: new_value
                        }
                    )
                )
            ]
        );
    assert(spy.events.len() == 0, 'There should be no events');
    assert(
        admin_contract.get_percent_divisor(collateral_address) == new_value,
        'Pct Divisor should be updated'
    );
}

