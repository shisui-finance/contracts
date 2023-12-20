use starknet::{ContractAddress, contract_address_const};
use snforge_std::{
    start_prank, start_warp, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions, PrintTrait
};
use shisui::core::{
    address_provider::{IAddressProviderDispatcher, IAddressProviderDispatcherTrait, AddressesKey},
    price_feed::{IPriceFeedDispatcher, IPriceFeedDispatcherTrait, PriceFeed}
};
use shisui::utils::math::pow;
use shisui::mocks::pragma_oracle_mock::{
    IPragmaOracleMockDispatcher, IPragmaOracleMockDispatcherTrait
};
use tests::utils::{
    constant::DEFAULT_TIMEOUT, aggregator::update_pragma_response,
    callers::{timelock_address, not_owner_address}
};

use super::super::setup::setup;

fn test_setup() -> (
    IAddressProviderDispatcher,
    IPriceFeedDispatcher,
    IPragmaOracleMockDispatcher,
    ContractAddress,
    felt252
) {
    let token_address = contract_address_const::<'ETH/USD'>();
    let pair_id = 'ETH/USD';
    let (address_provider, price_feed, pragma_mock) = setup();

    update_pragma_response(pragma_mock, pow(10, 18), 18_u32, 0_u64);

    return (address_provider, price_feed, pragma_mock, token_address, pair_id);
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn given_set_new_oracle_caller_is_not_owner_it_should_revert() {
    let (address_provider, price_feed, _, token_address, pair_id) = test_setup();
    start_prank(CheatTarget::One(price_feed.contract_address), not_owner_address());
    price_feed.set_oracle(token_address, pair_id, DEFAULT_TIMEOUT);
}

#[test]
#[should_panic(expected: ('Unknown Pair Id Error',))]
fn given_valid_caller_when_decimals_response_is_zero_it_should_revert() {
    let (address_provider, price_feed, pragma_mock, token_address, pair_id) = test_setup();

    update_pragma_response(pragma_mock, pow(10, 18), 0, 0_u64);
    price_feed.set_oracle(token_address, pair_id, DEFAULT_TIMEOUT);
}

#[test]
#[should_panic(expected: ('Invalid Oracle Response Error',))]
fn given_valid_caller_when_price_response_is_stale_it_should_revert() {
    let (address_provider, price_feed, pragma_mock, token_address, pair_id) = test_setup();
    update_pragma_response(pragma_mock, pow(10, 6), 6_u32, DEFAULT_TIMEOUT * 5);
    start_warp(CheatTarget::One(price_feed.contract_address), DEFAULT_TIMEOUT * 10);

    price_feed.set_oracle(token_address, pair_id, DEFAULT_TIMEOUT);
}

#[test]
#[should_panic(expected: ('Invalid Oracle Response Error',))]
fn given_valid_caller_when_price_response_is_zero_it_should_revert() {
    let (address_provider, price_feed, pragma_mock, token_address, pair_id) = test_setup();
    update_pragma_response(pragma_mock, 0, 6_u32, 0_u64);

    price_feed.set_oracle(token_address, pair_id, DEFAULT_TIMEOUT);
}

#[test]
#[should_panic(expected: ('Invalid Oracle Response Error',))]
fn given_valid_caller_when_price_response_scale_to_target_digits_is_zero_it_should_revert() {
    let (address_provider, price_feed, pragma_mock, token_address, pair_id) = test_setup();
    update_pragma_response(pragma_mock, 1, 20_u32, 0_u64);

    price_feed.set_oracle(token_address, pair_id, DEFAULT_TIMEOUT);
}


#[test]
fn given_caller_is_owner_it_should_set_the_oracle() {
    let (address_provider, price_feed, pragma_mock, token_address, pair_id) = test_setup();

    let mut spy = spy_events(SpyOn::One(price_feed.contract_address));

    price_feed.set_oracle(token_address, pair_id, DEFAULT_TIMEOUT);

    // event check
    spy
        .assert_emitted(
            @array![
                (
                    price_feed.contract_address,
                    PriceFeed::Event::NewOracleRegistered(
                        PriceFeed::NewOracleRegistered {
                            token: token_address, pair_id, timeout_seconds: DEFAULT_TIMEOUT
                        }
                    )
                )
            ]
        );
    assert(spy.events.len() == 0, 'There should be no events');

    let oracle = price_feed.get_oracle(token_address);
    assert(oracle.pair_id == pair_id, 'Wrong pair Id');
    assert(oracle.timeout_seconds == DEFAULT_TIMEOUT, 'Wrong timeout set');
}


#[test]
fn given_caller_is_owner_it_should_update_the_oracle() {
    let (address_provider, price_feed, pragma_mock, token_address, pair_id) = test_setup();

    price_feed.set_oracle(token_address, pair_id, DEFAULT_TIMEOUT);
    let timelock_address = timelock_address();
    address_provider.set_address(AddressesKey::timelock, timelock_address);

    start_prank(CheatTarget::One(price_feed.contract_address), timelock_address);
    let mut spy = spy_events(SpyOn::One(price_feed.contract_address));
    let new_timeout = DEFAULT_TIMEOUT * 2;
    price_feed.set_oracle(token_address, pair_id, new_timeout);
    // event check
    spy
        .assert_emitted(
            @array![
                (
                    price_feed.contract_address,
                    PriceFeed::Event::NewOracleRegistered(
                        PriceFeed::NewOracleRegistered {
                            token: token_address, pair_id, timeout_seconds: new_timeout
                        }
                    )
                )
            ]
        );
    assert(spy.events.len() == 0, 'There should be no events');

    let oracle = price_feed.get_oracle(token_address);
    assert(oracle.pair_id == pair_id, 'Wrong pair Id');
    assert(oracle.timeout_seconds == new_timeout, 'Wrong timeout set');
}

