use shisui::mocks::pragma_oracle_mock::{
    IPragmaOracleMockDispatcher, IPragmaOracleMockDispatcherTrait, PricesData
};

fn update_pragma_response(
    pragma_mock: IPragmaOracleMockDispatcher, price: u256, decimals: u32, timestamp: u64
) {
    let value = PricesData {
        price: price.try_into().unwrap(), decimals: decimals, last_updated_timestamp: timestamp
    };
    pragma_mock.set_data(value);
}
