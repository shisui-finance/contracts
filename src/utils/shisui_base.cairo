use starknet::ContractAddress;
use shisui::utils::{
    array::{StoreContractAddressArray, StoreU256Array}, constants::DECIMAL_PRECISION,
    shisui_math::compute_cr,
};
use shisui::core::{
    address_provider::{IAddressProviderDispatcher, IAddressProviderDispatcherTrait, AddressesKey},
    admin_contract::{IAdminContractDispatcher, IAdminContractDispatcherTrait}
};
use shisui::pools::{
    active_pool::{IActivePoolDispatcher, IActivePoolDispatcherTrait},
    default_pool::{IDefaultPoolDispatcher, IDefaultPoolDispatcherTrait}
};
use snforge_std::{PrintTrait};

#[derive(Drop, Clone, starknet::Store, Serde)]
struct Colls {
    tokens: Array<ContractAddress>,
    amounts: Array<u256>,
}

mod Errors {
    const ShisuiBaseErrors__ExceedFee: felt252 = 'Fee exceeded provided maximum';
}

// Returns the composite debt (drawn debt + gas compensation) of a vessel, for the purpose of ICR calculation
fn get_composite_debt(
    admin_contract: IAdminContractDispatcher, asset: ContractAddress, debt: u256
) -> u256 {
    return debt + admin_contract.get_debt_token_gas_compensation(asset);
}

fn get_net_debt(
    admin_contract: IAdminContractDispatcher, asset: ContractAddress, debt: u256
) -> u256 {
    return debt - admin_contract.get_debt_token_gas_compensation(asset);
}

// Return the amount of ETH to be drawn from a vessel's collateral and sent as gas compensation.
fn get_coll_gas_compensation(
    admin_contract: IAdminContractDispatcher, asset: ContractAddress, entire_coll: u256
) -> u256 {
    return entire_coll / admin_contract.get_percent_divisor(asset);
}

fn get_entire_system_coll(
    addres_provider: IAddressProviderDispatcher, asset: ContractAddress
) -> u256 {
    let active_coll = IActivePoolDispatcher {
        contract_address: addres_provider.get_address(AddressesKey::active_pool)
    }
        .get_asset_balance(asset);
    let liquidated_coll = IDefaultPoolDispatcher {
        contract_address: addres_provider.get_address(AddressesKey::default_pool)
    }
        .get_asset_balance(asset);
    return active_coll + liquidated_coll;
}

fn get_entire_system_debt(
    addres_provider: IAddressProviderDispatcher, asset: ContractAddress
) -> u256 {
    let active_debt = IActivePoolDispatcher {
        contract_address: addres_provider.get_address(AddressesKey::active_pool)
    }
        .get_debt_token_balance(asset);
    let closed_debt = IDefaultPoolDispatcher {
        contract_address: addres_provider.get_address(AddressesKey::default_pool)
    }
        .get_debt_token_balance(asset);
    return active_debt + closed_debt;
}

fn get_TCR(
    addres_provider: IAddressProviderDispatcher, asset: ContractAddress, price: u256
) -> u256 {
    let entire_system_coll = get_entire_system_coll(addres_provider, asset);
    let entire_system_debt = get_entire_system_debt(addres_provider, asset);
    return compute_cr(entire_system_coll, entire_system_debt, price);
}

fn check_recovery_mode(
    addres_provider: IAddressProviderDispatcher, asset: ContractAddress, price: u256
) -> bool {
    let tcr = get_TCR(addres_provider, asset, price);
    return tcr < IAdminContractDispatcher {
        contract_address: addres_provider.get_address(AddressesKey::admin_contract)
    }
        .get_ccr(asset);
}

fn assert_user_accepts_fee(fee: u256, amount: u256, max_fee_percentage: u256) {
    let fee_percentage = fee * DECIMAL_PRECISION / amount;
    assert(fee_percentage <= max_fee_percentage, Errors::ShisuiBaseErrors__ExceedFee);
}
