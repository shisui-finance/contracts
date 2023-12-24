use starknet::ContractAddress;


#[starknet::interface]
trait ITimelock<TContractState> {
    fn set_delay(ref self: TContractState, _delay: u256);
    fn accept_admin(ref self: TContractState);
    fn set_pending_admin(ref self: TContractState, _pending_admin: ContractAddress);
    fn queue_transaction(
        ref self: TContractState,
        _target: ContractAddress,
        _value: u256,
        _signature: felt252,
        _data: Span<felt252>,
        _eta: u256,
    ) -> felt252;
    fn cancel_transaction(
        ref self: TContractState,
        _target: ContractAddress,
        _value: u256,
        _signature: felt252,
        _data: Span<felt252>,
        _eta: u256,
    );
    fn execute_transaction(
        ref self: TContractState,
        _target: ContractAddress,
        _value: u256,
        _signature: felt252,
        _data: Span<felt252>,
        _eta: u256,
    ) -> felt252;
}


#[starknet::contract]
mod Timelock {
    use starknet::ContractAddress;

    const MINIMUM_DELAY: u256 = 172_800; // 2 days
    const MAXIMUM_DELAY: u256 = 1_296_000; // 15 days
    const GRACE_PERIOD: u256 = 1_209_600; // 14 days

    #[storage]
    struct Storage {
        admin: ContractAddress,
        pending_admin: ContractAddress,
        delay: u256,
        queued_transactions: LegacyMap::<felt252, bool>,
    }

    mod TimelockErrors {
        const DelayMustExceedMininumDelay: felt252 = 'Delay must exceed mininum delay';
        const DelayMustNotExceedMaximumDelay: felt252 = 'Delay must under maximum delay';
        const TimelockOnly: felt252 = 'Timelock only';
        const PendingAdminOnly: felt252 = 'Pending admin only';
        const AdminOnly: felt252 = 'Admin only';
        const ETAMustSatisfyDelay: felt252 = 'ETA must satisfy delay';
        const TxNoQueued: felt252 = 'Tx no queued';
        const TxAlreadyQueued: felt252 = 'Tx already queued';
        const TxStillLocked: felt252 = 'Tx still locked';
        const TxExpired: felt252 = 'Tx expired';
        const TxReverted: felt252 = 'Tx reverted';
    }


    #[constructor]
    fn constructor(ref self: ContractState, _delay: u256, _admin: ContractAddress) {}

    #[external(v0)]
    impl TimelockImpl of super::ITimelock<ContractState> {
        fn set_delay(ref self: ContractState, _delay: u256) {}

        fn accept_admin(ref self: ContractState) {}

        fn set_pending_admin(ref self: ContractState, _pending_admin: ContractAddress) {}

        fn queue_transaction(
            ref self: ContractState,
            _target: ContractAddress,
            _value: u256,
            _signature: felt252,
            _data: Span<felt252>,
            _eta: u256,
        ) -> felt252 {
            return '0';
        }

        fn cancel_transaction(
            ref self: ContractState,
            _target: ContractAddress,
            _value: u256,
            _signature: felt252,
            _data: Span<felt252>,
            _eta: u256,
        ) {}

        fn execute_transaction(
            ref self: ContractState,
            _target: ContractAddress,
            _value: u256,
            _signature: felt252,
            _data: Span<felt252>,
            _eta: u256,
        ) -> felt252 {
            return '0';
        }
    }


    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _is_valid_delay(_delay: u256) {}
        fn _admin_only() {}
    }
}
