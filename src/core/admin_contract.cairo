use starknet::ContractAddress;


#[derive(Serde, Drop, Copy, starknet::Store, Default)]
struct CollateralParams {
    decimals: u8,
    index: usize, // Maps to token address in supported_collateral[]
    is_active: bool,
    borrowing_fee: u256,
    ccr: u256,
    mcr: u256,
    debt_token_gas_compensation: u256,
    min_net_debt: u256,
    mint_cap: u256,
    percent_divisor: u256,
    redemption_fee_floor: u256,
    redemption_block_timestamp: u64
}


#[starknet::interface]
trait IAdminContract<TContractState> {
    fn add_new_collateral(
        ref self: TContractState,
        collateral: ContractAddress,
        debt_token_gas_compensation: u256,
        decimals: u8
    );

    fn set_collateral_parameters(
        ref self: TContractState,
        collateral: ContractAddress,
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
        ref self: TContractState, collateral: ContractAddress, block_timestamp: u64
    );
    fn set_setup_initialized(ref self: TContractState);
    fn get_supported_collateral(self: @TContractState) -> Span<ContractAddress>;
    fn get_is_active(self: @TContractState, collateral: ContractAddress) -> bool;
    fn get_decimals(self: @TContractState, collateral: ContractAddress) -> u8;
    fn get_index(self: @TContractState, collateral: ContractAddress) -> usize;
    fn get_indices(self: @TContractState, collaterals: Span<ContractAddress>) -> Span<usize>;
    fn get_mcr(self: @TContractState, collateral: ContractAddress) -> u256;
    fn get_ccr(self: @TContractState, collateral: ContractAddress) -> u256;
    fn get_debt_token_gas_compensation(self: @TContractState, collateral: ContractAddress) -> u256;
    fn get_min_net_debt(self: @TContractState, collateral: ContractAddress) -> u256;
    fn get_percent_divisor(self: @TContractState, collateral: ContractAddress) -> u256;
    fn get_borrowing_fee(self: @TContractState, collateral: ContractAddress) -> u256;
    fn get_redemption_fee_floor(self: @TContractState, collateral: ContractAddress) -> u256;
    fn get_redemption_block_timestamp(self: @TContractState, collateral: ContractAddress) -> u64;
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
    fn get_default_redemption_block_timestamp(self: @TContractState) -> u64;
}


#[starknet::contract]
mod AdminContract {
    use starknet::{ContractAddress, get_caller_address};
    use openzeppelin::access::ownable::{OwnableComponent, OwnableComponent::InternalImpl};
    use shisui::utils::{
        constants::DECIMAL_PRECISION, array::StoreContractAddressArray, errors::CommunErrors,
        math::pow
    };
    use shisui::core::address_provider::{
        IAddressProviderDispatcher, IAddressProviderDispatcherTrait, AddressesKey
    };
    use shisui::pools::{
        stability_pool::{IStabilityPoolDispatcher, IStabilityPoolDispatcherTrait},
        active_pool::{IActivePoolDispatcher, IActivePoolDispatcherTrait},
        default_pool::{IDefaultPoolDispatcher, IDefaultPoolDispatcherTrait}
    };
    use super::CollateralParams;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;

    const ONE_HUNDRED_PCT: u256 = 1_000_000_000_000_000_000; // 1e18 == 100%
    const DEFAULT_DECIMALS: u8 = 18;

    const BORROWING_FEE_DEFAULT: u256 = 5_000_000_000_000_000; // 0.5%
    const CCR_DEFAULT: u256 = 1_500_000_000_000_000_000; // 1.5e18
    const MCR_DEFAULT: u256 = 1_100_000_000_000_000_000; // 1.1e18
    const MIN_NET_DEBT_DEFAULT: u256 = 2_000_000_000_000_000_000_000; // 2_000e18
    const MINT_CAP_DEFAULT: u256 = 1_000_000_000_000_000_000_000_000; // 1 million
    const PERCENT_DIVISOR_DEFAULT: u256 = 200; // dividing by 200 yields 0.5%
    const REDEMPTION_FEE_FLOOR_DEFAULT: u256 = 5_000_000_000_000_000; // 0.5%
    const REDEMPTION_BLOCK_TIMESTAMP_DEFAULT: u64 = 0xffffffffffffffff_u64; // max u64

