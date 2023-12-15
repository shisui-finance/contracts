use traits::TryInto;
use starknet::{ContractAddress, contract_address_const};
use snforge_std::{
    start_prank, start_warp, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions, PrintTrait
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

    update_pragma_data(pragma_mock, 6 * pow(10, 6), 6_u32, 0_u64);
    (address_provider, price_feed, pragma_mock)
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn given_set_new_oracle_caller_is_not_owner_it_should_revert() {
    let (address_provider, price_feed, _) = setup();
    start_prank(
        CheatTarget::One(price_feed.contract_address), contract_address_const::<'not_owner'>()
    );
    price_feed.set_oracle(contract_address_const::<'ETH/USD'>(), 'ETH/USD', DEFAULT_TIMEOUT);
}

#[test]
#[should_panic(expected: ('Unknown Pair Id Error',))]
fn given_valid_caller_when_decimals_response_is_zero_it_should_revert() {
    let (address_provider, price_feed, pragma_mock) = setup();
    update_pragma_data(pragma_mock, pow(10, 6), 0, 0_u64);
    price_feed.set_oracle(contract_address_const::<'ETH/USD'>(), 'ETH/USD', DEFAULT_TIMEOUT);
}

#[test]
#[should_panic(expected: ('Invalid Oracle Response Error',))]
fn given_valid_caller_when_price_response_is_stale_it_should_revert() {
    let (address_provider, price_feed, pragma_mock) = setup();
    update_pragma_data(pragma_mock, pow(10, 6), 6_u32, DEFAULT_TIMEOUT * 5);
    start_warp(CheatTarget::One(price_feed.contract_address), DEFAULT_TIMEOUT * 10);

    price_feed.set_oracle(contract_address_const::<'ETH/USD'>(), 'ETH/USD', DEFAULT_TIMEOUT);
}

#[test]
#[should_panic(expected: ('Invalid Oracle Response Error',))]
fn given_valid_caller_when_price_response_is_zero_it_should_revert() {
    let (address_provider, price_feed, pragma_mock) = setup();
    update_pragma_data(pragma_mock, 0, 6_u32, 0_u64);

    price_feed.set_oracle(contract_address_const::<'ETH/USD'>(), 'ETH/USD', DEFAULT_TIMEOUT);
}

#[test]
#[should_panic(expected: ('Invalid Oracle Response Error',))]
fn given_valid_caller_when_price_response_scale_to_target_digits_is_zero_it_should_revert() {
    let (address_provider, price_feed, pragma_mock) = setup();
    update_pragma_data(pragma_mock, 1, 20_u32, 0_u64);

    price_feed.set_oracle(contract_address_const::<'ETH/USD'>(), 'ETH/USD', DEFAULT_TIMEOUT);
}


#[test]
fn given_valid_caller_it_should_set_the_new_oracle() {
    let (address_provider, price_feed, pragma_mock) = setup();
    update_pragma_data(pragma_mock, pow(10, 6), 6_u32, 0_u64);

    let pair_id: felt252 = 'ETH/USD';
    let token_address = contract_address_const::<'ETH/USD'>();

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
                            token: token_address, pair_id: pair_id, timeout_seconds: DEFAULT_TIMEOUT
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

