use starknet::ContractAddress;
use shisui::utils::traits::ContractAddressDefault;

#[derive(Serde, Drop, Copy, starknet::Store, Default)]
struct OracleRecord {
    oracle: ContractAddress,
    timeout_seconds: u64,
    decimals: u8,
}


#[starknet::interface]
trait IPriceFeed<TContractState> {
    fn set_oracle(
        ref self: TContractState,
        _token: ContractAddress,
        _oracle: ContractAddress,
        _timeout_seconds: u64,
    );

    // @notice Fetches the price for an asset from a previosly configured oracle.
    // @dev Callers:
    //     - BorrowerOperations.open_vessel()
    //     - BorrowerOperations.adjust_vessel()
    //     - BorrowerOperations.close_vessel()
    //     - VesselManagerOperations.liquidate_vessels()
    //     - VesselManagerOperations.batch_liquidate_vessels()
    //     - VesselManagerOperations.redeem_collateral()
    fn fetch_price(self: @TContractState, _token: ContractAddress) -> u256;

    fn get_oracles(self: @TContractState, _token: ContractAddress) -> OracleRecord;
}


#[starknet::contract]
mod PriceFeed {
    use starknet::ContractAddress;
    use shisui::core::address_provider::{
        IAddressProviderDispatcher, IAddressProviderDispatcherTrait
    };
    use super::OracleRecord;

    const TARGET_DECIMALS: u8 = 18;

    #[storage]
    struct Storage {
        address_provider: IAddressProviderDispatcher,
        oracles: LegacyMap<ContractAddress, OracleRecord>,
    }

    mod Errors {
        const PriceFeed__ExistingOracleRequired: felt252 = 'Existing Oracle Required';
        const PriceFeed__InvalidDecimalsError: felt252 = 'Invalid Decimals Error';
        const PriceFeed__InvalidOracleResponseError: felt252 = 'Invalid Oracle Response Error';
        const PriceFeed__TimelockOnlyError: felt252 = 'Timelock Only Error';
        const PriceFeed__UnknownAssetError: felt252 = 'Unknown Asset Error';
    }

    #[constructor]
    fn constructor(ref self: ContractState, address_provider: IAddressProviderDispatcher) {}

    #[external(v0)]
    impl PriceFeedImpl of super::IPriceFeed<ContractState> {
        fn set_oracle(
            ref self: ContractState,
            _token: ContractAddress,
            _oracle: ContractAddress,
            _timeout_seconds: u64
        ) {}

        fn fetch_price(self: @ContractState, _token: ContractAddress) -> u256 {
            return 0;
        }

        fn get_oracles(self: @ContractState, _token: ContractAddress) -> OracleRecord {
            return Default::default();
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _fetch_decimals(_oracle: ContractAddress) -> u8 {
            return 18;
        }
        fn _fetch_oracle_scaled_price(_oracle_price: u256, _price_timestamp: u64) -> u256 {
            return 0;
        }
        fn _is_stale_price(_priceTimestamp: u256, _oracle_timeout_seconds: u64) -> bool {
            return false;
        }

        fn _scale_price_by_digits(_price: u256, _price_digits: u256) -> u256 {
            return 0;
        }
        fn _require_owner_or_timelock(_token: ContractAddress) {}
    }
}
