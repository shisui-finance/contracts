use starknet::ContractAddress;


#[derive(Serde, Drop, Copy, starknet::Store, Default)]
struct CollateralParams {
    decimals: u256,
    index: u256, // Maps to token address in valid_collateral[]
    is_active: bool,
    borrowing_fee: u256,
    ccr: u256,
    mcr: u256,
    debt_token_gas_compensation: u256,
    min_net_debt: u256,
    mint_cap: u256,
    percent_divisor: u256,
    redemption_fee_floor: u256,
    redemption_block_timestamp: u256
}


#[starknet::interface]
trait IAdminContract<TContractState> {
    fn add_new_collateral(
        ref self: TContractState,
        collateral: ContractAddress,
        debt_token_gas_compensation: ContractAddress,
        decimals: u256
    );

    fn set_collateral_parameters(
        ref self: TContractState,
        borrowing_fee: u256,
        ccr: u256,
        mcr: u256,
        min_net_debt: u256,
        mint_cap: u256,
        percent_divisor: u256,
        redemption_fee_floor: u256,
    );

    fn set_is_active(ref self: TContractState, collateral: ContractAddress, active: bool);
    fn set_borrowing_fee(
        ref self: TContractState, collateral: ContractAddress, borrowing_fee: u256
    );
    fn set_ccr(ref self: TContractState, collateral: ContractAddress, ccr: u256);
    fn set_mcr(ref self: TContractState, collateral: ContractAddress, mcr: u256);
    fn set_min_net_debt(ref self: TContractState, collateral: ContractAddress, min_net_debt: u256);
    fn set_mint_cap(ref self: TContractState, collateral: ContractAddress, mint_cap: u256);
    fn set_percent_divisor(
        ref self: TContractState, collateral: ContractAddress, percent_divisor: u256
    );
    fn set_redemption_fee_floor(
        ref self: TContractState, collateral: ContractAddress, redemption_fee_floor: u256
    );
    fn set_redemption_block_timestamp(
        ref self: TContractState, collateral: ContractAddress, block_timestamp: u256
    );

    fn get_valid_collateral(self: @TContractState) -> Span<ContractAddress>;
    fn get_is_active(self: @TContractState, collateral: ContractAddress) -> bool;
    fn get_decimals(self: @TContractState, collateral: ContractAddress) -> u256;
    fn get_index(self: @TContractState, collateral: ContractAddress) -> u256;
    fn get_indices(self: @TContractState, collaterals: Span<ContractAddress>) -> Span<u256>;
    fn get_mcr(self: @TContractState, collateral: ContractAddress) -> u256;
    fn get_ccr(self: @TContractState, collateral: ContractAddress) -> u256;
    fn get_debt_token_gas_compensation(self: @TContractState, collateral: ContractAddress) -> u256;
    fn get_min_net_debt(self: @TContractState, collateral: ContractAddress) -> u256;
    fn get_percent_divisor(self: @TContractState, collateral: ContractAddress) -> u256;
    fn get_borrowing_fee(self: @TContractState, collateral: ContractAddress) -> u256;
    fn get_redemption_fee_floor(self: @TContractState, collateral: ContractAddress) -> u256;
    fn get_redemption_block_timestamp(self: @TContractState, collateral: ContractAddress) -> u256;
    fn get_mint_cap(self: @TContractState, collateral: ContractAddress) -> u256;
    fn get_total_asset_debt(self: @TContractState, asset: ContractAddress) -> u256;
    fn get_collaterals_params(
        self: @TContractState, collateral: ContractAddress
    ) -> CollateralParams;
    fn get_default_borrowing_fee(self: @TContractState) -> u256;
    fn get_default_ccr(self: @TContractState) -> u256;
    fn get_default_mcr(self: @TContractState) -> u256;
    fn get_default_min_net_debt(self: @TContractState) -> u256;
    fn get_default_mint_cap(self: @TContractState) -> u256;
    fn get_default_percent_divisor(self: @TContractState) -> u256;
    fn get_default_redemption_fee_floor(self: @TContractState) -> u256;
    fn get_default_redemption_block_timestamp(self: @TContractState) -> u256;
}


#[starknet::contract]
mod AdminContract {
    use starknet::{ContractAddress, get_caller_address};

    use shisui::utils::{precision::DECIMAL_PRECISION, array::StoreContractAddressArray};
    use shisui::core::address_provider::{
        IAddressProviderDispatcher, IAddressProviderDispatcherTrait
    };
    use super::CollateralParams;


    const _100pct: u256 = 1_000_000_000_000_000_000; // 1e18 == 100%
    const DEFAULT_DECIMALS: u256 = 18;

    const BORROWING_FEE_DEFAULT: u256 = 5_000_000_000_000_000; // 0.5%
    const CCR_DEFAULT: u256 = 1_500_000_000_000_000_000; // 1.5e18
    const MCR_DEFAULT: u256 = 1_100_000_000_000_000_000; // 1.1e18
    const MIN_NET_DEBT_DEFAULT: u256 = 2_000_000_000_000_000_000_000; // 2_000e18
    const MINT_CAP_DEFAULT: u256 = 1_000_000_000_000_000_000_000_000; // 1 million
    const PERCENT_DIVISOR_DEFAULT: u256 = 200; // dividing by 200 yields 0.5%
    const REDEMPTION_FEE_FLOOR_DEFAULT: u256 = 5_000_000_000_000_000; // 0.5%
    const REDEMPTION_BLOCK_TIMESTAMP_DEFAULT: u256 = 1_000_000_000_000_000_000_000_000; // 1 million

