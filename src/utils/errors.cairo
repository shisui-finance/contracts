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
