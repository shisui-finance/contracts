mod CommunErrors {
    const AddressZero: felt252 = 'Address is zero';
    const CantBeZero: felt252 = 'Value is zero';
    const OnlyTimelock: felt252 = 'Caller not Timelock';
    const CallerNotAuthorized: felt252 = 'Caller not authorized';
    const Invalid_amount: felt252 = 'Amount Invalid';
}

mod DebtTokenErrors {
    const DebtTokenErrors__BurnAmountGtBalance: felt252 = 'Burn amount gt balance';
}

mod SortedVesselsErrors {
    const NodeAlreadyExists: felt252 = 'Node already exists';
    const NodeDoesntExist: felt252 = 'Node doesnt exist';
    const NICRMustBePositive: felt252 = 'NICR must be positive';
}
