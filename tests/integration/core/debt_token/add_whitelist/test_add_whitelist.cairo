use starknet::{ContractAddress, contract_address_const};
use shisui::core::{
    debt_token::{IDebtToken, IDebtTokenDispatcher, IDebtTokenDispatcherTrait, DebtToken},
    address_provider::{IAddressProviderDispatcher, IAddressProviderDispatcherTrait, AddressesKey},
};
use tests::tests_lib::{deploy_address_provider, deploy_debt_token};
use snforge_std::{start_prank, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions};

fn setup() -> (IAddressProviderDispatcher, IDebtTokenDispatcher) {
    let address_provider_address: ContractAddress = deploy_address_provider();
    let address_provider: IAddressProviderDispatcher = IAddressProviderDispatcher {
        contract_address: address_provider_address
    };

    let debt_token_address: ContractAddress = deploy_debt_token(address_provider_address);
    let debt_token: IDebtTokenDispatcher = IDebtTokenDispatcher {
        contract_address: debt_token_address
    };

    (address_provider, debt_token)
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn given_caller_is_not_owner_on_add_whitelist_it_should_revert() {
    let (_, debt_token) = setup();
    start_prank(
        CheatTarget::One(debt_token.contract_address), contract_address_const::<'not_owner'>()
    );
    debt_token.add_whitelist(contract_address_const::<'fee_collector'>());
}

#[test]
#[should_panic(expected: ('Address is zero',))]
fn given_caller_is_owner_whitelisting_new_address_zero_it_should_revert() {
    let (_, debt_token) = setup();
    debt_token.add_whitelist(contract_address_const::<0x00>());
}

#[test]
fn given_caller_is_owner_it_should_add_whitelist() {
    let (_, debt_token) = setup();
    let mut spy = spy_events(SpyOn::One(debt_token.contract_address));

    debt_token.add_whitelist(contract_address_const::<'fee_collector'>());

    // event check
    spy
        .assert_emitted(
            @array![
                (
                    debt_token.contract_address,
                    DebtToken::Event::WhitelistChanged(
                        DebtToken::WhitelistChanged {
                            address: contract_address_const::<'fee_collector'>(),
                            is_whitelisted: true
                        }
                    )
                )
            ]
        );

    assert(spy.events.len() == 0, 'There should be no events');
    assert(
        debt_token.is_whitelisted(contract_address_const::<'fee_collector'>()),
        'Address should be whitelisted'
    );
}
