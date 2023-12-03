use starknet::ContractAddress;


#[starknet::interface]
trait IDebtToken<TContractState> {
    fn emergency_stop_minting(ref self: TContractState, _delay: u256);

    fn mint(
        ref self: TContractState, _asset: ContractAddress, _account: ContractAddress, _amount: u256
    );

    fn mint_from_whitelisted_contract(ref self: TContractState, _amount: u256);

    fn burn_from_whitelisted_contract(ref self: TContractState, _amount: u256);

    fn burn(ref self: TContractState, _account: ContractAddress, _amount: u256);

    fn send_to_pool(
        ref self: TContractState,
        _sender: ContractAddress,
        poolAddress: ContractAddress,
        _amount: u256
    );

    fn return_from_pool(
        ref self: TContractState, poolAddress: ContractAddress, user: ContractAddress, _amount: u256
    );

    fn add_whitelist(ref self: TContractState, _address: ContractAddress);

    fn remove_whitelist(ref self: TContractState, _address: ContractAddress);

    fn transfer(ref self: TContractState, _recipient: ContractAddress, _amount: u256);

    fn transfer_from(
        ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    );
}


#[starknet::contract]
mod DebtToken {
    use starknet::ContractAddress;


    #[storage]
    struct Storage {
        address_provider: ContractAddress,
        emergency_stop_minting_collateral: LegacyMap::<ContractAddress, bool>,
        whitelisted_contracts: LegacyMap::<ContractAddress, bool>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, address_provider: ContractAddress) {}


    #[external(v0)]
    impl DebtTokenImpl of super::IDebtToken<ContractState> {
        fn emergency_stop_minting(ref self: ContractState, _delay: u256) {}

        fn mint(
            ref self: ContractState,
            _asset: ContractAddress,
            _account: ContractAddress,
            _amount: u256
        ) {}

        fn mint_from_whitelisted_contract(ref self: ContractState, _amount: u256) {}

        fn burn_from_whitelisted_contract(ref self: ContractState, _amount: u256) {}

        fn burn(ref self: ContractState, _account: ContractAddress, _amount: u256) {}

        fn send_to_pool(
            ref self: ContractState,
            _sender: ContractAddress,
            poolAddress: ContractAddress,
            _amount: u256
        ) {}

        fn return_from_pool(
            ref self: ContractState,
            poolAddress: ContractAddress,
            user: ContractAddress,
            _amount: u256
        ) {}

        fn add_whitelist(ref self: ContractState, _address: ContractAddress) {}

        fn remove_whitelist(ref self: ContractState, _address: ContractAddress) {}

        fn transfer(ref self: ContractState, _recipient: ContractAddress, _amount: u256) {}

        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {}
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn require_valid_recipient(_recipient: ContractAddress) {}
        fn require_caller_is_whitelisted_contract() {}
        fn require_caller_is_borrower_operations() {}
        fn require_caller_is_bo_or_vesselm_or_sp() {}
        fn require_caller_is_stability_pool() {}
        fn require_caller_is_vesselm_or_sp() {}
    }
}
