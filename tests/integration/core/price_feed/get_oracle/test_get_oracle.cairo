use starknet::{ContractAddress, contract_address_const};
use shisui::core::{
    address_provider::{IAddressProviderDispatcher, IAddressProviderDispatcherTrait},
    price_feed::{IPriceFeedDispatcher, IPriceFeedDispatcherTrait}
};
use shisui::mocks::pragma_oracle_mock::{
    IPragmaOracleMockDispatcher, IPragmaOracleMockDispatcherTrait
};
use shisui::utils::math::pow;
use tests::utils::{constant::DEFAULT_TIMEOUT, aggregator::update_pragma_response};

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

    price_feed.set_oracle(token_address, pair_id, DEFAULT_TIMEOUT);
    return (address_provider, price_feed, pragma_mock, token_address, pair_id);
}

#[test]
fn given_valid_oracle_it_should_return_the_correct_data() {
    let (address_provider, price_feed, pragma_mock, token_address, pair_id) = test_setup();

    let oracle = price_feed.get_oracle(token_address);
    assert(oracle.pair_id == pair_id, 'Wrong pair Id');
    assert(oracle.timeout_seconds == DEFAULT_TIMEOUT, 'Wrong timeout set');
}

#[test]
fn given_unvalid_oracle_it_should_return_the_default_data() {
    let (address_provider, price_feed, pragma_mock, _, _) = test_setup();
    let token_address = contract_address_const::<'BTC/USD'>();

    let oracle = price_feed.get_oracle(token_address);
    assert(oracle.pair_id == '', 'Wrong pair Id');
    assert(oracle.timeout_seconds == 0, 'Wrong timeout set');
}
