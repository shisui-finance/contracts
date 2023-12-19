use core::option::OptionTrait;
use core::traits::TryInto;
use core::traits::Into;
use snforge_std::cheatcodes::events::EventFetcher;
use starknet::{ContractAddress, contract_address_const,};
use shisui::core::timelock::{ITimelockDispatcher, ITimelockDispatcherTrait, Timelock};
use shisui::mocks::simple_contract_mock::{ISimpleStorageDispatcher, ISimpleStorageDispatcherTrait};
use poseidon::PoseidonTrait;
use shisui::utils::hash::ISpanFelt252Hash;
use core::hash::HashStateTrait;
use core::hash::HashStateExTrait;
use snforge_std::{
    start_prank, stop_prank, start_warp, stop_warp, CheatTarget, spy_events, SpyOn, EventSpy,
    EventAssertions
};
use serde::Serde;
use debug::PrintTrait;

const MINIMUM_DELAY: u256 = consteval_int!(2 * 24 * 60 * 60); // 2 days
const GRACE_PERIOD: u256 = consteval_int!(14 * 24 * 60 * 60); // 14 days

// This test check execute transaction with caller isn't the admin address
// It calls timelock.execute_transaction()
// The test expects to fails with error Pending admin only
#[test]
#[should_panic(expected: ('Admin only',))]
fn when_caller_not_admin_it_should_revert() {
    let (timelock, _,) = init();
    let target = contract_address_const::<'target'>();
    let signature = selector!("signature");
    let data = array!['0x01'];
    let eta = MINIMUM_DELAY + 1;

    timelock.execute_transaction(target, signature, data.span(), eta);
}

// This test check execute transaction with transaction not in queue
// It calls timelock.execute_transaction()
// The test expects to fails with error Tx no queued
#[test]
#[should_panic(expected: ('Tx no queued',))]
fn when_caller_is_admin_and_tx_not_queue_it_should_revert() {
    let (timelock, _) = init();
    set_admin(timelock);

    let target = contract_address_const::<'target'>();
    let signature = selector!("signature");
    let data = array!['0x01'];
    let eta = MINIMUM_DELAY + 1;

    timelock.execute_transaction(target, signature, data.span(), eta);
}

// This test check execute transaction with block timestamp below eta
// It calls timelock.execute_transaction()
// The test expects to fails with error Tx still locked
#[test]
#[should_panic(expected: ('Tx still locked',))]
fn when_caller_is_admin_and_block_timestamp_below_eta_it_should_revert() {
    let (timelock, simple_contract) = init();
    set_admin(timelock);
    let (signature, data, eta) = queue_transaction(
        timelock, simple_contract.contract_address, 5, MINIMUM_DELAY + 20000
    );
    timelock.execute_transaction(simple_contract.contract_address, signature, data, eta);
}

// This test check execute transaction with block timestamp below eta
// It calls timelock.execute_transaction()
// The test expects to fails with error Tx expired
#[test]
#[should_panic(expected: ('Tx expired',))]
fn when_caller_is_admin_and_block_timestamp_above_eta_it_should_revert() {
    let (timelock, simple_contract) = init();
    set_admin(timelock);
    let (signature, data, eta) = queue_transaction(
        timelock, simple_contract.contract_address, 5, MINIMUM_DELAY + 20000
    );
    start_warp(
        CheatTarget::One(timelock.contract_address),
        eta.try_into().unwrap() + GRACE_PERIOD.try_into().unwrap() + 1
    );

    timelock.execute_transaction(simple_contract.contract_address, signature, data, eta);
}

// This test check execute transaction with block timestamp valid, call invalid and unrecoverable error
// It calls timelock.execute_transaction()
// The test expects to fails
#[test]
#[should_panic]
fn when_caller_is_admin_and_block_timestamp_is_valid_and_call_not_valid_it_should_revert() {
    //init contract
    let (timelock, simple_contract) = init();
    set_admin(timelock);
    let (signature, data, eta) = queue_transaction(
        timelock, simple_contract.contract_address, 256, MINIMUM_DELAY + 20000
    );
    start_warp(CheatTarget::One(timelock.contract_address), eta.try_into().unwrap() + 1);
    //execute transaction - should revert 
    timelock.execute_transaction(simple_contract.contract_address, signature, data, eta);
}

// This test check execute transaction with block timestamp and call valid
// It calls timelock.execute_transaction()
// The test expects to succeed
#[test]
fn when_caller_is_admin_and_block_timestamp_is_valid_and_call_is_valid_it_should_work() {
    let (timelock, simple_contract) = init();
    set_admin(timelock);
    let value: felt252 = 4;
    let (signature, data, eta) = queue_transaction(
        timelock, simple_contract.contract_address, value, MINIMUM_DELAY + 20000
    );

    let tx_hash = get_hash(simple_contract.contract_address, signature, data, eta);
    start_warp(CheatTarget::One(timelock.contract_address), eta.try_into().unwrap() + 1);
    let mut spy = spy_events(SpyOn::One(timelock.contract_address));
    let result: Span<felt252> = timelock
        .execute_transaction(simple_contract.contract_address, signature, data, eta);
    spy
        .assert_emitted(
            @array![
                (
                    timelock.contract_address,
                    Timelock::Event::ExecuteTransaction(
                        Timelock::ExecuteTransaction {
                            tx_hash,
                            target: simple_contract.contract_address,
                            signature,
                            input_data: data,
                            eta
                        }
                    )
                )
            ]
        );
    assert(simple_contract.get() == 4, 'Call to simple contract failed');
    assert(!timelock.get_tx_status(tx_hash), 'Tx still in queued');
    assert(*result[0] == 4, 'Wrong value return by syscall');
}

fn init() -> (ITimelockDispatcher, ISimpleStorageDispatcher) {
    let (timelock, timelock_address) = tests::tests_lib::deploy_timelock_mock(
        MINIMUM_DELAY + 1, contract_address_const::<'admin'>()
    );
    let address = tests::tests_lib::deploy_simple_storage_mock();
    let simple_storage = ISimpleStorageDispatcher { contract_address: address };
    (timelock, simple_storage)
}

fn set_admin(timelock: ITimelockDispatcher) {
    let admin_address = contract_address_const::<'admin'>();
    // set pending admin
    start_prank(CheatTarget::One(timelock.contract_address), timelock.contract_address);
    timelock.set_pending_admin(admin_address);
    stop_prank(CheatTarget::One(timelock.contract_address));
    // accept admin
    start_prank(CheatTarget::One(timelock.contract_address), admin_address);
    timelock.accept_admin();
}

fn queue_transaction(
    timelock: ITimelockDispatcher, target: ContractAddress, data: felt252, eta: u256
) -> (felt252, Span<felt252>, u256) {
    //set block timestamp
    start_warp(CheatTarget::One(timelock.contract_address), 1000);
    //define data
    let signature = selector!("set");
    let mut call_data: Array<felt252> = ArrayTrait::new();
    Serde::serialize(@data, ref call_data);
    //queue transcation
    timelock.queue_transaction(target, signature, call_data.span(), eta);
    //set block timestamp
    stop_warp(CheatTarget::One(timelock.contract_address));
    (signature, call_data.span(), eta)
}

fn get_hash(
    target: ContractAddress, signature: felt252, data: Span<felt252>, eta: u256
) -> felt252 {
    let mut hash_state = PoseidonTrait::new();
    hash_state = hash_state.update_with(target);
    hash_state = hash_state.update_with(signature);
    hash_state = hash_state.update_with(data.hash_span());
    hash_state = hash_state.update_with(eta);
    hash_state.finalize()
}
