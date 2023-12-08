use starknet::ContractAddress;


#[starknet::interface]
trait ITimelock<TContractState> {
    fn set_delay(ref self: TContractState, delay: u256);
    fn get_delay(self: @TContractState) -> u256;
    fn accept_admin(ref self: TContractState);
    fn get_admin(self: @TContractState) -> ContractAddress;
    fn set_pending_admin(ref self: TContractState, pending_admin: ContractAddress);
    fn get_pending_admin(self: @TContractState) -> ContractAddress;

    fn get_grace_period(self: @TContractState) -> u256;
    fn get_minimum_delay(self: @TContractState) -> u256;
    fn get_maximum_delay(self: @TContractState) -> u256;

    fn get_tx_status(self: @TContractState, tx_hash: felt252) -> bool;

    fn queue_transaction(
        ref self: TContractState,
        target: ContractAddress,
        signature: felt252,
        data: Span<felt252>,
        eta: u256,
    ) -> felt252;

    fn cancel_transaction(
        ref self: TContractState,
        target: ContractAddress,
        signature: felt252,
        data: Span<felt252>,
        eta: u256,
    );

    fn execute_transaction(
        ref self: TContractState,
        target: ContractAddress,
        signature: felt252,
        data: Span<felt252>,
        eta: u256,
    );
}


#[starknet::contract]
mod Timelock {
    use core::traits::Into;
    use core::zeroable::Zeroable;
    use core::array::ArrayTrait;
    use core::starknet::event::EventEmitter;
    use core::option::OptionTrait;
    use core::serde::Serde;
    use core::traits::TryInto;
    use core::box::BoxTrait;
    use starknet::{
        ContractAddress, contract_address_const, get_caller_address, get_contract_address,
        get_block_timestamp, call_contract_syscall
    };
    use poseidon::PoseidonTrait;
    use shisui::utils::hash::ISpanFelt252Hash;
    use core::hash::HashStateTrait;
    use core::hash::HashStateExTrait;
    use starknet::SyscallResultTrait;

    const MINIMUM_DELAY: u256 = consteval_int!(2 * 24 * 60 * 60); // 2 days
    const MAXIMUM_DELAY: u256 = consteval_int!(15 * 24 * 60 * 60); // 15 days
    const GRACE_PERIOD: u256 = consteval_int!(14 * 24 * 60 * 60); // 14 days

    // *************************************************************************
    //                              STORAGE
    // *************************************************************************
    #[storage]
    struct Storage {
        admin: ContractAddress,
        pending_admin: ContractAddress,
        delay: u256,
        queued_transactions: LegacyMap::<felt252, bool>,
    }

