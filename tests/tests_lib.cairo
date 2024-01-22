use snforge_std::{
    declare, start_prank, stop_prank, start_mock_call, stop_mock_call, ContractClassTrait,
    ContractClass, CheatTarget
};
use starknet::{ContractAddress, Felt252TryIntoContractAddress, contract_address_const};


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
