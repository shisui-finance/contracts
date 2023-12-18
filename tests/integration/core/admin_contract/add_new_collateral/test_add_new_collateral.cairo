use starknet::{ContractAddress, contract_address_const};
use snforge_std::{start_prank, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions};
use shisui::core::admin_contract::{
    IAdminContractDispatcher, IAdminContractDispatcherTrait, AdminContract
};
use super::super::setup::setup;

const valid_decimals: u8 = 18;
const debt_token_gas_compensation: u256 = 1000;

#[test]
#[should_panic(expected: ('Caller is not Owner',))]
fn given_setup_not_initialized_and_caller_is_not_owner_it_should_revert() {
    let (admin_contract, _) = setup();

    start_prank(
        CheatTarget::One(admin_contract.contract_address), contract_address_const::<'not_owner'>()
    );
    admin_contract
        .add_new_collateral(
            contract_address_const::<'collateral'>(), debt_token_gas_compensation, valid_decimals
        );
}

#[test]
#[should_panic(expected: ('Caller not Timelock',))]
fn given_setup_is_initialized_and_caller_is_not_timelock_it_should_revert() {
    let (admin_contract, _) = setup();
    admin_contract.set_setup_initialized();

    start_prank(
        CheatTarget::One(admin_contract.contract_address),
        contract_address_const::<'not_timelock'>()
    );
    admin_contract
        .add_new_collateral(
            contract_address_const::<'collateral'>(), debt_token_gas_compensation, valid_decimals
        );
}

#[test]
#[should_panic(expected: ('Collateral decimals not default',))]
fn given_caller_valid_and_decimals_not_valid_it_should_revert() {
    let (admin_contract, _) = setup();
    let wrong_decimals = 8;
    admin_contract
        .add_new_collateral(
            contract_address_const::<'collateral'>(), debt_token_gas_compensation, wrong_decimals
        );
}

#[test]
#[should_panic(expected: ('Collateral already exist',))]
fn given_caller_valid_and_collateral_already_exist_it_should_revert() {
    let (admin_contract, _) = setup();
    admin_contract
        .add_new_collateral(
            contract_address_const::<'collateral'>(), debt_token_gas_compensation, valid_decimals
        );
    admin_contract
        .add_new_collateral(
            contract_address_const::<'collateral'>(), debt_token_gas_compensation, valid_decimals
        );
}

#[test]
fn given_setup_not_initialized_and_caller_is_owner_it_should_correctly_add_the_collateral() {
    let (admin_contract, _) = setup();
    let collateral_address = contract_address_const::<'collateral'>();
    let mut spy = spy_events(SpyOn::One(admin_contract.contract_address));
    admin_contract
        .add_new_collateral(collateral_address, debt_token_gas_compensation, valid_decimals);
    // event check
    spy
        .assert_emitted(
            @array![
                (
                    admin_contract.contract_address,
                    AdminContract::Event::CollateralAdded(
                        AdminContract::CollateralAdded { collateral: collateral_address }
                    )
                )
            ]
        );
    assert(spy.events.len() == 0, 'There should be no events');
    assert(admin_contract.get_index(collateral_address) == 0, 'index should be 0');
    assert(admin_contract.get_is_active(collateral_address) == false, 'is_active should be false');
    assert(
        admin_contract.get_ccr(collateral_address) == AdminContract::CCR_DEFAULT,
        'CCR should be default'
    );
    assert(
        admin_contract.get_mcr(collateral_address) == AdminContract::MCR_DEFAULT,
        'MCR should be default'
    );
    assert(
        admin_contract
            .get_borrowing_fee(collateral_address) == AdminContract::BORROWING_FEE_DEFAULT,
        'Borrowing Fee should be default'
    );
    assert(
        admin_contract.get_min_net_debt(collateral_address) == AdminContract::MIN_NET_DEBT_DEFAULT,
        'Min Net Debt should be default'
    );
    assert(
        admin_contract.get_mint_cap(collateral_address) == AdminContract::MINT_CAP_DEFAULT,
        'Mint Cap should be default'
    );
    assert(
        admin_contract
            .get_percent_divisor(collateral_address) == AdminContract::PERCENT_DIVISOR_DEFAULT,
        'Pct Divisor should be default'
    );
    assert(
        admin_contract
            .get_redemption_fee_floor(
                collateral_address
            ) == AdminContract::REDEMPTION_FEE_FLOOR_DEFAULT,
        'Redemp Fee should be default'
    );
    assert(
        admin_contract
            .get_redemption_block_timestamp(
                collateral_address
            ) == AdminContract::REDEMPTION_BLOCK_TIMESTAMP_DEFAULT,
        'Redemp Time should be default'
    );
    assert(
        admin_contract
            .get_debt_token_gas_compensation(collateral_address) == debt_token_gas_compensation,
        'Gas Compensation should be 1000'
    );
    let indices = admin_contract.get_indices(array![collateral_address].span());
    assert(indices.len() == 1, 'indices length should be 1');
    assert(*indices[0] == 0_usize, 'index should be 0');
}

