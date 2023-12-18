use starknet::{ContractAddress, contract_address_const};
use snforge_std::{start_prank, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions};
use shisui::core::{
    address_provider::{IAddressProviderDispatcher, IAddressProviderDispatcherTrait, AddressesKey},
    admin_contract::{IAdminContractDispatcher, IAdminContractDispatcherTrait, AdminContract}
};
use shisui::utils::math::pow;
use super::super::setup::setup;

const valid_decimals: u8 = 18;
const debt_token_gas_compensation: u256 = 1000;

fn test_setup() -> (
    IAddressProviderDispatcher, IAdminContractDispatcher, ContractAddress, ContractAddress
) {
    let (address_provider, admin_contract, timelock_address) = setup();
    let collateral_address = contract_address_const::<'collateral'>();
    admin_contract
        .add_new_collateral(collateral_address, debt_token_gas_compensation, valid_decimals);

    (address_provider, admin_contract, collateral_address, timelock_address)
}

#[test]
#[should_panic(expected: ('Caller is not Owner',))]
fn given_setup_not_initialized_and_caller_is_not_owner_it_should_revert() {
    let (address_provider, admin_contract, collateral_address, _) = test_setup();
    start_prank(
        CheatTarget::One(admin_contract.contract_address), contract_address_const::<'not_owner'>()
    );
    admin_contract.set_borrowing_fee(collateral_address, 0);
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
    admin_contract.set_borrowing_fee(collateral_address, 0);
}

#[test]
#[should_panic(expected: ('Collateral not active',))]
fn given_valid_caller_and_collateral_not_active_it_should_revert() {
    let (address_provider, admin_contract, collateral_address, _) = test_setup();

    admin_contract.set_borrowing_fee(collateral_address, 0);
}

#[test]
#[should_panic(expected: ('Value out of range',))]
fn given_valid_caller_and_value_exceed_max_value_it_should_revert() {
    let (address_provider, admin_contract, collateral_address, _) = test_setup();
    admin_contract.set_is_active(collateral_address, true);
    admin_contract.set_borrowing_fee(collateral_address, pow(10, 17) + 1);
}


#[test]
fn given_valid_caller_and_value_equal_min_it_should_update_the_borring_fee_value() {
    let (address_provider, admin_contract, collateral_address, _) = test_setup();
    admin_contract.set_is_active(collateral_address, true);
    let min_value = 0;
    let mut spy = spy_events(SpyOn::One(admin_contract.contract_address));

    admin_contract.set_borrowing_fee(collateral_address, min_value);
    // event check
    spy
        .assert_emitted(
            @array![
                (
                    admin_contract.contract_address,
                    AdminContract::Event::BorrowingFeeUpdated(
                        AdminContract::BorrowingFeeUpdated {
                            collateral: collateral_address,
                            old_borrowing_fee: AdminContract::BORROWING_FEE_DEFAULT,
                            borrowing_fee: min_value
                        }
                    )
                )
            ]
        );
    assert(spy.events.len() == 0, 'There should be no events');
    assert(
        admin_contract.get_borrowing_fee(collateral_address) == min_value,
        'Borrowing fee should be updated'
    );
}

#[test]
fn given_valid_caller_and_value_equal_max_it_should_update_the_borring_fee_value() {
    let (address_provider, admin_contract, collateral_address, _) = test_setup();
    admin_contract.set_is_active(collateral_address, true);
    let max_value = AdminContract::_100_pct / 10;
    let mut spy = spy_events(SpyOn::One(admin_contract.contract_address));

    admin_contract.set_borrowing_fee(collateral_address, max_value);
    // event check
    spy
        .assert_emitted(
            @array![
                (
                    admin_contract.contract_address,
                    AdminContract::Event::BorrowingFeeUpdated(
                        AdminContract::BorrowingFeeUpdated {
                            collateral: collateral_address,
                            old_borrowing_fee: AdminContract::BORROWING_FEE_DEFAULT,
                            borrowing_fee: max_value
                        }
                    )
                )
            ]
        );
    assert(spy.events.len() == 0, 'There should be no events');
    assert(
        admin_contract.get_borrowing_fee(collateral_address) == max_value,
        'Borrowing fee should be updated'
    );
}

#[test]
fn given_valid_caller_and_value_it_should_update_the_borring_fee_value() {
    let (address_provider, admin_contract, collateral_address, _) = test_setup();
    admin_contract.set_is_active(collateral_address, true);
    let new_value = pow(10, 16);
    let mut spy = spy_events(SpyOn::One(admin_contract.contract_address));

    admin_contract.set_borrowing_fee(collateral_address, new_value);
    // event check
    spy
        .assert_emitted(
            @array![
                (
                    admin_contract.contract_address,
                    AdminContract::Event::BorrowingFeeUpdated(
                        AdminContract::BorrowingFeeUpdated {
                            collateral: collateral_address,
                            old_borrowing_fee: AdminContract::BORROWING_FEE_DEFAULT,
                            borrowing_fee: new_value
                        }
                    )
                )
            ]
        );
    assert(spy.events.len() == 0, 'There should be no events');
    assert(
        admin_contract.get_borrowing_fee(collateral_address) == new_value,
        'Borrowing fee should be updated'
    );
}

