use starknet::{ContractAddress, contract_address_const};

fn timelock_address() -> ContractAddress {
    return contract_address_const::<'timelock'>();
}

fn owner_address() -> ContractAddress {
    return contract_address_const::<'owner'>();
}

fn not_owner_address() -> ContractAddress {
    return contract_address_const::<'not_owner'>();
}