    mod AdminContractErrors {
        const CollateralAlreadyExist: felt252 = 'Collateral already exist';
        const CollateralNotEqualToDefault: felt252 = 'Collateral decimals not default';
        const CollateralNotActive: felt252 = 'Collateral not active';
        const CollateralNotExist: felt252 = 'Collateral does not exist';
        const SafeCheckError: felt252 = 'Collateral already init';
    }


    #[storage]
    struct Storage {
        address_provider: IAddressProviderDispatcher,
        collateral_params: LegacyMap<ContractAddress, CollateralParams>,
        supported_collateral: Array<ContractAddress>,
        is_setup_initialized: bool,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        CollateralAdded: CollateralAdded,
        BorrowingFeeUpdated: BorrowingFeeUpdated,
        CCRUpdated: CCRUpdated,
        MCRUpdated: MCRUpdated,
        MinNetDebtUpdated: MinNetDebtUpdated,
        MintCapUpdated: MintCapUpdated,
        PercentDivisorUpdated: PercentDivisorUpdated,
        RedemptionFeeFloorUpdated: RedemptionFeeFloorUpdated,
        RedemptionBlockTimestampUpdated: RedemptionBlockTimestampUpdated,
    }

    #[derive(Drop, starknet::Event)]
    struct CollateralAdded {
        collateral: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct BorrowingFeeUpdated {
        collateral: ContractAddress,
        old_borrowing_fee: u256,
        borrowing_fee: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct CCRUpdated {
        collateral: ContractAddress,
        old_ccr: u256,
        ccr: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct MCRUpdated {
        collateral: ContractAddress,
        old_mcr: u256,
        mcr: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct MinNetDebtUpdated {
        collateral: ContractAddress,
        old_min_net_debt: u256,
        min_net_debt: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct MintCapUpdated {
        collateral: ContractAddress,
        old_mint_cap: u256,
        mint_cap: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct PercentDivisorUpdated {
        collateral: ContractAddress,
        old_percent_divisor: u256,
        percent_divisor: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct RedemptionFeeFloorUpdated {
        collateral: ContractAddress,
        old_redemption_fee_floor: u256,
        redemption_fee_floor: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct RedemptionBlockTimestampUpdated {
        collateral: ContractAddress,
        old_redemption_block_timestamp: u64,
        redemption_block_timestamp: u64,
    }


    #[constructor]
    fn constructor(ref self: ContractState, address_provider: ContractAddress) {
        self.ownable.initializer(get_caller_address());
        self
            .address_provider
            .write(IAddressProviderDispatcher { contract_address: address_provider });
    }

    #[external(v0)]
    impl AdminContractImpl of super::IAdminContract<ContractState> {
        fn add_new_collateral(
            ref self: ContractState,
            collateral: ContractAddress,
            debt_token_gas_compensation: u256,
            decimals: u8
        ) {
            self.only_timelock();
            assert(!self.exist(collateral), Errors::AdminContract__CollateralAlreadyExist);
            assert(
                decimals == DEFAULT_DECIMALS, Errors::AdminContract__CollateralDecimalsNotSupported
            );
            let mut coll_array = self.supported_collateral.read();
            let index = coll_array.len();
            coll_array.append(collateral);
            self.supported_collateral.write(coll_array);

            self
                .collateral_params
                .write(
                    collateral,
                    CollateralParams {
                        decimals,
                        index,
                        is_active: false,
                        borrowing_fee: BORROWING_FEE_DEFAULT,
                        ccr: CCR_DEFAULT,
                        mcr: MCR_DEFAULT,
                        debt_token_gas_compensation,
                        min_net_debt: MIN_NET_DEBT_DEFAULT,
                        mint_cap: MINT_CAP_DEFAULT,
                        percent_divisor: PERCENT_DIVISOR_DEFAULT,
                        redemption_fee_floor: REDEMPTION_FEE_FLOOR_DEFAULT,
                        redemption_block_timestamp: REDEMPTION_BLOCK_TIMESTAMP_DEFAULT
                    }
                );

            IStabilityPoolDispatcher {
                contract_address: self
                    .address_provider
                    .read()
                    .get_address(AddressesKey::stability_pool)
            }
                .add_collateral_type(collateral);

            self.emit(CollateralAdded { collateral });
        }

        fn set_collateral_parameters(
            ref self: ContractState,
            collateral: ContractAddress,
            borrowing_fee: u256,
            ccr: u256,
            mcr: u256,
            min_net_debt: u256,
            mint_cap: u256,
            percent_divisor: u256,
            redemption_fee_floor: u256,
        ) {
            self.only_timelock();
            assert(self.exist(collateral), Errors::AdminContract__CollateralNotExist);
            let mut params = self.collateral_params.read(collateral);
            params.is_active = true;
            self.set_borrowing_fee_internal(ref params, collateral, borrowing_fee);
            self.set_ccr_internal(ref params, collateral, ccr);
            self.set_mcr_internal(ref params, collateral, mcr);
            self.set_min_net_debt_internal(ref params, collateral, min_net_debt);
            self.set_mint_cap_internal(ref params, collateral, mint_cap);
            self.set_percent_divisor_internal(ref params, collateral, percent_divisor);
            self.set_redemption_fee_floor_internal(ref params, collateral, redemption_fee_floor);
            self.collateral_params.write(collateral, params);
        }

        fn set_is_active(ref self: ContractState, collateral: ContractAddress, active: bool) {
            self.only_timelock();
            assert(self.exist(collateral), Errors::AdminContract__CollateralNotExist);
            let mut params = self.collateral_params.read(collateral);
            params.is_active = active;
            self.collateral_params.write(collateral, params);
        }

        fn set_borrowing_fee(
            ref self: ContractState, collateral: ContractAddress, borrowing_fee: u256
        ) {
            self.only_timelock();
            let mut params = self.collateral_params.read(collateral);
            self.set_borrowing_fee_internal(ref params, collateral, borrowing_fee);
            self.collateral_params.write(collateral, params);
        }

        fn set_ccr(ref self: ContractState, collateral: ContractAddress, ccr: u256) {
            self.only_timelock();
            let mut params = self.collateral_params.read(collateral);
            self.set_ccr_internal(ref params, collateral, ccr);
            self.collateral_params.write(collateral, params);
        }

        fn set_mcr(ref self: ContractState, collateral: ContractAddress, mcr: u256) {
            self.only_timelock();
            let mut params = self.collateral_params.read(collateral);
            self.set_mcr_internal(ref params, collateral, mcr);
            self.collateral_params.write(collateral, params);
        }

        fn set_min_net_debt(
            ref self: ContractState, collateral: ContractAddress, min_net_debt: u256
        ) {
            self.only_timelock();
            let mut params = self.collateral_params.read(collateral);
            self.set_min_net_debt_internal(ref params, collateral, min_net_debt);
            self.collateral_params.write(collateral, params);
        }

        fn set_mint_cap(ref self: ContractState, collateral: ContractAddress, mint_cap: u256) {
            self.only_timelock();
            assert(self.exist(collateral), Errors::AdminContract__CollateralNotExist);
            let mut params = self.collateral_params.read(collateral);
            self.set_mint_cap_internal(ref params, collateral, mint_cap);
            self.collateral_params.write(collateral, params);
        }

        fn set_percent_divisor(
            ref self: ContractState, collateral: ContractAddress, percent_divisor: u256
        ) {
            self.only_timelock();
            let mut params = self.collateral_params.read(collateral);
            self.set_percent_divisor_internal(ref params, collateral, percent_divisor);
            self.collateral_params.write(collateral, params);
        }

        fn set_redemption_fee_floor(
            ref self: ContractState, collateral: ContractAddress, redemption_fee_floor: u256
        ) {
            self.only_timelock();
            let mut params = self.collateral_params.read(collateral);
            self.set_redemption_fee_floor_internal(ref params, collateral, redemption_fee_floor);
            self.collateral_params.write(collateral, params);
        }

        fn set_redemption_block_timestamp(
            ref self: ContractState, collateral: ContractAddress, block_timestamp: u64
        ) {
            self.only_timelock();
            assert(self.exist(collateral), Errors::AdminContract__CollateralNotExist);
            let mut params = self.collateral_params.read(collateral);
            self.set_redemption_block_timestamp_internal(ref params, collateral, block_timestamp);
            self.collateral_params.write(collateral, params);
        }

        fn set_setup_initialized(ref self: ContractState) {
            self.only_timelock();
            self.is_setup_initialized.write(true);
        }

        fn get_supported_collateral(self: @ContractState) -> Span<ContractAddress> {
            return self.supported_collateral.read().span();
        }

        fn get_is_active(self: @ContractState, collateral: ContractAddress) -> bool {
            return self.collateral_params.read(collateral).is_active;
        }

        fn get_decimals(self: @ContractState, collateral: ContractAddress) -> u8 {
            return self.collateral_params.read(collateral).decimals;
        }

        fn get_index(self: @ContractState, collateral: ContractAddress) -> usize {
            return self.collateral_params.read(collateral).index;
        }

        fn get_indices(self: @ContractState, collaterals: Span<ContractAddress>) -> Span<usize> {
            let mut indices: Array<usize> = ArrayTrait::new();
            let mut colls = collaterals;
            loop {
                match colls.pop_front() {
                    Option::Some(collateral) => {
                        assert(
                            self.exist(*collateral), Errors::AdminContract__CollateralAlreadyExist
                        );
                        let index = self.collateral_params.read(*collateral).index;
                        indices.append(index);
                    },
                    Option::None(_) => { break; }
                };
            };

            return indices.span();
        }

        fn get_mcr(self: @ContractState, collateral: ContractAddress) -> u256 {
            return self.collateral_params.read(collateral).mcr;
        }

        fn get_ccr(self: @ContractState, collateral: ContractAddress) -> u256 {
            return self.collateral_params.read(collateral).ccr;
        }

        fn get_debt_token_gas_compensation(
            self: @ContractState, collateral: ContractAddress
        ) -> u256 {
            return self.collateral_params.read(collateral).debt_token_gas_compensation;
        }

        fn get_min_net_debt(self: @ContractState, collateral: ContractAddress) -> u256 {
            return self.collateral_params.read(collateral).min_net_debt;
        }

        fn get_percent_divisor(self: @ContractState, collateral: ContractAddress) -> u256 {
            return self.collateral_params.read(collateral).percent_divisor;
        }

        fn get_borrowing_fee(self: @ContractState, collateral: ContractAddress) -> u256 {
            return self.collateral_params.read(collateral).borrowing_fee;
        }

        fn get_redemption_fee_floor(self: @ContractState, collateral: ContractAddress) -> u256 {
            return self.collateral_params.read(collateral).redemption_fee_floor;
        }

        fn get_redemption_block_timestamp(
            self: @ContractState, collateral: ContractAddress
        ) -> u64 {
            return self.collateral_params.read(collateral).redemption_block_timestamp;
        }

        fn get_mint_cap(self: @ContractState, collateral: ContractAddress) -> u256 {
            return self.collateral_params.read(collateral).mint_cap;
        }

        fn get_total_asset_debt(self: @ContractState, asset: ContractAddress) -> u256 {
            let active_pool_debt_balance = IActivePoolDispatcher {
                contract_address: self
                    .address_provider
                    .read()
                    .get_address(AddressesKey::active_pool)
            }
                .get_debt_token_balance(asset);
            let default_pool_debt_balance = IDefaultPoolDispatcher {
                contract_address: self
                    .address_provider
                    .read()
                    .get_address(AddressesKey::default_pool)
            }
                .get_debt_token_balance(asset);
            return active_pool_debt_balance + default_pool_debt_balance;
        }

        fn get_collaterals_params(
            self: @ContractState, collateral: ContractAddress
        ) -> CollateralParams {
            return self.collateral_params.read(collateral);
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
        fn get_default_redemption_block_timestamp(self: @ContractState) -> u64 {
            return REDEMPTION_BLOCK_TIMESTAMP_DEFAULT;
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        #[inline(always)]
        fn set_borrowing_fee_internal(
            ref self: ContractState,
            ref coll_params: CollateralParams,
            collateral: ContractAddress,
            borrowing_fee: u256
        ) {
            // min: 0% - max: 10%
            self.safe_check(@coll_params, 'Borrowing Fee', borrowing_fee, 0, ONE_HUNDRED_PCT / 10);

            let old_borrowing_fee = coll_params.borrowing_fee;
            coll_params.borrowing_fee = borrowing_fee;

            self.emit(BorrowingFeeUpdated { collateral, old_borrowing_fee, borrowing_fee });
        }

        #[inline(always)]
        fn set_ccr_internal(
            ref self: ContractState,
            ref coll_params: CollateralParams,
            collateral: ContractAddress,
            ccr: u256
        ) {
            // min: 100% - max: 1000%
            self.safe_check(@coll_params, 'CCR', ccr, ONE_HUNDRED_PCT, ONE_HUNDRED_PCT * 10);

            let old_ccr = coll_params.ccr;
            coll_params.ccr = ccr;

            self.emit(CCRUpdated { collateral, old_ccr, ccr });
        }

        #[inline(always)]
        fn set_mcr_internal(
            ref self: ContractState,
            ref coll_params: CollateralParams,
            collateral: ContractAddress,
            mcr: u256
        ) {
            // min: 101% - max: 1000%
            self
                .safe_check(
                    @coll_params, 'MCR', mcr, ONE_HUNDRED_PCT + pow(10, 16), ONE_HUNDRED_PCT * 10
                );
            let old_mcr = coll_params.mcr;
            coll_params.mcr = mcr;
            self.emit(MCRUpdated { collateral, old_mcr, mcr });
        }

        #[inline(always)]
        fn set_min_net_debt_internal(
            ref self: ContractState,
            ref coll_params: CollateralParams,
            collateral: ContractAddress,
            min_net_debt: u256
        ) {
            // min: 0 - max: 2_000
            self.safe_check(@coll_params, 'Min Net Debt', min_net_debt, 0, 2 * pow(10, 21));

            let old_min_net_debt = coll_params.min_net_debt;
            coll_params.min_net_debt = min_net_debt;

            self.emit(MinNetDebtUpdated { collateral, old_min_net_debt, min_net_debt });
        }

        #[inline(always)]
        fn set_mint_cap_internal(
            ref self: ContractState,
            ref coll_params: CollateralParams,
            collateral: ContractAddress,
            mint_cap: u256
        ) {
            let old_mint_cap = coll_params.mint_cap;
            coll_params.mint_cap = mint_cap;
            self.emit(MintCapUpdated { collateral, old_mint_cap, mint_cap });
        }

        #[inline(always)]
        fn set_percent_divisor_internal(
            ref self: ContractState,
            ref coll_params: CollateralParams,
            collateral: ContractAddress,
            percent_divisor: u256
        ) {
            // min: 2 - max: 200
            self.safe_check(@coll_params, 'Percent Divisor', percent_divisor, 2, 200);
            let old_percent_divisor = coll_params.percent_divisor;
            coll_params.percent_divisor = percent_divisor;
            self.emit(PercentDivisorUpdated { collateral, old_percent_divisor, percent_divisor });
        }

        #[inline(always)]
        fn set_redemption_fee_floor_internal(
            ref self: ContractState,
            ref coll_params: CollateralParams,
            collateral: ContractAddress,
            redemption_fee_floor: u256
        ) {
            self
                // min: 0.10% - max: 10%
                .safe_check(
                    @coll_params,
                    'Redemption Fee Floor',
                    redemption_fee_floor,
                    pow(10, 15),
                    pow(10, 17)
                );
            let old_redemption_fee_floor = coll_params.redemption_fee_floor;
            coll_params.redemption_fee_floor = redemption_fee_floor;
            self
                .emit(
                    RedemptionFeeFloorUpdated {
                        collateral, old_redemption_fee_floor, redemption_fee_floor
                    }
                );
        }

        #[inline(always)]
        fn set_redemption_block_timestamp_internal(
            ref self: ContractState,
            ref coll_params: CollateralParams,
            collateral: ContractAddress,
            block_timestamp: u64
        ) {
            let old_redemption_block_timestamp = coll_params.redemption_block_timestamp;
            coll_params.redemption_block_timestamp = block_timestamp;
            self
                .emit(
                    RedemptionBlockTimestampUpdated {
                        collateral,
                        old_redemption_block_timestamp,
                        redemption_block_timestamp: block_timestamp
                    }
                );
        }

        #[inline(always)]
        fn exist(self: @ContractState, collateral: ContractAddress) -> bool {
            return self.collateral_params.read(collateral).mcr.is_non_zero();
        }

        #[inline(always)]
        fn only_timelock(self: @ContractState) {
            let caller = get_caller_address();

            if (self.is_setup_initialized.read()) {
                assert(
                    caller == self.address_provider.read().get_address(AddressesKey::timelock),
                    CommunErrors::CommunErrors__OnlyTimelock
                );
                return;
            }
            assert(caller == self.ownable.owner(), CommunErrors::CommunErrors__OnlyOwner);
        }

        #[inline(always)]
        fn safe_check(
            self: @ContractState,
            coll_params: @CollateralParams,
            parameter: felt252,
            entered_value: u256,
            min: u256,
            max: u256
        ) {
            assert(*coll_params.is_active, Errors::AdminContract__CollateralNotActive);
            // Todo: refact with a panic(array![parameter, entered_value.try_into().unwrap(), min.try_into().unwrap(), max.try_into().unwrap()])
            assert(
                entered_value >= min && entered_value <= max, Errors::AdminContract__ValueOutOfRange
            );
        }
    }
}
