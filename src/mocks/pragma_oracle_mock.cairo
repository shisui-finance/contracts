//! Contract to mock Pragma Oracle
use pragma_lib::types::{AggregationMode, DataType, PragmaPricesResponse};


#[derive(Serde, Drop, starknet::Store, Copy)]
struct PricesData {
    price: u128,
    decimals: u32,
    last_updated_timestamp: u64,
}


#[starknet::interface]
trait IPragmaOracleMock<TContractState> {
    fn set_data(ref self: TContractState, price_data: PricesData);
    fn get_data(
        self: @TContractState, data_type: DataType, aggregation_mode: AggregationMode
    ) -> PragmaPricesResponse;
}

#[starknet::contract]
mod PragmaOracleMock {
    use option::OptionTrait;
    use starknet::{
        ContractAddress, get_caller_address, contract_address_const, get_block_timestamp
    };
    use pragma_lib::types::{AggregationMode, DataType, PragmaPricesResponse};
    use shisui::utils::math::pow;
    use super::PricesData;
    use snforge_std::PrintTrait;

    #[storage]
    struct Storage {
        info: LegacyMap<felt252, PricesData>,
    }


    #[external(v0)]
    impl PragmaOracleImpl of super::IPragmaOracleMock<ContractState> {
        fn set_data(ref self: ContractState, price_data: PricesData) {
            self.info.write(1, price_data);
        }

        fn get_data(
            self: @ContractState, data_type: DataType, aggregation_mode: AggregationMode
        ) -> PragmaPricesResponse {
            let price_data = self.info.read(1);

            return PragmaPricesResponse {
                price: price_data.price,
                decimals: price_data.decimals,
                last_updated_timestamp: price_data.last_updated_timestamp,
                num_sources_aggregated: 1_u32,
                expiration_timestamp: Option::Some(0)
            };
        }
    }
}
