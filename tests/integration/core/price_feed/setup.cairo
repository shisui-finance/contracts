use starknet::{ContractAddress, contract_address_const};
use shisui::core::{
    address_provider::{IAddressProviderDispatcher, IAddressProviderDispatcherTrait},
    price_feed::{PriceFeed, IPriceFeedDispatcher, IPriceFeedDispatcherTrait}
};
use shisui::utils::math::pow;
use shisui::mocks::pragma_oracle_mock::{
    IPragmaOracleMockDispatcher, IPragmaOracleMockDispatcherTrait, PricesData
};
use tests::utils::{constant::DEFAULT_TIMEOUT, aggregator::update_pragma_response};
use tests::tests_lib::{deploy_address_provider, deploy_pragma_oracle_mock, deploy_price_feed};

fn setup() -> (IAddressProviderDispatcher, IPriceFeedDispatcher, IPragmaOracleMockDispatcher) {
    let address_provider_address: ContractAddress = deploy_address_provider();
    let address_provider: IAddressProviderDispatcher = IAddressProviderDispatcher {
        contract_address: address_provider_address
    };
    let pragma_mock_address: ContractAddress = deploy_pragma_oracle_mock();
    let pragma_mock: IPragmaOracleMockDispatcher = IPragmaOracleMockDispatcher {
        contract_address: pragma_mock_address
    };

    let price_feed_address: ContractAddress = deploy_price_feed(
        address_provider_address, pragma_mock_address
    );
    let price_feed: IPriceFeedDispatcher = IPriceFeedDispatcher {
        contract_address: price_feed_address
    };

    return (address_provider, price_feed, pragma_mock);
}
