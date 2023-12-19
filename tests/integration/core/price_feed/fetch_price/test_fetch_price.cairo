use starknet::{ContractAddress, contract_address_const};
use snforge_std::{start_warp, CheatTarget};
use shisui::core::{
    address_provider::{IAddressProviderDispatcher, IAddressProviderDispatcherTrait},
    price_feed::{IPriceFeedDispatcher, IPriceFeedDispatcherTrait}
};
use shisui::utils::math::pow;
use shisui::mocks::pragma_oracle_mock::{
    IPragmaOracleMockDispatcher, IPragmaOracleMockDispatcherTrait
};
use tests::utils::{constant::DEFAULT_TIMEOUT, aggregator::update_pragma_response};

use super::super::setup::setup;

fn test_setup() -> (
    IAddressProviderDispatcher, IPriceFeedDispatcher, IPragmaOracleMockDispatcher, ContractAddress
) {
    let token_address = contract_address_const::<'ETH/USD'>();
    let (address_provider, price_feed, pragma_mock) = setup();

    update_pragma_response(pragma_mock, pow(10, 18), 18_u32, 0_u64);

    price_feed.set_oracle(token_address, 'ETH/USD', DEFAULT_TIMEOUT);
    return (address_provider, price_feed, pragma_mock, token_address);
}

#[test]
#[should_panic(expected: ('Unknown Asset Error',))]
fn given_oracle_not_set_it_should_revert() {
    let (address_provider, price_feed, _, _) = test_setup();
    price_feed.fetch_price(contract_address_const::<'BTC/USD'>());
}

#[test]
#[should_panic(expected: ('Invalid Oracle Response Error',))]
fn given_price_response_is_zero_it_should_revert() {
    let (address_provider, price_feed, pragma_mock, token_address) = test_setup();
    update_pragma_response(pragma_mock, 0, 6_u32, 0_u64);
    price_feed.fetch_price(token_address);
}

#[test]
#[should_panic(expected: ('Invalid Oracle Response Error',))]
fn given_price_response_is_stale_it_should_revert() {
    let (address_provider, price_feed, pragma_mock, token_address) = test_setup();
    update_pragma_response(pragma_mock, pow(10, 6), 6_u32, DEFAULT_TIMEOUT * 5);
    start_warp(CheatTarget::One(price_feed.contract_address), DEFAULT_TIMEOUT * 10);
    price_feed.fetch_price(token_address);
}

#[test]
#[should_panic(expected: ('Invalid Oracle Response Error',))]
fn given_price_response_scale_to_target_digits_is_zero_it_should_revert() {
    let (address_provider, price_feed, pragma_mock, token_address) = test_setup();
    update_pragma_response(pragma_mock, 1, 20_u32, 0_u64);
    price_feed.fetch_price(token_address);
}


#[test]
fn given_oracle_decimals_less_than_target_decimals_it_should_scale_it() {
    let (address_provider, price_feed, pragma_mock, token_address) = test_setup();
    update_pragma_response(pragma_mock, 6 * pow(10, 6), 6_u32, 0_u64);

    let price = price_feed.fetch_price(token_address);

    assert(price == 6 * pow(10, 18), 'Wrong scale');
}

#[test]
fn given_oracle_decimals_greater_than_target_decimals_it_should_scale_it() {
    let (address_provider, price_feed, pragma_mock, token_address) = test_setup();
    update_pragma_response(pragma_mock, 6 * pow(10, 27), 27_u32, 0_u64);

    let price = price_feed.fetch_price(token_address);

    assert(price == 6 * pow(10, 18), 'Wrong scale');
}

#[test]
fn given_oracle_decimals_is_target_decimals_it_should_return_price() {
    let (address_provider, price_feed, pragma_mock, token_address) = test_setup();
    update_pragma_response(pragma_mock, 6 * pow(10, 18), 18_u32, 0_u64);
    let price = price_feed.fetch_price(token_address);

    assert(price == 6 * pow(10, 18), 'Wrong scale');
}

