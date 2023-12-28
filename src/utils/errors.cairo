mod CommunErrors {
    const CommunErrors__AddressZero: felt252 = 'Address is zero';
    const CommunErrors__CantBeZero: felt252 = 'Value is zero';
    const CommunErrors__OnlyTimelock: felt252 = 'Caller not Timelock';
    const CommunErrors__CallerNotAuthorized: felt252 = 'Caller is not authorized';
    const CommunErrors__Invalid_amount: felt252 = 'Invalid_amount';
}

mod DebtTokenErrors {
    const DebtTokenErrors__BurnAmountGtBalance: felt252 = 'Burn amount gt balance';
}

mod SortedVesselsErrors {
    const NodeAlreadyExists: felt252 = 'Node already exists';
    const NodeDoesntExist: felt252 = 'Node doesnt exist';
    const NICRMustBePositive: felt252 = 'NICR must be positive';
}
