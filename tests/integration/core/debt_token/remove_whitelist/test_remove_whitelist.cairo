use starknet::{ContractAddress, contract_address_const, get_caller_address};
use shisui::core::{
    debt_token::{IDebtTokenDispatcher, IDebtTokenDispatcherTrait, DebtToken},
    address_provider::{IAddressProviderDispatcher, IAddressProviderDispatcherTrait, AddressesKey},
};
use tests::tests_lib::{deploy_address_provider, deploy_debt_token};
use snforge_std::{
    start_prank, stop_prank, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions, PrintTrait
};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

const MINT_AMOUNT: u256 = 1000;

fn setup() -> (IAddressProviderDispatcher, IDebtTokenDispatcher, ContractAddress, ContractAddress) {
    let address_provider_address: ContractAddress = deploy_address_provider();
    let address_provider: IAddressProviderDispatcher = IAddressProviderDispatcher {
        contract_address: address_provider_address
    };
    let debt_token_address: ContractAddress = deploy_debt_token(address_provider_address);
    let debt_token: IDebtTokenDispatcher = IDebtTokenDispatcher {
        contract_address: debt_token_address
    };
    let caller = contract_address_const::<'caller'>();
    let not_caller = contract_address_const::<'not_caller'>();

    debt_token.add_whitelist(caller);

    start_prank(CheatTarget::One(debt_token.contract_address), caller);

    (address_provider, debt_token, caller, not_caller)
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn when_caller_is_not_owner_it_should_revert() {
    let (_, debt_token, caller, not_caller) = setup();

    start_prank(CheatTarget::One(debt_token.contract_address), not_caller);
    debt_token.remove_whitelist(caller);
    stop_prank(CheatTarget::One(debt_token.contract_address));
}

#[test]
#[should_panic(expected: ('Not whitelisted',))]
fn when_caller_is_owner_removing_address_not_whitelisted_it_should_revert() {
    let (_, debt_token, caller, _) = setup();
    debt_token.remove_whitelist(contract_address_const::<'not_whitelisted'>());
}

#[test]
fn when_caller_is_owner_it_should_remove_whitelist() {
    let (_, debt_token, caller, _) = setup();
    let mut spy = spy_events(SpyOn::One(debt_token.contract_address));

    debt_token.remove_whitelist(caller);

    // event check
    spy
        .assert_emitted(
            @array![
                (
                    debt_token.contract_address,
                    DebtToken::Event::WhitelistChanged(
                        DebtToken::WhitelistChanged { address: caller, is_whitelisted: false }
                    )
                )
            ]
        );

    assert(spy.events.len() == 0, 'There should be no events');

    assert(debt_token.is_whitelisted(caller) == false, 'Address still whitelisted');
}
