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
    use openzeppelin::access::ownable::OwnableComponent;


    use shisui::utils::{
        constants::DECIMAL_PRECISION, array::StoreContractAddressArray, errors::CommunErrors,
        math::pow
    };
    use shisui::core::address_provider::{
        IAddressProviderDispatcher, IAddressProviderDispatcherTrait, AddressesKey
    };
    use shisui::pools::stability_pool::{IStabilityPoolDispatcher, IStabilityPoolDispatcherTrait};
    use super::CollateralParams;


    use snforge_std::PrintTrait;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    const _100_pct: u256 = 1_000_000_000_000_000_000; // 1e18 == 100%
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
            self.set_is_active(collateral, true);
            self.set_borrowing_fee(collateral, borrowing_fee);
            self.set_ccr(collateral, ccr);
            self.set_mcr(collateral, mcr);
            self.set_min_net_debt(collateral, min_net_debt);
            self.set_mint_cap(collateral, mint_cap);
            self.set_percent_divisor(collateral, percent_divisor);
            self.set_redemption_fee_floor(collateral, redemption_fee_floor);
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
            self
                .safe_check(
                    'Borrowing Fee', collateral, borrowing_fee, 0, _100_pct / 10
                ); // 0% - 10%
            let mut params = self.collateral_params.read(collateral);
            let old_borrowing_fee = params.borrowing_fee;
            params.borrowing_fee = borrowing_fee;
            self.collateral_params.write(collateral, params);
            self.emit(BorrowingFeeUpdated { collateral, old_borrowing_fee, borrowing_fee });
        }

        fn set_ccr(ref self: ContractState, collateral: ContractAddress, ccr: u256) {
            self.only_timelock();
            self.safe_check('CCR', collateral, ccr, _100_pct, _100_pct * 10); // 100% - 1000%
            let mut params = self.collateral_params.read(collateral);
            let old_ccr = params.ccr;
            params.ccr = ccr;
            self.collateral_params.write(collateral, params);
            self.emit(CCRUpdated { collateral, old_ccr, ccr });
        }

        fn set_mcr(ref self: ContractState, collateral: ContractAddress, mcr: u256) {
            self.only_timelock();
            self
                .safe_check(
                    'MCR', collateral, mcr, _100_pct + pow(10, 16), _100_pct * 10
                ); // 101% - 1000%
            let mut params = self.collateral_params.read(collateral);
            let old_mcr = params.mcr;
            params.mcr = mcr;
            self.collateral_params.write(collateral, params);
            self.emit(MCRUpdated { collateral, old_mcr, mcr });
        }

        fn set_min_net_debt(
            ref self: ContractState, collateral: ContractAddress, min_net_debt: u256
        ) {
            self.only_timelock();
            self
                .safe_check(
                    'Min Net Debt', collateral, min_net_debt, 0, 2 * pow(10, 21)
                ); // 0 - 2_000
            let mut params = self.collateral_params.read(collateral);
            let old_min_net_debt = params.min_net_debt;
            params.min_net_debt = min_net_debt;
            self.collateral_params.write(collateral, params);
            self.emit(MinNetDebtUpdated { collateral, old_min_net_debt, min_net_debt });
        }

        fn set_mint_cap(ref self: ContractState, collateral: ContractAddress, mint_cap: u256) {
            self.only_timelock();
            assert(self.exist(collateral), Errors::AdminContract__CollateralNotExist);
            let mut params = self.collateral_params.read(collateral);
            let old_mint_cap = params.mint_cap;
            params.mint_cap = mint_cap;
            self.collateral_params.write(collateral, params);
            self.emit(MintCapUpdated { collateral, old_mint_cap, mint_cap });
        }

        fn set_percent_divisor(
            ref self: ContractState, collateral: ContractAddress, percent_divisor: u256
        ) {
            self.only_timelock();
            self.safe_check('Percent Divisor', collateral, percent_divisor, 2, 200);
            let mut params = self.collateral_params.read(collateral);
            let old_percent_divisor = params.percent_divisor;
            params.percent_divisor = percent_divisor;
            self.collateral_params.write(collateral, params);
            self.emit(PercentDivisorUpdated { collateral, old_percent_divisor, percent_divisor });
        }

        fn set_redemption_fee_floor(
            ref self: ContractState, collateral: ContractAddress, redemption_fee_floor: u256
        ) {
            self.only_timelock();
            self
                .safe_check(
                    'Redemption Fee Floor',
                    collateral,
                    redemption_fee_floor,
                    pow(10, 15),
                    pow(10, 17)
                ); // min: 0.10% - max: 10%
            let mut params = self.collateral_params.read(collateral);
            let old_redemption_fee_floor = params.redemption_fee_floor;
            params.redemption_fee_floor = redemption_fee_floor;
            self.collateral_params.write(collateral, params);
            self
                .emit(
                    RedemptionFeeFloorUpdated {
                        collateral, old_redemption_fee_floor, redemption_fee_floor
                    }
                );
        }

        fn set_redemption_block_timestamp(
            ref self: ContractState, collateral: ContractAddress, block_timestamp: u64
        ) {
            self.only_timelock();
            assert(self.exist(collateral), Errors::AdminContract__CollateralNotExist);
            let mut params = self.collateral_params.read(collateral);
            let old_redemption_block_timestamp = params.redemption_block_timestamp;
            params.redemption_block_timestamp = block_timestamp;
            self.collateral_params.write(collateral, params);
            self
                .emit(
                    RedemptionBlockTimestampUpdated {
                        collateral,
                        old_redemption_block_timestamp,
                        redemption_block_timestamp: block_timestamp
                    }
                );
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
            return 0;
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
            parameter: felt252,
            collateral: ContractAddress,
            entered_value: u256,
            min: u256,
            max: u256
        ) {
            assert(
                self.collateral_params.read(collateral).is_active,
                Errors::AdminContract__CollateralNotActive
            );
            // Todo: refact with a panic passing all the info
            assert(
                entered_value >= min && entered_value <= max, Errors::AdminContract__ValueOutOfRange
            );
        }
    }
}