    // *************************************************************************
    //                              EVENT
    // *************************************************************************
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        NewAdmin: NewAdmin,
        NewPendingAdmin: NewPendingAdmin,
        NewDelay: NewDelay,
        CancelTransaction: CancelTransaction,
        ExecuteTransaction: ExecuteTransaction,
        QueueTransaction: QueueTransaction
    }

    #[derive(Drop, starknet::Event)]
    struct NewAdmin {
        #[key]
        new_admin: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct NewPendingAdmin {
        #[key]
        new_pending_admin: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct NewDelay {
        #[key]
        new_delay: u256
    }

    #[derive(Drop, starknet::Event)]
    struct CancelTransaction {
        #[key]
        tx_hash: felt252,
        #[key]
        target: ContractAddress,
        signature: felt252,
        input_data: Span<felt252>,
        eta: u256
    }

    #[derive(Drop, starknet::Event)]
    struct ExecuteTransaction {
        #[key]
        tx_hash: felt252,
        #[key]
        target: ContractAddress,
        signature: felt252,
        input_data: Span<felt252>,
        eta: u256
    }

    #[derive(Drop, starknet::Event)]
    struct QueueTransaction {
        #[key]
        tx_hash: felt252,
        #[key]
        target: ContractAddress,
        signature: felt252,
        input_data: Span<felt252>,
        eta: u256
    }

    // *************************************************************************
    //                              ERRORS
    // *************************************************************************
    mod Errors {
        const Timelock__DelayMustExceedMininumDelay: felt252 = 'Delay must exceed mininum delay';
        const Timelock__DelayMustNotExceedMaximumDelay: felt252 = 'Delay must under maximum delay';
        const Timelock__TimelockOnly: felt252 = 'Timelock only';
        const Timelock__PendingAdminOnly: felt252 = 'Pending admin only';
        const Timelock__AdminOnly: felt252 = 'Admin only';
        const Timelock__ETAMustSatisfyDelay: felt252 = 'ETA must satisfy delay';
        const Timelock__TxNoQueued: felt252 = 'Tx no queued';
        const Timelock__TxAlreadyQueued: felt252 = 'Tx already queued';
        const Timelock__TxStillLocked: felt252 = 'Tx still locked';
        const Timelock__TxExpired: felt252 = 'Tx expired';
        const Timelock__TxReverted: felt252 = 'Tx reverted';
        const Timelock__ZeroAddressAdmin: felt252 = 'Admin is the zero address';
        const Timelock_ZeroAddressCaller: felt252 = 'Caller is the zero address';
    }

    // *************************************************************************
    //                              CONSTRUCTOR
    // *************************************************************************
    #[constructor]
    fn constructor(ref self: ContractState, _delay: u256, _admin: ContractAddress) {
        self.is_valid_delay(_delay);
        assert(_admin.is_non_zero(), Errors::Timelock__ZeroAddressAdmin);
        self.admin.write(_admin);
        self.delay.write(_delay);
    }

    // *************************************************************************
    //                          INTERNAL FUNCTIONS
    // *************************************************************************
    #[external(v0)]
    impl TimelockImpl of super::ITimelock<ContractState> {
        fn get_delay(self: @ContractState) -> u256 {
            self.delay.read()
        }

        fn get_admin(self: @ContractState) -> ContractAddress {
            self.admin.read()
        }

        fn get_pending_admin(self: @ContractState) -> ContractAddress {
            self.pending_admin.read()
        }

        fn get_grace_period(self: @ContractState) -> u256 {
            GRACE_PERIOD
        }

        fn get_minimum_delay(self: @ContractState) -> u256 {
            MINIMUM_DELAY
        }

        fn get_maximum_delay(self: @ContractState) -> u256 {
            MAXIMUM_DELAY
        }

        fn get_tx_status(self: @ContractState, tx_hash: felt252) -> bool {
            self.queued_transactions.read(tx_hash)
        }

        fn set_delay(ref self: ContractState, delay: u256) {
            self.is_valid_delay(delay);
            assert(get_caller_address() == get_contract_address(), Errors::Timelock__TimelockOnly);

            self.delay.write(delay);
            self.emit(NewDelay { new_delay: delay });
        }

        fn accept_admin(ref self: ContractState) {
            let caller = get_caller_address();
            assert(caller == self.pending_admin.read(), Errors::Timelock__PendingAdminOnly);

            self.admin.write(caller);
            self.pending_admin.write(contract_address_const::<0>());
            self.emit(NewAdmin { new_admin: caller });
        }

        fn set_pending_admin(ref self: ContractState, pending_admin: ContractAddress) {
            assert(get_caller_address() == get_contract_address(), Errors::Timelock__TimelockOnly);

            self.pending_admin.write(pending_admin);
            self.emit(NewPendingAdmin { new_pending_admin: pending_admin });
        }

        fn queue_transaction(
            ref self: ContractState,
            target: ContractAddress,
            signature: felt252,
            data: Span<felt252>,
            eta: u256
        ) -> felt252 {
            self.admin_only();
            let block_time_stamp: u256 = get_block_timestamp().into();
            let delay = self.delay.read();

            assert(
                eta >= block_time_stamp + delay && eta <= block_time_stamp + delay + GRACE_PERIOD,
                Errors::Timelock__ETAMustSatisfyDelay
            );

            let tx_hash = self.get_hash(target, signature, data, eta);
            assert(!self.queued_transactions.read(tx_hash), Errors::Timelock__TxAlreadyQueued);

            self.queued_transactions.write(tx_hash, true);
            self
                .emit(
                    QueueTransaction {
                        tx_hash, target: target, signature: signature, input_data: data, eta: eta
                    }
                );
            tx_hash
        }

        fn cancel_transaction(
            ref self: ContractState,
            target: ContractAddress,
            signature: felt252,
            data: Span<felt252>,
            eta: u256
        ) {
            self.admin_only();
            let tx_hash = self.get_hash(target, signature, data, eta);
            assert(self.queued_transactions.read(tx_hash), Errors::Timelock__TxNoQueued);

            self.queued_transactions.write(tx_hash, false);
            self
                .emit(
                    CancelTransaction {
                        tx_hash, target: target, signature: signature, input_data: data, eta: eta
                    }
                );
        }

        fn execute_transaction(
            ref self: ContractState,
            target: ContractAddress,
            signature: felt252,
            data: Span<felt252>,
            eta: u256
        ) {
            self.admin_only();

            let tx_hash = self.get_hash(target, signature, data, eta);
            assert(self.queued_transactions.read(tx_hash), Errors::Timelock__TxNoQueued);

            assert(get_block_timestamp().into() >= eta, Errors::Timelock__TxStillLocked);
            assert(get_block_timestamp().into() <= eta + GRACE_PERIOD, Errors::Timelock__TxExpired);

            self.queued_transactions.write(tx_hash, false);
            match call_contract_syscall(target, signature, data) {
                Result::Ok(return_data) => {
                    self
                        .emit(
                            ExecuteTransaction {
                                tx_hash,
                                target: target,
                                signature: signature,
                                input_data: data,
                                eta: eta
                            }
                        );
                },
                Result::Err(revert_reason) => { panic_with_felt252(Errors::Timelock__TxReverted); },
            }
        }
    }

    // *************************************************************************
    //                          INTERNAL FUNCTIONS
    // *************************************************************************
    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn is_valid_delay(self: @ContractState, _delay: u256) {
            assert(_delay > MINIMUM_DELAY, Errors::Timelock__DelayMustExceedMininumDelay);
            assert(_delay < MAXIMUM_DELAY, Errors::Timelock__DelayMustNotExceedMaximumDelay);
        }

        fn admin_only(self: @ContractState) {
            assert(get_caller_address() == self.admin.read(), Errors::Timelock__AdminOnly)
        }

        fn get_hash(
            self: @ContractState,
            target: ContractAddress,
            signature: felt252,
            data: Span<felt252>,
            eta: u256
        ) -> felt252 {
            let mut hash_state = PoseidonTrait::new();
            hash_state = hash_state.update_with(target);
            hash_state = hash_state.update_with(signature);
            hash_state = hash_state.update_with(data.hash_span());
            hash_state = hash_state.update_with(eta);
            hash_state.finalize()
        }
    }
}
