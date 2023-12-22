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

fn setup() -> (IAddressProviderDispatcher, IDebtTokenDispatcher, ContractAddress) {
    let address_provider_address: ContractAddress = deploy_address_provider();
    let address_provider: IAddressProviderDispatcher = IAddressProviderDispatcher {
        contract_address: address_provider_address
    };
    let debt_token_address: ContractAddress = deploy_debt_token(address_provider_address);
    let debt_token: IDebtTokenDispatcher = IDebtTokenDispatcher {
        contract_address: debt_token_address
    };
    let caller = contract_address_const::<'caller'>();

    address_provider
        .set_address(
            AddressesKey::borrower_operations, contract_address_const::<'borrower_operations'>()
        );

    (address_provider, debt_token, caller)
}

#[test]
#[should_panic(expected: ('Caller is not authorized',))]
fn given_caller_is_not_borrower_operations_it_should_revert() {
    let (_, debt_token, caller) = setup();
    debt_token.burn(caller, MINT_AMOUNT);
}

#[test]
fn given_caller_is_borrower_operations_it_should_mint() {
    let (_, debt_token, caller) = setup();
    start_prank(
        CheatTarget::One(debt_token.contract_address),
        contract_address_const::<'borrower_operations'>()
    );
    debt_token.mint(caller, MINT_AMOUNT);
    stop_prank(CheatTarget::One(debt_token.contract_address));

    let debt_token: IERC20Dispatcher = IERC20Dispatcher {
        contract_address: debt_token.contract_address
    };

    assert(debt_token.balance_of(caller) == MINT_AMOUNT, 'Wrong balance');
}
