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

fn vessel_manager_operations_address() -> ContractAddress {
    return contract_address_const::<'vessel_manager_operations'>();
}

fn borrower_operations_address() -> ContractAddress {
    return contract_address_const::<'borrower_operations'>();
}

fn active_pool_address() -> ContractAddress {
    return contract_address_const::<'active_pool'>();
}

fn treasury_address() -> ContractAddress {
    return contract_address_const::<'treasury'>();
}

fn default_pool_address() -> ContractAddress {
    return contract_address_const::<'default_pool'>();
}

fn stability_pool_address() -> ContractAddress {
    return contract_address_const::<'stability_pool'>();
}

fn borrower() -> ContractAddress {
    return contract_address_const::<'borrower'>();
}

fn alice() -> ContractAddress {
    return contract_address_const::<'alice'>();
}


fn bob() -> ContractAddress {
    return contract_address_const::<'bob'>();
}