#[test]
fn given_setup_is_initialized_and_caller_is_timelock_it_should_correctly_add_the_collateral() {
    let (admin_contract, timelock_address) = setup();
    let collateral_address = contract_address_const::<'collateral'>();
    admin_contract.set_setup_initialized();
    start_prank(CheatTarget::One(admin_contract.contract_address), timelock_address);
    let mut spy = spy_events(SpyOn::One(admin_contract.contract_address));
    admin_contract
        .add_new_collateral(collateral_address, debt_token_gas_compensation, valid_decimals);
    // event check
    spy
        .assert_emitted(
            @array![
                (
                    admin_contract.contract_address,
                    AdminContract::Event::CollateralAdded(
                        AdminContract::CollateralAdded { collateral: collateral_address }
                    )
                )
            ]
        );
    assert(spy.events.len() == 0, 'There should be no events');
    assert(admin_contract.get_index(collateral_address) == 0, 'index should be 0');
    assert(admin_contract.get_is_active(collateral_address) == false, 'is_active should be false');
    assert(
        admin_contract.get_ccr(collateral_address) == AdminContract::CCR_DEFAULT,
        'CCR should be default'
    );
    assert(
        admin_contract.get_mcr(collateral_address) == AdminContract::MCR_DEFAULT,
        'MCR should be default'
    );
    assert(
        admin_contract
            .get_borrowing_fee(collateral_address) == AdminContract::BORROWING_FEE_DEFAULT,
        'Borrowing Fee should be default'
    );
    assert(
        admin_contract.get_min_net_debt(collateral_address) == AdminContract::MIN_NET_DEBT_DEFAULT,
        'Min Net Debt should be default'
    );
    assert(
        admin_contract.get_mint_cap(collateral_address) == AdminContract::MINT_CAP_DEFAULT,
        'Mint Cap should be default'
    );
    assert(
        admin_contract
            .get_percent_divisor(collateral_address) == AdminContract::PERCENT_DIVISOR_DEFAULT,
        'Pct Divisor should be default'
    );
    assert(
        admin_contract
            .get_redemption_fee_floor(
                collateral_address
            ) == AdminContract::REDEMPTION_FEE_FLOOR_DEFAULT,
        'Redemp Fee should be default'
    );
    assert(
        admin_contract
            .get_redemption_block_timestamp(
                collateral_address
            ) == AdminContract::REDEMPTION_BLOCK_TIMESTAMP_DEFAULT,
        'Redemp Time should be default'
    );
    assert(
        admin_contract
            .get_debt_token_gas_compensation(collateral_address) == debt_token_gas_compensation,
        'Gas Compensation should be 1000'
    );
    let indices = admin_contract.get_indices(array![collateral_address].span());
    assert(indices.len() == 1, 'indices length should be 1');
    assert(*indices[0] == 0_usize, 'index should be 0');
}

#[test]
fn given_caller_is_valid_it_should_correctly_add_multi_collateral() {
    let (admin_contract, _) = setup();
    let collateral_1_addresss = contract_address_const::<'collateral_1'>();
    let collateral_2_addresss = contract_address_const::<'collateral_2'>();
    admin_contract
        .add_new_collateral(collateral_1_addresss, debt_token_gas_compensation, valid_decimals);
    admin_contract
        .add_new_collateral(collateral_2_addresss, debt_token_gas_compensation, valid_decimals);

    assert(admin_contract.get_index(collateral_1_addresss) == 0, 'index should be 0');
    assert(admin_contract.get_index(collateral_2_addresss) == 1, 'index should be 0');

    let indices = admin_contract
        .get_indices(array![collateral_1_addresss, collateral_2_addresss].span());
    assert(indices.len() == 2, 'indices length should be 1');
    assert(*indices[0] == 0, 'index should be 0');
    assert(*indices[1] == 1, 'index should be 1');
    let supported_collateral = admin_contract.get_supported_collateral();
    assert(supported_collateral.len() == 2, 'sup coll length should be 2');
    assert(*supported_collateral[0] == collateral_1_addresss, 'sup coll should be collateral_1');
    assert(*supported_collateral[1] == collateral_2_addresss, 'sup coll should be collateral_2');
}

