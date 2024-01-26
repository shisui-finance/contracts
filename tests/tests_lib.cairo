use snforge_std::{
    declare, start_prank, stop_prank, start_mock_call, stop_mock_call, ContractClassTrait,
    ContractClass, CheatTarget
};
use starknet::{ContractAddress, Felt252TryIntoContractAddress, contract_address_const};

use shisui::core::{
    borrower_operations::{IBorrowerOperationsDispatcher, IBorrowerOperationsDispatcherTrait},
    vessel_manager::{IVesselManagerDispatcher, IVesselManagerDispatcherTrait},
    address_provider::{IAddressProviderDispatcher, IAddressProviderDispatcherTrait, AddressesKey},
    admin_contract::{IAdminContractDispatcher, IAdminContractDispatcherTrait},
    fee_collector::{IFeeCollectorDispatcher, IFeeCollectorDispatcherTrait},
    debt_token::{IDebtTokenDispatcher, IDebtTokenDispatcherTrait},
    price_feed::{IPriceFeedDispatcher, IPriceFeedDispatcherTrait},
};
use shisui::mocks::pragma_oracle_mock::{
    IPragmaOracleMockDispatcher, IPragmaOracleMockDispatcherTrait
};
use shisui::pools::active_pool::{IActivePoolDispatcher, IActivePoolDispatcherTrait};
use shisui::pools::default_pool::{IDefaultPoolDispatcher, IDefaultPoolDispatcherTrait};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};


/// Utility function to pre-calculate the address of a mock contract & deploy it.
///
/// # Arguments
/// * `contract` - The contract class
/// * `calldata` - The calldata used for the contract constructor
///
/// # Returns
/// * `ContractAddress` - The pre-calculated address of the deployed contract
fn deploy_mock_contract(contract: ContractClass, calldata: @Array<felt252>) -> ContractAddress {
    let future_deployed_address = contract.precalculate_address(calldata);
    start_prank(CheatTarget::One(future_deployed_address), contract_address_const::<'caller'>());
    contract.deploy_at(calldata, future_deployed_address).unwrap()
}

/// Utility function to deploy a SafetyTransferMockContract contract and return its address.
///
/// # Returns
/// * `ContractAddress` - The address of the deployed data store contract.
fn deploy_safety_transfer_mock() -> ContractAddress {
    let contract = declare('SafetyTransferMockContract');
    deploy_mock_contract(contract, @array![])
}

/// Utility function to deploy a erc20 mock contract and return its address.
///
/// # Arguments
/// * `decimals` - The decimals of the erc20 mock contract.
///
/// # Returns
/// * `ContractAddress` - The address of the deployed data store contract.
fn deploy_erc20_mock(decimals: u8) -> ContractAddress {
    let contract = declare('ERC20Mock');
    deploy_mock_contract(contract, @array![decimals.into()])
}

/// Utility function to deploy a pragma oracle mock contract and return its address.
///
/// # Returns
///
/// * `ContractAddress` - The address of the deployed data store contract.
fn deploy_pragma_oracle_mock() -> ContractAddress {
    let contract = declare('PragmaOracleMock');
    deploy_mock_contract(contract, @array![])
}

/// Utility function to deploy a pragma oracle mock contract and return its address.
///
/// # Returns
///
/// * `ContractAddress` - The address of the deployed data store contract.
fn deploy_price_feed(
    address_provider: ContractAddress, pragma_contract: ContractAddress
) -> ContractAddress {
    let contract = declare('PriceFeed');
    deploy_mock_contract(contract, @array![address_provider.into(), pragma_contract.into()])
}


/// Utility function to deploy a AddressProvider contract and return its address.
///
/// # Arguments
/// * `address_provider` - The address of the address provider contract.
///
/// # Returns
/// * `ContractAddress` - The address of the deployed data store contract.
fn deploy_address_provider() -> ContractAddress {
    let contract = declare('AddressProvider');
    deploy_mock_contract(contract, @array![])
}

