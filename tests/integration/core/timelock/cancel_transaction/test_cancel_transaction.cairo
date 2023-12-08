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

const MINIMUM_DELAY: u256 = consteval_int!(2 * 24 * 60 * 60); // 2 days

// This test check cancel transaction with caller isn't the admin address
// It calls timelock.cancel_transaction()
// The test expects to fails with error Pending admin only
#[test]
#[should_panic(expected: ('Admin only',))]
fn when_caller_not_admin_it_should_revert() {
    let (timelock, _) = init();
    let target = contract_address_const::<'target'>();
    let signature = selector!("signature");
    let data = array!['0x01'];
    let eta = MINIMUM_DELAY + 1;

    timelock.cancel_transaction(target, signature, data.span(), eta);
}

// This test check cancel transaction with transaction not in queue
// It calls timelock.cancel_transaction()
// The test expects to fails with error Tx no queued
#[test]
#[should_panic(expected: ('Tx no queued',))]
fn when_caller_is_admin_and_tx_not_queue_it_should_revert() {
    let (timelock, timelock_address) = init();
    let admin_address = contract_address_const::<'admin'>();
    set_admin(timelock, timelock_address, admin_address);

    let target = contract_address_const::<'target'>();
    let signature = selector!("signature");
    let data = array!['0x01'];
    let eta = MINIMUM_DELAY + 1;

    timelock.cancel_transaction(target, signature, data.span(), eta);
}

// This test check cancel transaction with transaction in queue
// It calls timelock.cancel_transaction()
// The test expects to succeed
#[test]
fn when_caller_is_admin_and_tx_in_queue_it_should_works() {
    let (timelock, timelock_address) = init();
    let admin_address = contract_address_const::<'admin'>();
    set_admin(timelock, timelock_address, admin_address);

    start_warp(CheatTarget::One(timelock_address), 1000);
    let target = contract_address_const::<'target'>();
    let signature = selector!("signature");
    let data = array!['0x01'];
    let eta = MINIMUM_DELAY + 20000;
    let tx_hash = 0x3d1394918f9a449d63ca74a79bdc7d573179ea887fae5a9896d1f93b6894384;
    timelock.queue_transaction(target, signature, data.span(), eta);
    let mut spy = spy_events(SpyOn::One(timelock_address));
    timelock.cancel_transaction(target, signature, data.span(), eta);
    spy
        .assert_emitted(
            @array![
                (
                    timelock_address,
                    Timelock::Event::CancelTransaction(
                        Timelock::CancelTransaction {
                            tx_hash, target, signature, input_data: data.span(), eta
                        }
                    )
                )
            ]
        );
    assert(spy.events.len() == 0, 'There should be no events');
    assert(!timelock.get_tx_status(tx_hash), 'Tx still in queued');
}

fn set_admin(
    timelock: ITimelockDispatcher, timelock_address: ContractAddress, admin_address: ContractAddress
) {
    // set pending admin
    start_prank(CheatTarget::One(timelock_address), timelock_address);
    timelock.set_pending_admin(admin_address);
    stop_prank(CheatTarget::One(timelock_address));
    // accept admin
    start_prank(CheatTarget::One(timelock_address), admin_address);
    timelock.accept_admin();
}


fn init() -> (ITimelockDispatcher, ContractAddress) {
    tests::tests_lib::deploy_timelock_mock(MINIMUM_DELAY + 1, contract_address_const::<'admin'>())
}
