use starknet::ContractAddress;

// *************************************************************************
//                              ENUM
// *************************************************************************
#[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
enum BorrowerOperation {
    OpenVessel,
    CloseVessel,
    AdjustVessel
}

// *************************************************************************
//                              STRUCT
// *************************************************************************
#[derive(Copy, Drop, Serde, starknet::Store)]
struct AdjustVessel {
    asset: ContractAddress,
    is_coll_increase: bool,
    price: u256,
    coll_change: u256,
    net_debt_change: u256,
    debt: u256,
    coll: u256,
    old_icr: u256,
    new_icr: u256,
    new_tcr: u256,
    debt_token_fee: u256,
    new_debt: u256,
    new_coll: u256,
    stake: u256,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct OpenVessel {
    asset: ContractAddress,
    price: u256,
    debt_token_fee: u256,
    net_debt: u256,
    composite_debt: u256,
    icr: u256,
    nicr: u256,
    stake: u256,
    array_index: u32,
}


#[starknet::interface]
trait IBorrowerOperations<TContractState> {
    fn open_vessel(
        ref self: TContractState,
        asset: ContractAddress,
        asset_amount: u256,
        debt_token_amount: u256,
        upper_hint: ContractAddress,
        lower_hint: ContractAddress
    );
}

#[starknet::contract]
mod BorrowerOperations {
    use core::traits::Into;
    use starknet::{
        ContractAddress, contract_address_const, get_caller_address, get_contract_address,
        get_block_timestamp,
    };
    use openzeppelin::security::reentrancyguard::ReentrancyGuardComponent::InternalTrait;
    use openzeppelin::security::reentrancyguard::ReentrancyGuardComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use super::{BorrowerOperation, AdjustVessel, OpenVessel};
    use shisui::core::address_provider::{
        IAddressProviderDispatcher, IAddressProviderDispatcherTrait, AddressesKey
    };
    use shisui::core::admin_contract::{IAdminContractDispatcher, IAdminContractDispatcherTrait,};
    use shisui::core::price_feed::{IPriceFeedDispatcher, IPriceFeedDispatcherTrait,};
    use shisui::core::debt_token::{IDebtTokenDispatcher, IDebtTokenDispatcherTrait,};
    use shisui::core::fee_collector::{IFeeCollectorDispatcher, IFeeCollectorDispatcherTrait,};
    use shisui::pools::vessel_manager::{IVesselManagerDispatcher, IVesselManagerDispatcherTrait};
    use shisui::pools::active_pool::{IActivePoolDispatcher, IActivePoolDispatcherTrait,};
    use shisui::pools::default_pool::{IDefaultPoolDispatcher, IDefaultPoolDispatcherTrait,};
    use shisui::utils::{
        shisui_math, shisui_base, constants::DECIMAL_PRECISION, convert::decimals_correction
    };

    use snforge_std::PrintTrait;

    // *************************************************************************
    //                              COMPONENTS
    // *************************************************************************
    component!(
        path: ReentrancyGuardComponent, storage: reentrancy_guard, event: ReentrancyGuardEvent
    );
    impl ReentrancyGuardInternalImpl = ReentrancyGuardComponent::InternalImpl<ContractState>;

    // *************************************************************************
    //                              ERRORS
    // *************************************************************************
    mod Errors {
        const BorrowerOperations_AssetNotActive: felt252 = 'Asset is not active';
        const BorrowerOperations_ActiveVessel: felt252 = 'Vessel is active';
        const BorrowerOperations_NetDebtMustBeGreaterThanMin: felt252 =
            'net debt must be great than min';
        const BorrowerOperations_CompositeDebtCantBeZero: felt252 = 'Composite debt cannot be 0';
        const BorrowerOperations_VesselICRMustbeGOECCR: felt252 = 'Vessel must have ICR >= CCR';
        const BorrowerOperations_VesselTCRMustbeGOECCR: felt252 = 'Vessel must have TCR >= CCR';
        const BorrowerOperations_VesselICRMustbeGOEMCR: felt252 = 'Vessel must have ICR >= MCR';
        const BorrowerOperations_ExceedsMintCap: felt252 = 'Exceeds mint cap';
    }

    // *************************************************************************
    //                              STORAGE
    // *************************************************************************
    #[storage]
    struct Storage {
        #[substorage(v0)]
        reentrancy_guard: ReentrancyGuardComponent::Storage,
        address_provider: IAddressProviderDispatcher,
        admin_contract: IAdminContractDispatcher,
        price_feed: IPriceFeedDispatcher,
        vessel_manager: IVesselManagerDispatcher,
        debt_token: IDebtTokenDispatcher,
        fee_collector: IFeeCollectorDispatcher,
        active_pool: IActivePoolDispatcher,
        default_pool: IDefaultPoolDispatcher,
        gas_pool_address: ContractAddress
    }

    // *************************************************************************
    //                              EVENT
    // *************************************************************************
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ReentrancyGuardEvent: ReentrancyGuardComponent::Event,
        BorrowingFeePaid: BorrowingFeePaid,
        VesselCreated: VesselCreated,
        VesselUpdated: VesselUpdated
    }

