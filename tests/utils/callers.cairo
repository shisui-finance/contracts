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

fn vessel_manager_address() -> ContractAddress {
    return contract_address_const::<'vessel_manager'>();
}

fn borrower_operation_address() -> ContractAddress {
    return contract_address_const::<'borrower_operation'>();
}

fn active_pool_address() -> ContractAddress {
    return contract_address_const::<'active_pool'>();
}

fn alice() -> ContractAddress {
    return contract_address_const::<'alice'>();
}

fn bob() -> ContractAddress {
    return contract_address_const::<'bob'>();
}