/// Utility function to deploy the AdminContract and return its address.
///
/// # Arguments
/// * `address_provider` - The address of the address provider contract.
///
/// # Returns
/// * `ContractAddress` - The address of the deployed data store contract.
fn deploy_admin_contract(address_provider: ContractAddress) -> ContractAddress {
    let contract = declare('AdminContract');
    deploy_mock_contract(contract, @array![address_provider.into()])
}

/// Utility function to deploy the StabilityPool contract and return its address.
///
/// # Arguments
/// * `address_provider` - The address of the address provider contract.
///
/// # Returns
/// * `ContractAddress` - The address of the deployed data store contract.
fn deploy_stability_pool(address_provider: ContractAddress) -> ContractAddress {
    let contract = declare('StabilityPool');
    deploy_mock_contract(contract, @array![address_provider.into()])
}

/// Utility function to deploy a CollateralSurplusPool contract and return its address.
///
/// # Returns
///
/// * `ContractAddress` - The address of the deployed data store contract.
fn deploy_collateral_surplus_pool(address_provider: ContractAddress) -> ContractAddress {
    let contract = declare('CollateralSurplusPool');
    deploy_mock_contract(contract, @array![address_provider.into()])
}

/// Utility function to deploy a DebtToken contract and return its address.
///
/// # Returns
///
/// * `ContractAddress` - The address of the deployed data store contract.
fn deploy_debt_token(address_provider: ContractAddress) -> ContractAddress {
    let contract = declare('DebtToken');
    deploy_mock_contract(contract, @array![address_provider.into()])
}

/// Utility function to deploy a FeeCollector contract and return its address.
///
/// # Returns
///
/// * `ContractAddress` - The address of the deployed data store contract.
fn deploy_fee_collector(address_provider: ContractAddress) -> ContractAddress {
    let contract = declare('FeeCollector');
    deploy_mock_contract(contract, @array![address_provider.into()])
}

/// Utility function to deploy a VesselManager contract and return its address.
///
/// # Returns
///
/// * `ContractAddress` - The address of the deployed data store contract.
fn deploy_vessel_manager(
    address_provider: ContractAddress,
    admin_contract: ContractAddress,
    debt_token: ContractAddress,
    fee_collector: ContractAddress
) -> ContractAddress {
    let contract = declare('VesselManager');
    deploy_mock_contract(
        contract,
        @array![
            address_provider.into(), admin_contract.into(), debt_token.into(), fee_collector.into()
        ]
    )
}

/// Utility function to deploy a ActivePool contract and return its address.
///
/// # Returns
///
/// * `ContractAddress` - The address of the deployed data store contract.
fn deploy_active_pool(address_provider: ContractAddress) -> ContractAddress {
    let contract = declare('ActivePool');
    deploy_mock_contract(contract, @array![address_provider.into()])
}

/// Utility function to deploy a DefaultPool contract and return its address.
///
/// # Returns
///
/// * `ContractAddress` - The address of the deployed data store contract.
fn deploy_default_pool(address_provider: ContractAddress) -> ContractAddress {
    let contract = declare('DefaultPool');
    deploy_mock_contract(contract, @array![address_provider.into()])
}

/// Utility function to deploy a GasPool contract and return its address.
///
/// # Returns
///
/// * `ContractAddress` - The address of the deployed data store contract.
fn deploy_gas_pool() -> ContractAddress {
    let contract = declare('GasPool');
    deploy_mock_contract(contract, @array![])
}


/// Utility function to deploy a BorrowerOperations contract and return its address.
///
/// # Returns
///
/// * `ContractAddress` - The address of the deployed data store contract.
fn deploy_borrower_operations(
    address_provider: ContractAddress,
    admin_contract: ContractAddress,
    price_feed: ContractAddress,
    vessel_manager: ContractAddress,
    debt_token: ContractAddress,
    fee_collector: ContractAddress,
    active_pool_address: ContractAddress,
    default_pool_address: ContractAddress,
    gas_pool_address: ContractAddress
) -> ContractAddress {
    let contract = declare('BorrowerOperations');
    deploy_mock_contract(
        contract,
        @array![
            address_provider.into(),
            admin_contract.into(),
            price_feed.into(),
            vessel_manager.into(),
            debt_token.into(),
            fee_collector.into(),
            active_pool_address.into(),
            default_pool_address.into(),
            gas_pool_address.into()
        ]
    )
}