    #[derive(Drop, starknet::Event)]
    struct BorrowingFeePaid {
        #[key]
        asset: ContractAddress,
        borrower: ContractAddress,
        fee_amount: u256
    }

    #[derive(Drop, starknet::Event)]
    struct VesselCreated {
        #[key]
        asset: ContractAddress,
        borrower: ContractAddress,
        array_index: u256
    }

    #[derive(Drop, starknet::Event)]
    struct VesselUpdated {
        #[key]
        asset: ContractAddress,
        #[key]
        borrower: ContractAddress,
        debt: u256,
        coll: u256,
        stake: u256,
        operation: BorrowerOperation,
    }

    // *************************************************************************
    //                              CONSTRUCTOR
    // *************************************************************************
    #[constructor]
    fn constructor(
        ref self: ContractState,
        address_provider: ContractAddress,
        admin_contract: ContractAddress,
        price_feed: ContractAddress,
        vessel_manager: ContractAddress,
        debt_token: ContractAddress,
        fee_collector: ContractAddress,
        active_pool: ContractAddress,
        default_pool: ContractAddress,
        gas_pool_address: ContractAddress
    ) {
        self
            .address_provider
            .write(IAddressProviderDispatcher { contract_address: address_provider });

        self.admin_contract.write(IAdminContractDispatcher { contract_address: admin_contract });
        self.price_feed.write(IPriceFeedDispatcher { contract_address: price_feed });
        self.vessel_manager.write(IVesselManagerDispatcher { contract_address: vessel_manager });
        self.debt_token.write(IDebtTokenDispatcher { contract_address: debt_token });
        self.fee_collector.write(IFeeCollectorDispatcher { contract_address: fee_collector });
        self.active_pool.write(IActivePoolDispatcher { contract_address: active_pool });
        self.default_pool.write(IDefaultPoolDispatcher { contract_address: default_pool });
        self.gas_pool_address.write(gas_pool_address);
    }

    // *************************************************************************
    //                              EXTERNAL FUNCTIONS
    // *************************************************************************
    #[external(v0)]
    impl BorrowerOperationsImpl of super::IBorrowerOperations<ContractState> {
        fn open_vessel(
            ref self: ContractState,
            asset: ContractAddress,
            asset_amount: u256,
            debt_token_amount: u256,
            upper_hint: ContractAddress,
            lower_hint: ContractAddress
        ) {
            assert(
                self.admin_contract.read().get_is_active(asset),
                Errors::BorrowerOperations_AssetNotActive
            );

            let price = self.price_feed.read().fetch_price(asset);

            let is_recovery_mode = shisui_base::check_recovery_mode(
                self.address_provider.read(), asset, price
            );

            self.require_vessel_not_active(asset, get_caller_address());

            let mut net_debt = debt_token_amount;
            let mut debt_token_fee = 0;

            if !is_recovery_mode {
                debt_token_fee = self.trigger_borrowing_fee(asset, debt_token_amount);

                net_debt = net_debt + debt_token_fee;
            }

            self.require_at_least_min_net_debt(asset, net_debt);

            // ICR is based on the composite debt, i.e. the requested debt token amount + borrowing fee + gas comp.
            let gas_compensation = self
                .admin_contract
                .read()
                .get_debt_token_gas_compensation(asset);

            let composite_debt = net_debt + gas_compensation;

            assert(composite_debt != 0, Errors::BorrowerOperations_CompositeDebtCantBeZero);

            let icr = shisui_math::compute_cr(asset_amount, composite_debt, price);

            let nicr = shisui_math::compute_nominal_cr(asset_amount, composite_debt);

            if is_recovery_mode {
                self.require_icr_is_above_ccr(asset, icr);
            } else {
                self.require_icr_is_above_mcr(asset, icr);

                let new_tcr = self
                    .get_new_tcr_from_vessel_change(
                        asset, asset_amount, true, composite_debt, true, price
                    );
                self.require_new_tcr_is_above_ccr(asset, new_tcr);
            }

            // Set the vessel struct's properties
            self
                .vessel_manager
                .read()
                .set_vessel_status(
                    asset, get_caller_address(), shisui::pools::vessel_manager::Status::Active
                );

            self
                .vessel_manager
                .read()
                .increase_vessel_coll(asset, get_caller_address(), asset_amount);

            self
                .vessel_manager
                .read()
                .increase_vessel_debt(asset, get_caller_address(), composite_debt);

            self.vessel_manager.read().update_vessel_reward_snapshots(asset, get_caller_address());
            let stake = self
                .vessel_manager
                .read()
                .update_stake_and_total_stakes(asset, get_caller_address());

            let array_index = self
                .vessel_manager
                .read()
                .add_vessel_owner_to_array(asset, get_caller_address());

            // TODO insert sortedVessel     
            //ISortedVessels(sortedVessels).insert(vars.asset, msg.sender, vars.NICR, _upperHint, _lowerHint);

            self.emit(VesselCreated { asset, borrower: get_caller_address(), array_index });
            // Move the asset to the Active Pool, and mint the debtToken amount to the borrower
            self.active_pool_add_coll(asset, asset_amount);
            self.withdraw_debt_token(asset, get_caller_address(), debt_token_amount, net_debt);
            // Move the debtToken gas compensation to the Gas Pool
            if gas_compensation != 0 {
                self
                    .withdraw_debt_token(
                        asset, self.gas_pool_address.read(), gas_compensation, gas_compensation
                    );
            }

            self
                .emit(
                    VesselUpdated {
                        asset,
                        borrower: get_caller_address(),
                        debt: composite_debt,
                        coll: asset_amount,
                        stake,
                        operation: BorrowerOperation::OpenVessel
                    }
                );
            self
                .emit(
                    BorrowingFeePaid {
                        asset, borrower: get_caller_address(), fee_amount: debt_token_fee
                    }
                );
        }
    }

