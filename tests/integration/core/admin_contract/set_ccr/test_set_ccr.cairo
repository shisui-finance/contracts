use starknet::{ContractAddress, contract_address_const};
use snforge_std::{start_prank, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions};
use shisui::core::admin_contract::{
    IAdminContractDispatcher, IAdminContractDispatcherTrait, AdminContract
};
use shisui::utils::math::pow;
use super::super::setup::setup;

const valid_decimals: u8 = 18;
const debt_token_gas_compensation: u256 = 1000;

fn test_setup() -> (IAdminContractDispatcher, ContractAddress, ContractAddress) {
    let (admin_contract, timelock_address) = setup();
    let collateral_address = contract_address_const::<'collateral'>();
    admin_contract
        .add_new_collateral(collateral_address, debt_token_gas_compensation, valid_decimals);

    (admin_contract, collateral_address, timelock_address)
}

#[test]
#[should_panic(expected: ('Caller is not Owner',))]
fn given_setup_not_initialized_and_caller_is_not_owner_it_should_revert() {
    let (admin_contract, collateral_address, _) = test_setup();
    start_prank(
        CheatTarget::One(admin_contract.contract_address), contract_address_const::<'not_owner'>()
    );
    admin_contract.set_ccr(collateral_address, 0);
}

#[test]
#[should_panic(expected: ('Caller not Timelock',))]
fn given_setup_is_initialized_and_caller_is_not_timelock_it_should_revert() {
    let (admin_contract, collateral_address, _) = test_setup();
    admin_contract.set_setup_initialized();
    start_prank(
        CheatTarget::One(admin_contract.contract_address),
        contract_address_const::<'not_timelock'>()
    );
    admin_contract.set_ccr(collateral_address, 0);
}

#[test]
#[should_panic(expected: ('Collateral not active',))]
fn given_valid_caller_and_collateral_not_active_it_should_revert() {
    let (admin_contract, collateral_address, _) = test_setup();

    admin_contract.set_ccr(collateral_address, 0);
}

#[test]
#[should_panic(expected: ('Value out of range',))]
fn given_valid_caller_and_value_exceed_max_value_it_should_revert() {
    let (admin_contract, collateral_address, _) = test_setup();
    admin_contract.set_is_active(collateral_address, true);
    admin_contract.set_ccr(collateral_address, AdminContract::CCR_DEFAULT * 10 + 1);
}


#[test]
fn given_valid_caller_and_value_equal_min_it_should_update_the_ccr_value() {
    let (admin_contract, collateral_address, _) = test_setup();
    admin_contract.set_is_active(collateral_address, true);
    let min_value = AdminContract::ONE_HUNDRED_PCT;
    let mut spy = spy_events(SpyOn::One(admin_contract.contract_address));

    admin_contract.set_ccr(collateral_address, min_value);
    // event check
    spy
        .assert_emitted(
            @array![
                (
                    admin_contract.contract_address,
                    AdminContract::Event::CCRUpdated(
                        AdminContract::CCRUpdated {
                            collateral: collateral_address,
                            old_ccr: AdminContract::CCR_DEFAULT,
                            ccr: min_value
                        }
                    )
                )
            ]
        );
    assert(spy.events.len() == 0, 'There should be no events');
    assert(admin_contract.get_ccr(collateral_address) == min_value, 'CCR should be updated');
}

#[test]
fn given_valid_caller_and_value_equal_max_it_should_update_the_ccr_value() {
    let (admin_contract, collateral_address, _) = test_setup();
    admin_contract.set_is_active(collateral_address, true);
    let max_value = AdminContract::ONE_HUNDRED_PCT * 10;
    let mut spy = spy_events(SpyOn::One(admin_contract.contract_address));

    admin_contract.set_ccr(collateral_address, max_value);
    // event check
    spy
        .assert_emitted(
            @array![
                (
                    admin_contract.contract_address,
                    AdminContract::Event::CCRUpdated(
                        AdminContract::CCRUpdated {
                            collateral: collateral_address,
                            old_ccr: AdminContract::CCR_DEFAULT,
                            ccr: max_value
                        }
                    )
                )
            ]
        );
    assert(spy.events.len() == 0, 'There should be no events');
    assert(admin_contract.get_ccr(collateral_address) == max_value, 'CCR should be updated');
}

#[test]
fn given_valid_caller_and_value_it_should_update_the_ccr_value() {
    let (admin_contract, collateral_address, _) = test_setup();
    admin_contract.set_is_active(collateral_address, true);
    let new_value = 8 * pow(10, 18);
    let mut spy = spy_events(SpyOn::One(admin_contract.contract_address));

    admin_contract.set_ccr(collateral_address, new_value);
    // event check
    spy
        .assert_emitted(
            @array![
                (
                    admin_contract.contract_address,
                    AdminContract::Event::CCRUpdated(
                        AdminContract::CCRUpdated {
                            collateral: collateral_address,
                            old_ccr: AdminContract::CCR_DEFAULT,
                            ccr: new_value
                        }
                    )
                )
            ]
        );
    assert(spy.events.len() == 0, 'There should be no events');
    assert(admin_contract.get_ccr(collateral_address) == new_value, 'CCR should be updated');
}

#[test]
fn given_setup_is_initialized_and_caller_is_timelock_it_should_correctly_update_the_ccr_value() {
    let (admin_contract, collateral_address, timelock_address) = test_setup();
    admin_contract.set_is_active(collateral_address, true);
    admin_contract.set_setup_initialized();

    let new_value = 8 * pow(10, 18);
    let mut spy = spy_events(SpyOn::One(admin_contract.contract_address));

    start_prank(CheatTarget::One(admin_contract.contract_address), timelock_address);
    admin_contract.set_ccr(collateral_address, new_value);
    // event check
    spy
        .assert_emitted(
            @array![
                (
                    admin_contract.contract_address,
                    AdminContract::Event::CCRUpdated(
                        AdminContract::CCRUpdated {
                            collateral: collateral_address,
                            old_ccr: AdminContract::CCR_DEFAULT,
                            ccr: new_value
                        }
                    )
                )
            ]
        );
    assert(spy.events.len() == 0, 'There should be no events');
    assert(admin_contract.get_ccr(collateral_address) == new_value, 'CCR should be updated');
}

