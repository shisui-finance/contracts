use starknet::{ContractAddress, contract_address_const};
use traits::{Into, TryInto};
use shisui::core::{
    address_provider::{IAddressProviderDispatcher, IAddressProviderDispatcherTrait, AddressesKey},
    debt_token::{IDebtTokenDispatcher, IDebtTokenDispatcherTrait},
    fee_collector::{IFeeCollectorDispatcher, IFeeCollectorDispatcherTrait}
};
use shisui::utils::constants::ONE;
use tests::tests_lib::{deploy_address_provider, deploy_debt_token, deploy_fee_collector};
use tests::utils::{
    callers::{
        vessel_manager_address, timelock_address, treasury_address, borrower_operations_address
    },
    constant::{MAX_FEE_FRACTION, MIN_FEE_FRACTION, FEE_EXPIRATION_SECONDS}
};

fn setup() -> (
    IAddressProviderDispatcher, IFeeCollectorDispatcher, ContractAddress, ContractAddress
) {
    let address_provider_address: ContractAddress = deploy_address_provider();
    let address_provider: IAddressProviderDispatcher = IAddressProviderDispatcher {
        contract_address: address_provider_address
    };

    let debt_token_address: ContractAddress = deploy_debt_token(address_provider_address);
    let debt_token: IDebtTokenDispatcher = IDebtTokenDispatcher {
        contract_address: debt_token_address
    };
    let fee_collector_address: ContractAddress = deploy_fee_collector(address_provider_address);
    let fee_collector: IFeeCollectorDispatcher = IFeeCollectorDispatcher {
        contract_address: fee_collector_address
    };
    debt_token.add_whitelist(fee_collector_address);

    address_provider.set_address(AddressesKey::debt_token, debt_token_address);
    address_provider.set_address(AddressesKey::timelock, timelock_address());
    address_provider.set_address(AddressesKey::vessel_manager, vessel_manager_address());
    address_provider.set_address(AddressesKey::borrower_operations, borrower_operations_address());
    address_provider.set_address(AddressesKey::treasury, treasury_address());
    let asset_address = contract_address_const::<'asset'>();
    return (address_provider, fee_collector, debt_token_address, asset_address);
}

fn calc_fees(debt_amount: u256) -> (u256, u256) {
    let max_fee: u256 = (MAX_FEE_FRACTION * debt_amount) / ONE;
    let min_fee: u256 = (MIN_FEE_FRACTION * max_fee) / ONE;
    return (min_fee, max_fee);
}

fn calc_new_duration(
    remaining_amount: u256, remaining_time_to_live: u64, added_amount: u256
) -> u64 {
    let prev_weight = remaining_amount * remaining_time_to_live.into();
    let next_weight = added_amount * FEE_EXPIRATION_SECONDS.into();
    return ((prev_weight + next_weight) / (remaining_amount + added_amount)).try_into().unwrap();
}

fn calc_expired_amount(now: u64, from: u64, to: u64, amount: u256) -> u256 {
    if (from > now) {
        return 0;
    }
    if (now >= to) {
        return amount;
    }
    let decay_rate = (amount * 1_000000000) / (to - from).into();
    return ((now - from).into() * decay_rate) / 1_000000000;
}