    // *************************************************************************
    //                              INTERNAL FUNCTIONS
    // *************************************************************************
    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn require_vessel_not_active(
            self: @ContractState, asset: ContractAddress, borrower: ContractAddress
        ) {
            let status = self.vessel_manager.read().get_vessel_status(asset, borrower);

            assert(
                status != shisui::pools::vessel_manager::Status::Active,
                Errors::BorrowerOperations_ActiveVessel
            );
        }

        fn trigger_borrowing_fee(
            ref self: ContractState, asset: ContractAddress, debt_token_amount: u256
        ) -> u256 {
            let debt_token_fee = self
                .vessel_manager
                .read()
                .get_borrowing_fee(asset, debt_token_amount);
            //TODO check in vessel manager -> emergencyStopMintingCollateral
            self.debt_token.read().mint(get_caller_address(), debt_token_fee);
            self.fee_collector.read().increase_debt(get_caller_address(), asset, debt_token_fee);
            debt_token_fee
        }

        fn require_at_least_min_net_debt(
            self: @ContractState, asset: ContractAddress, net_debt: u256
        ) {
            let min_debt = self.admin_contract.read().get_min_net_debt(asset);

            assert(
                net_debt >= self.admin_contract.read().get_min_net_debt(asset),
                Errors::BorrowerOperations_NetDebtMustBeGreaterThanMin
            );
        }

        fn require_icr_is_above_mcr(self: @ContractState, asset: ContractAddress, new_icr: u256) {
            assert(
                new_icr >= self.admin_contract.read().get_mcr(asset),
                Errors::BorrowerOperations_VesselICRMustbeGOEMCR
            );
        }

        fn require_icr_is_above_ccr(self: @ContractState, asset: ContractAddress, new_icr: u256) {
            assert(
                new_icr >= self.admin_contract.read().get_ccr(asset),
                Errors::BorrowerOperations_VesselICRMustbeGOECCR
            );
        }

        fn require_new_tcr_is_above_ccr(
            self: @ContractState, asset: ContractAddress, new_tcr: u256
        ) {
            assert(
                new_tcr >= self.admin_contract.read().get_ccr(asset),
                Errors::BorrowerOperations_VesselTCRMustbeGOECCR
            );
        }

        fn get_new_tcr_from_vessel_change(
            self: @ContractState,
            asset: ContractAddress,
            coll_change: u256,
            is_coll_increase: bool,
            debt_change: u256,
            is_debt_increase: bool,
            price: u256
        ) -> u256 {
            let mut total_coll: u256 = shisui_base::get_entire_system_coll(
                self.address_provider.read(), asset
            );

            let mut total_debt = shisui_base::get_entire_system_debt(
                self.address_provider.read(), asset
            );

            total_coll =
                if is_coll_increase {
                    total_coll + coll_change
                } else {
                    total_coll - coll_change
                };

            total_debt =
                if is_debt_increase {
                    total_debt + debt_change
                } else {
                    total_debt - debt_change
                };

            let new_tcr = shisui_math::compute_cr(total_coll, total_debt, price);
            new_tcr
        }

        fn active_pool_add_coll(ref self: ContractState, asset: ContractAddress, amount: u256) {
            let safety_transfer_amount = decimals_correction(asset, amount);
            self.active_pool.read().received_erc20(asset, amount);
            IERC20Dispatcher { contract_address: asset }
                .transfer_from(get_caller_address(), self.active_pool.read().contract_address, 1);
        }

        fn withdraw_debt_token(
            ref self: ContractState,
            asset: ContractAddress,
            account: ContractAddress,
            debt_token_amount: u256,
            net_debt_increase: u256
        ) {
            let new_total_asset_debt = self.active_pool.read().get_debt_token_balance(asset)
                + self.default_pool.read().get_debt_token_balance(asset)
                + net_debt_increase;
            assert(
                new_total_asset_debt <= self.admin_contract.read().get_mint_cap(asset),
                Errors::BorrowerOperations_ExceedsMintCap
            );
            self.active_pool.read().increase_debt(asset, net_debt_increase);
            self.debt_token.read().mint(account, debt_token_amount);
        }
    }
}
