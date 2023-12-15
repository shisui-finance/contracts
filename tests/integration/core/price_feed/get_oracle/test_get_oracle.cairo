use traits::TryInto;
use starknet::{ContractAddress, contract_address_const};
use snforge_std::{CheatTarget, PrintTrait};
use shisui::core::{
    address_provider::{IAddressProviderDispatcher, IAddressProviderDispatcherTrait},
    price_feed::{IPriceFeedDispatcher, IPriceFeedDispatcherTrait}
};
use shisui::utils::math::pow;
use shisui::mocks::pragma_oracle_mock::{
    IPragmaOracleMockDispatcher, IPragmaOracleMockDispatcherTrait, PricesData
};
use tests::utils::constant::DEFAULT_TIMEOUT;


fn update_pragma_data(
    pragma_mock: IPragmaOracleMockDispatcher, price: u256, decimals: u32, timestamp: u64
) {
    let value = PricesData {
        price: price.try_into().unwrap(), decimals: decimals, last_updated_timestamp: timestamp
    };
    pragma_mock.set_data(value);
}

fn setup() -> (IAddressProviderDispatcher, IPriceFeedDispatcher, IPragmaOracleMockDispatcher) {
    let address_provider_address: ContractAddress = tests::tests_lib::deploy_address_provider();
    let address_provider: IAddressProviderDispatcher = IAddressProviderDispatcher {
        contract_address: address_provider_address
    };
    let pragma_mock_address: ContractAddress = tests::tests_lib::deploy_pragma_oracle_mock();
    let pragma_mock: IPragmaOracleMockDispatcher = IPragmaOracleMockDispatcher {
        contract_address: pragma_mock_address
    };

    let price_feed_address: ContractAddress = tests::tests_lib::deploy_price_feed(
        address_provider_address, pragma_mock_address
    );
    let price_feed: IPriceFeedDispatcher = IPriceFeedDispatcher {
        contract_address: price_feed_address
    };

    update_pragma_data(pragma_mock, pow(10, 6), 6_u32, 0_u64);
    (address_provider, price_feed, pragma_mock)
}

#[test]
fn given_valid_oracle_it_should_return_the_correct_data() {
    let (address_provider, price_feed, pragma_mock) = setup();

    let pair_id: felt252 = 'ETH/USD';
    let token_address = contract_address_const::<'ETH/USD'>();
    price_feed.set_oracle(token_address, pair_id, DEFAULT_TIMEOUT);

    let oracle = price_feed.get_oracle(token_address);
    assert(oracle.pair_id == pair_id, 'Wrong pair Id');
    assert(oracle.timeout_seconds == DEFAULT_TIMEOUT, 'Wrong timeout set');
}

#[test]
fn given_unvalid_oracle_it_should_return_the_default_data() {
    let (address_provider, price_feed, pragma_mock) = setup();
    let token_address = contract_address_const::<'ETH/USD'>();

    let oracle = price_feed.get_oracle(token_address);
    assert(oracle.pair_id == '', 'Wrong pair Id');
    assert(oracle.timeout_seconds == 0, 'Wrong timeout set');
}
