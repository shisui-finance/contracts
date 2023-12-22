use starknet::ContractAddress;
use shisui::utils::errors::CommunErrors;

fn assert_address_non_zero(address: ContractAddress) {
    assert(address.is_non_zero(), CommunErrors::CommunErrors__AddressZero);
}