    mod Errors {
        const AdminContract__CollateralAlreadyExist: felt252 = 'Collateral already exist';
        const AdminContract__CollateralNotEqualToDefault: felt252 =
            'Collateral decimals not default';
        const AdminContract__CollateralNotActive: felt252 = 'Collateral not active';
        const AdminContract__CollateralNotExist: felt252 = 'Collateral does not exist';
        const AdminContract__SafeCheckError: felt252 = 'Collateral already init';
    }

    #[storage]
    struct Storage {
        address_provider: IAddressProviderDispatcher,
        collateral_params: LegacyMap<ContractAddress, CollateralParams>,
        valid_collateral: Array<ContractAddress>
    }


    #[constructor]
    fn constructor(ref self: ContractState) {}

    #[external(v0)]
    impl AdminContractImpl of super::IAdminContract<ContractState> {
        fn add_new_collateral(
            ref self: ContractState,
            collateral: ContractAddress,
            debt_token_gas_compensation: ContractAddress,
            decimals: u256
        ) {}

        fn set_collateral_parameters(
            ref self: ContractState,
            borrowing_fee: u256,
            ccr: u256,
            mcr: u256,
            min_net_debt: u256,
            mint_cap: u256,
            percent_divisor: u256,
            redemption_fee_floor: u256,
        ) {}

        fn set_is_active(ref self: ContractState, collateral: ContractAddress, active: bool) {}

        fn set_borrowing_fee(
            ref self: ContractState, collateral: ContractAddress, borrowing_fee: u256
        ) {}

        fn set_ccr(ref self: ContractState, collateral: ContractAddress, ccr: u256) {}

        fn set_mcr(ref self: ContractState, collateral: ContractAddress, mcr: u256) {}

        fn set_min_net_debt(
            ref self: ContractState, collateral: ContractAddress, min_net_debt: u256
        ) {}

        fn set_mint_cap(ref self: ContractState, collateral: ContractAddress, mint_cap: u256) {}

        fn set_percent_divisor(
            ref self: ContractState, collateral: ContractAddress, percent_divisor: u256
        ) {}

        fn set_redemption_fee_floor(
            ref self: ContractState, collateral: ContractAddress, redemption_fee_floor: u256
        ) {}

        fn set_redemption_block_timestamp(
            ref self: ContractState, collateral: ContractAddress, block_timestamp: u256
        ) {}

        fn get_valid_collateral(self: @ContractState) -> Span<ContractAddress> {
            return array![].span();
        }

        fn get_is_active(self: @ContractState, collateral: ContractAddress) -> bool {
            return false;
        }

        fn get_decimals(self: @ContractState, collateral: ContractAddress) -> u256 {
            return 0;
        }

        fn get_index(self: @ContractState, collateral: ContractAddress) -> u256 {
            return 0;
        }

        fn get_indices(self: @ContractState, collaterals: Span<ContractAddress>) -> Span<u256> {
            return array![].span();
        }

        fn get_mcr(self: @ContractState, collateral: ContractAddress) -> u256 {
            return 0;
        }

        fn get_ccr(self: @ContractState, collateral: ContractAddress) -> u256 {
            return 0;
        }

        fn get_debt_token_gas_compensation(
            self: @ContractState, collateral: ContractAddress
        ) -> u256 {
            return 0;
        }

        fn get_min_net_debt(self: @ContractState, collateral: ContractAddress) -> u256 {
            return 0;
        }

        fn get_percent_divisor(self: @ContractState, collateral: ContractAddress) -> u256 {
            return 0;
        }

        fn get_borrowing_fee(self: @ContractState, collateral: ContractAddress) -> u256 {
            return 0;
        }

        fn get_redemption_fee_floor(self: @ContractState, collateral: ContractAddress) -> u256 {
            return 0;
        }

        fn get_redemption_block_timestamp(
            self: @ContractState, collateral: ContractAddress
        ) -> u256 {
            return 0;
        }

        fn get_mint_cap(self: @ContractState, collateral: ContractAddress) -> u256 {
            return 0;
        }

        fn get_total_asset_debt(self: @ContractState, asset: ContractAddress) -> u256 {
            return 0;
        }

        fn get_collaterals_params(
            self: @ContractState, collateral: ContractAddress
        ) -> CollateralParams {
            return Default::default();
        }

        fn get_default_borrowing_fee(self: @ContractState) -> u256 {
            return BORROWING_FEE_DEFAULT;
        }
        fn get_default_ccr(self: @ContractState) -> u256 {
            return CCR_DEFAULT;
        }
        fn get_default_mcr(self: @ContractState) -> u256 {
            return MCR_DEFAULT;
        }
        fn get_default_min_net_debt(self: @ContractState) -> u256 {
            return MIN_NET_DEBT_DEFAULT;
        }
        fn get_default_mint_cap(self: @ContractState) -> u256 {
            return MINT_CAP_DEFAULT;
        }
        fn get_default_percent_divisor(self: @ContractState) -> u256 {
            return PERCENT_DIVISOR_DEFAULT;
        }
        fn get_default_redemption_fee_floor(self: @ContractState) -> u256 {
            return REDEMPTION_FEE_FLOOR_DEFAULT;
        }
        fn get_default_redemption_block_timestamp(self: @ContractState) -> u256 {
            return REDEMPTION_BLOCK_TIMESTAMP_DEFAULT;
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _exists(self: @ContractState, collateral: ContractAddress) {}

        fn _only_timelock(self: @ContractState) {}

        fn _safe_check(
            self: @ContractState,
            parameter: felt252,
            collateral: ContractAddress,
            entered_value: u256,
            min: u256,
            max: u256
        ) {}
    }
}
