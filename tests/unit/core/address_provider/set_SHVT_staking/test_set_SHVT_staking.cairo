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
// It calls address_provider.set_shvt_staking()
// The test expects the call to revert
#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn given_caller_is_not_owner_it_should_revert() {
    let (address_provider, address_provider_address) = setup();

    start_prank(
        CheatTarget::One(address_provider_address), contract_address_const::<'not_owner'>()
    );

    address_provider.set_shvt_staking(contract_address_const::<0x1>());
}


// This tests check that no address zero is allowed
// It calls address_provider.set_shvt_staking()
// The test expects the call to revert
#[test]
#[should_panic(expected: ('Address is zero',))]
fn given_caller_is_owner_and_at_least_one_address_is_zero_it_should_revert() {
    let (address_provider, address_provider_address) = setup();
    address_provider.set_shvt_staking(contract_address_const::<0x0>());
}

// This tests check that contract owner can set addresses
// It calls address_provider.set_shvt_staking()
#[test]
fn given_caller_is_owner_it_should_set_shvt_staking() {
    let (address_provider, address_provider_address) = setup();
    let shvt_staking: ContractAddress = contract_address_const::<0x1>();
    address_provider.set_shvt_staking(shvt_staking);
    assert(address_provider.get_shvt_staking() == shvt_staking, 'SHVT staking not correct');
}
