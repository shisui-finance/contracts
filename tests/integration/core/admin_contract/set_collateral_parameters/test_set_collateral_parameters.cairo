use starknet::{ContractAddress, contract_address_const};
use snforge_std::{start_prank, CheatTarget};
use shisui::core::{
    address_provider::{IAddressProviderDispatcher, IAddressProviderDispatcherTrait},
    admin_contract::{IAdminContractDispatcher, IAdminContractDispatcherTrait}
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
    admin_contract.set_collateral_parameters(collateral_address, 0, 0, 0, 0, 0, 0, 0);
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
    admin_contract.set_collateral_parameters(collateral_address, 0, 0, 0, 0, 0, 0, 0);
}

#[test]
#[should_panic(expected: ('Collateral does not exist',))]
fn given_valid_caller_and_collateral_not_exist_it_should_revert() {
    let (address_provider, admin_contract, _, _) = test_setup();
    let wrong_collateral_address = contract_address_const::<'wrong_collateral'>();
    admin_contract.set_collateral_parameters(wrong_collateral_address, 0, 0, 0, 0, 0, 0, 0);
}

#[test]
#[should_panic]
fn given_valid_caller_and_at_least_one_value_out_of_range_it_should_revert() {
    let (address_provider, admin_contract, collateral_address, _) = test_setup();

    admin_contract.set_collateral_parameters(collateral_address, 0, 0, 0, 0, 0, 0, 0);
}

#[test]
fn given_valid_caller_it_should_update_the_collateral_params() {
    let (address_provider, admin_contract, collateral_address, _) = test_setup();
    let new_borrowing_fee = pow(10, 16);
    let new_ccr = 8 * pow(10, 18);
    let new_mcr = 8 * pow(10, 18);
    let new_min_net_debt = 1000 * pow(10, 18);
    let new_mint_cap = pow(10, 20);
    let new_percent_divisor = 100;
    let new_redemption_fee_floor = pow(10, 16);
    admin_contract
        .set_collateral_parameters(
            collateral_address,
            new_borrowing_fee,
            new_ccr,
            new_mcr,
            new_min_net_debt,
            new_mint_cap,
            new_percent_divisor,
            new_redemption_fee_floor
        );
    assert(admin_contract.get_is_active(collateral_address) == true, 'Is active should be True');
    let collateral_params = admin_contract.get_collaterals_params(collateral_address);
    assert(collateral_params.borrowing_fee == new_borrowing_fee, 'Borrowing fee should be updated');
    assert(collateral_params.ccr == new_ccr, 'CCR should be updated');
    assert(collateral_params.mcr == new_mcr, 'MCR should be updated');
    assert(collateral_params.min_net_debt == new_min_net_debt, 'Min net debt should be updated');
    assert(collateral_params.mint_cap == new_mint_cap, 'Mint cap should be updated');
    assert(
        collateral_params.percent_divisor == new_percent_divisor, 'Pct divisor should be updated'
    );
    assert(
        collateral_params.redemption_fee_floor == new_redemption_fee_floor,
        'Redemp fee should be updated'
    );
}
