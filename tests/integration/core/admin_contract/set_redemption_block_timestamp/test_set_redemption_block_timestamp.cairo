use starknet::{ContractAddress, contract_address_const};
use snforge_std::{start_prank, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions};
use shisui::core::admin_contract::{
    IAdminContractDispatcher, IAdminContractDispatcherTrait, AdminContract
};
use tests::helpers::constants::TimeValues;
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
    admin_contract.set_redemption_block_timestamp(collateral_address, 0);
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
    admin_contract.set_redemption_block_timestamp(collateral_address, 0);
}

#[test]
#[should_panic(expected: ('Collateral does not exist',))]
fn given_valid_caller_and_collateral_not_exist_it_should_revert() {
    let (admin_contract, _, _) = test_setup();
    let wrong_collateral_address = contract_address_const::<'wrong_collateral'>();

    admin_contract.set_redemption_block_timestamp(wrong_collateral_address, 0);
}

#[test]
fn given_valid_caller_it_should_update_the_redemption_block_timestamp_value() {
    let (admin_contract, collateral_address, _) = test_setup();
    admin_contract.set_is_active(collateral_address, true);
    let value: u64 = TimeValues::SECONDS_IN_ONE_DAY;
    let mut spy = spy_events(SpyOn::One(admin_contract.contract_address));

    admin_contract.set_redemption_block_timestamp(collateral_address, value);
    // event check
    spy
        .assert_emitted(
            @array![
                (
                    admin_contract.contract_address,
                    AdminContract::Event::RedemptionBlockTimestampUpdated(
                        AdminContract::RedemptionBlockTimestampUpdated {
                            collateral: collateral_address,
                            old_redemption_block_timestamp: AdminContract::REDEMPTION_BLOCK_TIMESTAMP_DEFAULT,
                            redemption_block_timestamp: value
                        }
                    )
                )
            ]
        );
    assert(spy.events.len() == 0, 'There should be no events');
    assert(
        admin_contract.get_redemption_block_timestamp(collateral_address) == value,
        'Redemp Time should be updated'
    );
}

#[test]
fn given_setup_is_initialized_and_caller_is_timelock_it_should_correctly_update_the_redemption_block_timestamp_value() {
    let (admin_contract, collateral_address, timelock_address) = test_setup();
    admin_contract.set_is_active(collateral_address, true);
    admin_contract.set_setup_initialized();

    let value: u64 = TimeValues::SECONDS_IN_ONE_DAY;

    let mut spy = spy_events(SpyOn::One(admin_contract.contract_address));
    start_prank(CheatTarget::One(admin_contract.contract_address), timelock_address);

    admin_contract.set_redemption_block_timestamp(collateral_address, value);
    // event check
    spy
        .assert_emitted(
            @array![
                (
                    admin_contract.contract_address,
                    AdminContract::Event::RedemptionBlockTimestampUpdated(
                        AdminContract::RedemptionBlockTimestampUpdated {
                            collateral: collateral_address,
                            old_redemption_block_timestamp: AdminContract::REDEMPTION_BLOCK_TIMESTAMP_DEFAULT,
                            redemption_block_timestamp: value
                        }
                    )
                )
            ]
        );
    assert(spy.events.len() == 0, 'There should be no events');
    assert(
        admin_contract.get_redemption_block_timestamp(collateral_address) == value,
        'Redemp Time should be updated'
    );
}