fn deploy_main_contracts() -> (
    IBorrowerOperationsDispatcher,
    IVesselManagerDispatcher,
    IAddressProviderDispatcher,
    IAdminContractDispatcher,
    IFeeCollectorDispatcher,
    IDebtTokenDispatcher,
    IPriceFeedDispatcher,
    IPragmaOracleMockDispatcher,
    IActivePoolDispatcher,
    IDefaultPoolDispatcher,
    IERC20Dispatcher
) {
    // address provider
    let address_provider_address: ContractAddress = deploy_address_provider();
    let address_provider: IAddressProviderDispatcher = IAddressProviderDispatcher {
        contract_address: address_provider_address
    };

    // active pool
    let active_pool_address = deploy_active_pool(address_provider_address);
    let active_pool = IActivePoolDispatcher { contract_address: active_pool_address };

    // default pool
    let default_pool_address = deploy_default_pool(address_provider_address);
    let default_pool = IDefaultPoolDispatcher { contract_address: default_pool_address };

    // admin contract
    let admin_contract_address: ContractAddress = deploy_admin_contract(address_provider_address);
    let admin_contract: IAdminContractDispatcher = IAdminContractDispatcher {
        contract_address: admin_contract_address
    };

    // fee collector
    let fee_collector_address: ContractAddress = deploy_fee_collector(address_provider_address);
    let fee_collector: IFeeCollectorDispatcher = IFeeCollectorDispatcher {
        contract_address: fee_collector_address
    };

    // debt token
    let debt_token_address: ContractAddress = deploy_debt_token(address_provider_address);
    let debt_token: IDebtTokenDispatcher = IDebtTokenDispatcher {
        contract_address: debt_token_address
    };

    // vessel manager
    let vessel_manager_address: ContractAddress = deploy_vessel_manager(
        address_provider_address, admin_contract_address, fee_collector_address, debt_token_address
    );
    let vessel_manager: IVesselManagerDispatcher = IVesselManagerDispatcher {
        contract_address: vessel_manager_address
    };

    // price feed
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

    // gas pool 
    let gas_pool_address = deploy_gas_pool();

    // borrower operations
    let borrower_operations_address: ContractAddress = deploy_borrower_operations(
        address_provider_address,
        admin_contract_address,
        price_feed_address,
        vessel_manager_address,
        debt_token_address,
        fee_collector_address,
        active_pool_address,
        default_pool_address,
        gas_pool_address
    );
    let borrower_operations: IBorrowerOperationsDispatcher = IBorrowerOperationsDispatcher {
        contract_address: borrower_operations_address
    };

    //define address_provider address
    let stability_pool_address = deploy_stability_pool(address_provider_address);

    let timelock_address = contract_address_const::<'timelock'>();
    address_provider.set_address(AddressesKey::timelock, timelock_address);
    address_provider.set_address(AddressesKey::stability_pool, stability_pool_address);
    address_provider.set_address(AddressesKey::active_pool, active_pool_address);
    address_provider.set_address(AddressesKey::default_pool, default_pool_address);
    address_provider.set_address(AddressesKey::admin_contract, admin_contract_address);
    address_provider.set_address(AddressesKey::borrower_operations, borrower_operations_address);
    address_provider.set_address(AddressesKey::debt_token, debt_token_address);

    let asset_address: ContractAddress = deploy_erc20_mock(18);
    let asset: IERC20Dispatcher = IERC20Dispatcher { contract_address: asset_address };

    return (
        borrower_operations,
        vessel_manager,
        address_provider,
        admin_contract,
        fee_collector,
        debt_token,
        price_feed,
        pragma_mock,
        active_pool,
        default_pool,
        asset
    );
}
