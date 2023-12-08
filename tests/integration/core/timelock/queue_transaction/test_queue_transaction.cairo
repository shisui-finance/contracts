use snforge_std::cheatcodes::events::EventFetcher;
use starknet::{ContractAddress, contract_address_const,};
use shisui::core::timelock::{ITimelockDispatcher, ITimelockDispatcherTrait, Timelock};
use poseidon::PoseidonTrait;
use shisui::utils::hash::ISpanFelt252Hash;
use core::hash::HashStateTrait;
use core::hash::HashStateExTrait;
use snforge_std::{
    start_prank, stop_prank, start_warp, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions
};
use array::ArrayTrait;

const MINIMUM_DELAY: u256 = consteval_int!(2 * 24 * 60 * 60); // 2 days

// This test check queue transaction with caller isn't the admin address
// It calls timelock.queue_transaction()
// The test expects to fails with error Pending admin only
#[test]
#[should_panic(expected: ('Admin only',))]
fn when_caller_not_admin_it_should_revert() {
    let (timelock, _) = init();

    let target = contract_address_const::<'target'>();
    let signature = selector!("signature");
    let data = array!['0x01'];
    let eta = MINIMUM_DELAY + 1;

    timelock.queue_transaction(target, signature, data.span(), eta);
}

// This test check queue transaction with caller is the admin and eta is lower than current block timestamp + delay
// It calls timelock.queue_transaction()
// The test expects to fails with error ETA must satisfy delay
#[test]
#[should_panic(expected: ('ETA must satisfy delay',))]
fn when_caller_is_admin_and_eta_lower_than_block_and_delay_it_should_revert() {
    let (timelock, timelock_address) = init();
    let admin_address = contract_address_const::<'admin'>();
    // set pending admin
    start_prank(CheatTarget::One(timelock_address), timelock_address);
    timelock.set_pending_admin(admin_address);
    stop_prank(CheatTarget::One(timelock_address));
    // accept admin
    start_prank(CheatTarget::One(timelock_address), admin_address);
    timelock.accept_admin();
    //define block timestamp
    start_warp(CheatTarget::One(timelock_address), 1000);
    // define values
    let target = contract_address_const::<'target'>();
    let signature = selector!("signature");
    let data = array!['0x01'];
    let eta = 1;

    timelock.queue_transaction(target, signature, data.span(), eta);
}

// This test check queue transaction with caller is the admin and eta is greater than current block timestamp + delay + grace period
// It calls timelock.queue_transaction()
// The test expects to fails with error ETA must satisfy delay
#[test]
#[should_panic(expected: ('ETA must satisfy delay',))]
fn when_caller_is_admin_and_eta_greater_than_block_and_delay_and_grace_period_it_should_revert() {
    let (timelock, timelock_address) = init();
    let admin_address = contract_address_const::<'admin'>();
    // set pending admin
    start_prank(CheatTarget::One(timelock_address), timelock_address);
    timelock.set_pending_admin(admin_address);
    stop_prank(CheatTarget::One(timelock_address));
    // accept admin
    start_prank(CheatTarget::One(timelock_address), admin_address);
    timelock.accept_admin();
    //define block timestamp
    start_warp(CheatTarget::One(timelock_address), 1000);
    // define values
    let target = contract_address_const::<'target'>();
    let signature = selector!("signature");
    let data = array!['0x01'];
    let eta =
        1383402; // value greater than 1000 (block timestamp)+172801 (delay) +1209600 (grace period)
    timelock.queue_transaction(target, signature, data.span(), eta);
}

// This test check queue transaction having tx_hash already in queue with caller is the admin and valid eta
// It calls timelock.queue_transaction()
// The test expects to fails with error Tx already queued
#[test]
#[should_panic(expected: ('Tx already queued',))]
fn when_caller_is_admin_and_valid_eta_and_tx_hash_already_in_queue_should_revert() {
    let (timelock, timelock_address) = init();
    let admin_address = contract_address_const::<'admin'>();
    // set pending admin
    start_prank(CheatTarget::One(timelock_address), timelock_address);
    timelock.set_pending_admin(admin_address);
    stop_prank(CheatTarget::One(timelock_address));
    // accept admin
    start_prank(CheatTarget::One(timelock_address), admin_address);
    timelock.accept_admin();
    //define block timestamp
    start_warp(CheatTarget::One(timelock_address), 1000);
    // define values
    let target = contract_address_const::<'target'>();
    let signature = selector!("signature");
    let data = array!['0x01'];
    let eta = MINIMUM_DELAY + 20000;
    timelock.queue_transaction(target, signature, data.span(), eta);
    timelock.queue_transaction(target, signature, data.span(), eta);
}

// This test check queue transaction with caller is the admin and valid eta to work
// It calls timelock.queue_transaction()
// The test expects to succeed
#[test]
fn when_caller_is_admin_and_valid_eta_it_should_work() {
    let (timelock, timelock_address) = init();
    let admin_address = contract_address_const::<'admin'>();
    // set pending admin
    start_prank(CheatTarget::One(timelock_address), timelock_address);
    timelock.set_pending_admin(admin_address);
    stop_prank(CheatTarget::One(timelock_address));
    // accept admin
    start_prank(CheatTarget::One(timelock_address), admin_address);
    timelock.accept_admin();
    //define block timestamp
    start_warp(CheatTarget::One(timelock_address), 1000);
    // define values
    let target = contract_address_const::<'target'>();
    let signature = selector!("signature");
    let data = array!['0x01'];
    let eta = MINIMUM_DELAY + 20000;
    //generate hash
    //let tx_hash = get_hash(target, signature, data.span(), eta);
    let mut spy = spy_events(SpyOn::One(timelock_address));
    //call queue_transaction
    timelock.queue_transaction(target, signature, data.span(), eta);
    let tx_hash = 0x3d1394918f9a449d63ca74a79bdc7d573179ea887fae5a9896d1f93b6894384;
    spy
        .assert_emitted(
            @array![
                (
                    timelock_address,
                    Timelock::Event::QueueTransaction(
                        Timelock::QueueTransaction {
                            tx_hash, target, signature, input_data: data.span(), eta
                        }
                    )
                )
            ]
        );
    assert(spy.events.len() == 0, 'There should be no events');
    assert(timelock.get_tx_status(tx_hash), 'Tx wrongly queued');
}

fn init() -> (ITimelockDispatcher, ContractAddress) {
    tests::tests_lib::deploy_timelock_mock(MINIMUM_DELAY + 1, contract_address_const::<'admin'>())
}

fn get_hash(
    _target: ContractAddress, _signature: felt252, _data: Span<felt252>, _eta: u256
) -> felt252 {
    let mut hash_state = PoseidonTrait::new();
    hash_state = hash_state.update_with(_target);
    hash_state = hash_state.update_with(_signature);
    hash_state = hash_state.update_with(_data.hash_span());
    hash_state = hash_state.update_with(_eta);
    hash_state.finalize()
}
