use starknet::ContractAddress;
use shisui::utils::traits::ContractAddressDefault;
use pragma_lib::abi::{IPragmaABIDispatcher, IPragmaABIDispatcherTrait};

#[derive(Serde, Drop, Copy, starknet::Store, Default)]
struct OracleRecord {
    pair_id: felt252,
    timeout_seconds: u64
}


#[starknet::interface]
trait IPriceFeed<TContractState> {
    fn set_pragma_contract(ref self: TContractState, pragma_contract: IPragmaABIDispatcher);

    fn set_oracle(
        ref self: TContractState, token: ContractAddress, pair_id: felt252, timeout_seconds: u64
    );

    // @notice Fetches the price for an asset from a previosly configured oracle.
    // @dev Callers:
    //     - BorrowerOperations.open_vessel()
    //     - BorrowerOperations.adjust_vessel()
    //     - BorrowerOperations.close_vessel()
    //     - VesselManagerOperations.liquidate_vessels()
    //     - VesselManagerOperations.batch_liquidate_vessels()
    //     - VesselManagerOperations.redeem_collateral()
    fn fetch_price(self: @TContractState, token: ContractAddress) -> u256;

    fn get_oracle(self: @TContractState, token: ContractAddress) -> OracleRecord;

    fn get_pragma_contract(self: @TContractState) -> ContractAddress;

    fn get_address_provider(self: @TContractState) -> ContractAddress;
}


#[starknet::contract]
mod PriceFeed {
    use starknet::{
        ContractAddress, get_caller_address, contract_address_const, get_block_timestamp
    };
    use openzeppelin::access::ownable::{OwnableComponent, OwnableComponent::InternalImpl};
    use pragma_lib::abi::{IPragmaABIDispatcher, IPragmaABIDispatcherTrait};
    use pragma_lib::types::{AggregationMode, DataType, PragmaPricesResponse};
    use shisui::core::address_provider::{
        IAddressProviderDispatcher, IAddressProviderDispatcherTrait, AddressesKey
    };
    use shisui::utils::errors::CommunErrors;
    use shisui::utils::math::pow;
    use shisui::utils::constants::TARGET_DECIMALS;
    use super::OracleRecord;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;

    #[storage]
    struct Storage {
        pragma_contract: IPragmaABIDispatcher,
        address_provider: IAddressProviderDispatcher,
        oracles: LegacyMap<ContractAddress, OracleRecord>,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        NewOracleRegistered: NewOracleRegistered,
    }


    #[derive(Drop, starknet::Event)]
    struct NewOracleRegistered {
        #[key]
        token: ContractAddress,
        pair_id: felt252,
        timeout_seconds: u64
    }

    mod PriceFeedErrors {
        const InvalidOracleResponseError: felt252 = 'Invalid Oracle Response Error';
        const UnknownAssetError: felt252 = 'Unknown Asset Error';
        const InvalidPairId: felt252 = 'Unknown Pair Id Error';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        address_provider: IAddressProviderDispatcher,
        pragma_contract: IPragmaABIDispatcher
    ) {
        assert(address_provider.contract_address.is_non_zero(), CommunErrors::AddressZero);
        assert(pragma_contract.contract_address.is_non_zero(), CommunErrors::AddressZero);
        self.pragma_contract.write(pragma_contract);
        self.address_provider.write(address_provider);
        self.ownable.initializer(get_caller_address());
    }

    #[external(v0)]
    impl PriceFeedImpl of super::IPriceFeed<ContractState> {
        fn set_pragma_contract(ref self: ContractState, pragma_contract: IPragmaABIDispatcher) {
            assert(pragma_contract.contract_address.is_non_zero(), PriceFeedErrors::InvalidPairId);
            self.assert_owner_or_timelock(self.pragma_contract.read().contract_address.is_zero());
            self.pragma_contract.write(pragma_contract);
        }

        fn set_oracle(
            ref self: ContractState, token: ContractAddress, pair_id: felt252, timeout_seconds: u64
        ) {
            let mut oracle: OracleRecord = self.oracles.read(token);
            self.assert_owner_or_timelock(oracle.pair_id.is_zero());

            oracle.pair_id = pair_id;
            oracle.timeout_seconds = timeout_seconds;

            self.fetch_oracle_scaled_price(oracle);

            self.oracles.write(token, oracle);
            self.emit(NewOracleRegistered { token, pair_id, timeout_seconds });
        }

        fn fetch_price(self: @ContractState, token: ContractAddress) -> u256 {
            let oracle: OracleRecord = self.oracles.read(token);
            assert(oracle.pair_id.is_non_zero(), PriceFeedErrors::UnknownAssetError);

            return self.fetch_oracle_scaled_price(oracle);
        }


        fn get_oracle(self: @ContractState, token: ContractAddress) -> OracleRecord {
            return self.oracles.read(token);
        }

        fn get_pragma_contract(self: @ContractState) -> ContractAddress {
            return self.pragma_contract.read().contract_address;
        }
        fn get_address_provider(self: @ContractState) -> ContractAddress {
            return self.address_provider.read().contract_address;
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn fetch_oracle_scaled_price(self: @ContractState, oracle: OracleRecord) -> u256 {
            let prices_response: PragmaPricesResponse = self.fetch_oracle(oracle);
            let price = self
                .scale_price_by_digits(
                    prices_response.price.into(), prices_response.decimals.try_into().unwrap()
                );
            assert(price.is_non_zero(), PriceFeedErrors::InvalidOracleResponseError);
            return price;
        }

        fn fetch_oracle(self: @ContractState, oracle: OracleRecord) -> PragmaPricesResponse {
            let pragma_contract: IPragmaABIDispatcher = self.pragma_contract.read();
            let data: PragmaPricesResponse = pragma_contract
                .get_data(DataType::SpotEntry(oracle.pair_id), AggregationMode::Median(()));

            assert(data.decimals.is_non_zero(), PriceFeedErrors::InvalidPairId);
            assert(
                self.is_not_stale_price(data.last_updated_timestamp, oracle.timeout_seconds),
                PriceFeedErrors::InvalidOracleResponseError
            );
            return data;
        }

        fn is_not_stale_price(
            self: @ContractState, price_timestamp: u64, oracle_timeout_seconds: u64
        ) -> bool {
            return get_block_timestamp() - price_timestamp <= oracle_timeout_seconds;
        }

        fn scale_price_by_digits(self: @ContractState, price: u256, price_decimals: u8) -> u256 {
            if (price_decimals > TARGET_DECIMALS) {
                return price / pow(10, (price_decimals - TARGET_DECIMALS));
            }
            if (price_decimals < TARGET_DECIMALS) {
                return price * pow(10, (TARGET_DECIMALS - price_decimals));
            }
            return price;
        }

        fn assert_owner_or_timelock(self: @ContractState, is_new: bool) {
            let caller = get_caller_address();
            if is_new {
                self.ownable.assert_only_owner();
            } else {
                assert(
                    caller == self.address_provider.read().get_address(AddressesKey::timelock),
                    CommunErrors::OnlyTimelock
                );
            }
        }
    }
}
