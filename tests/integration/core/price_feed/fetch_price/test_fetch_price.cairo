use traits::TryInto;
use starknet::{ContractAddress, contract_address_const};
use snforge_std::{
    start_warp, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions, PrintTrait
};
use shisui::core::{
    address_provider::{IAddressProviderDispatcher, IAddressProviderDispatcherTrait},
    price_feed::{PriceFeed, IPriceFeedDispatcher, IPriceFeedDispatcherTrait}
};
use shisui::utils::math::pow;
use shisui::mocks::pragma_oracle_mock::{
    IPragmaOracleMockDispatcher, IPragmaOracleMockDispatcherTrait, PricesData
};
use tests::utils::constant::DEFAULT_TIMEOUT;

fn update_pragma_response(
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

    update_pragma_response(pragma_mock, 6 * pow(10, 6), 6_u32, 0_u64);
    price_feed.set_oracle(contract_address_const::<'ETH/USD'>(), 'ETH/USD', DEFAULT_TIMEOUT);
    (address_provider, price_feed, pragma_mock)
}

#[test]
#[should_panic(expected: ('Unknown Asset Error',))]
fn given_oracle_not_set_it_should_revert() {
    let (address_provider, price_feed, _) = setup();
    price_feed.fetch_price(contract_address_const::<'BTC/USD'>());
}

#[test]
#[should_panic(expected: ('Invalid Oracle Response Error',))]
fn given_price_response_is_zero_it_should_revert() {
    let (address_provider, price_feed, pragma_mock) = setup();
    update_pragma_response(pragma_mock, 0, 6_u32, 0_u64);
    price_feed.fetch_price(contract_address_const::<'ETH/USD'>());
}

#[test]
#[should_panic(expected: ('Invalid Oracle Response Error',))]
fn given_price_response_is_stale_it_should_revert() {
    let (address_provider, price_feed, pragma_mock) = setup();
    update_pragma_response(pragma_mock, pow(10, 6), 6_u32, DEFAULT_TIMEOUT * 5);
    start_warp(CheatTarget::One(price_feed.contract_address), DEFAULT_TIMEOUT * 10);
    price_feed.fetch_price(contract_address_const::<'ETH/USD'>());
}

#[test]
#[should_panic(expected: ('Invalid Oracle Response Error',))]
fn given_price_response_scale_to_target_digits_is_zero_it_should_revert() {
    let (address_provider, price_feed, pragma_mock) = setup();
    update_pragma_response(pragma_mock, 1, 20_u32, 0_u64);
    price_feed.fetch_price(contract_address_const::<'ETH/USD'>());
}


#[test]
fn given_oracle_decimals_less_than_target_decimals_it_should_scale_it() {
    let (address_provider, price_feed, pragma_mock) = setup();
    update_pragma_response(pragma_mock, pow(10, 6), 6_u32, 0_u64);

    let price = price_feed.fetch_price(contract_address_const::<'ETH/USD'>());

    assert(price == pow(10, 18), 'Wrong scale');
}

#[test]
fn given_oracle_decimals_greater_than_target_decimals_it_should_scale_it() {
    let (address_provider, price_feed, pragma_mock) = setup();
    update_pragma_response(pragma_mock, pow(10, 27), 27_u32, 0_u64);

    let price = price_feed.fetch_price(contract_address_const::<'ETH/USD'>());

    assert(price == pow(10, 18), 'Wrong scale');
}

