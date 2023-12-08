use core::traits::TryInto;
use snforge_std::{
    declare, start_prank, stop_prank, start_mock_call, stop_mock_call, ContractClassTrait,
    ContractClass, CheatTarget
};
use starknet::{ContractAddress, Felt252TryIntoContractAddress, contract_address_const};
use shisui::core::timelock::{ITimelockDispatcher, ITimelockDispatcherTrait};


/// Utility function to pre-calculate the address of a mock contract & deploy it.
///
/// # Arguments
///
/// * `contract` - The contract class
/// * `calldata` - The calldata used for the contract constructor
///
/// # Returns
///
/// * `ContractAddress` - The pre-calculated address of the deployed contract
fn deploy_mock_contract_precalc_address(contract: ContractClass, calldata: @Array<felt252>) -> ContractAddress {
    let future_deployed_address = contract.precalculate_address(calldata);
    start_prank(CheatTarget::One(future_deployed_address), contract_address_const::<'caller'>());
    contract.deploy_at(calldata, future_deployed_address).unwrap()
}

/// Utility function to deploy a SafetyTransferMockContract contract and return its address.
///
/// # Returns
///
/// * `ContractAddress` - The address of the deployed data store contract.
fn deploy_safety_transfer_mock() -> ContractAddress {
    let contract = declare('SafetyTransferMockContract');
    deploy_mock_contract(contract, @array![])
}

/// Utility function to deploy a erc20 mock contract and return its address.
///
/// # Returns
///
/// * `ContractAddress` - The address of the deployed data store contract.
fn deploy_erc20_mock(decimals: u8) -> ContractAddress {
    let contract = declare('ERC20Mock');
    let constructor_calldata = array![decimals.into()];
    deploy_mock_contract(contract, @constructor_calldata)
}


/// Utility function to deploy a AddressProvider contract and return its address.
///
/// # Returns
///
/// * `ContractAddress` - The address of the deployed data store contract.
fn deploy_address_provider() -> ContractAddress {
    let contract = declare('AddressProvider');
    let constructor_calldata = array![];
    deploy_mock_contract(contract, @constructor_calldata)
}

/// Utility function to deploy a simple storage mock contract and return its address.
///
/// # Returns
///
/// * `ContractAddress` - The address of the deployed data store contract.
fn deploy_simple_storage_mock() -> ContractAddress {
    let contract = declare('SimpleStorage');
    deploy_mock_contract(contract, @array![])
}

/// Utility function to deploy timelock contract and return its address.
///
/// # Returns
///
/// * `ContractAddress` - The address of the deployed data store contract.
fn deploy_timelock_mock(
    _delay: u256, _admin: ContractAddress
) -> (ITimelockDispatcher, ContractAddress) {
    let contract = declare('Timelock');
    let constructor_calldata = array![_delay.low.into(), _delay.high.into(), _admin.into()];
    let timelock_address = deploy_mock_contract(contract, @constructor_calldata);
    (ITimelockDispatcher { contract_address: timelock_address }, timelock_address)
}


/// Utility function to pre-calculate the address of a mock contract & deploy it.
///
/// # Arguments
///
/// * `contract` - The contract class
/// * `calldata` - The calldata used for the contract constructor
///
/// # Returns
///
/// * `ContractAddress` - The pre-calculated address of the deployed contract
fn deploy_mock_contract(contract: ContractClass, calldata: @Array<felt252>) -> ContractAddress {
    //let future_deployed_address = contract.precalculate_address(calldata);
    //start_prank(CheatTarget::One(future_deployed_address), contract_address_const::<'caller'>());
    contract.deploy(calldata).unwrap()
}
