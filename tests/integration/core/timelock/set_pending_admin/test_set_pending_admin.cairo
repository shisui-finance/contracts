use snforge_std::cheatcodes::events::EventFetcher;
use starknet::{ContractAddress, contract_address_const,};
use shisui::core::timelock::{ITimelockDispatcher, ITimelockDispatcherTrait, Timelock};
use snforge_std::{
    start_prank, stop_prank, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions
};

const MINIMUM_DELAY: u256 = consteval_int!(2 * 24 * 60 * 60); // 2 days

// This test check set pending admin with caller isn't timelock contract
// It calls timelock.set_pending_admin()
// The test expects to fails with error Pending admin only
#[test]
#[should_panic(expected: ('Timelock only',))]
fn when_caller_not_timelock_contract_it_should_revert() {
    let (timelock, _) = init();
    let admin_address = contract_address_const::<'admin'>();
    timelock.set_pending_admin(admin_address);
}

// This test check set pending admin with caller = timelock contract
// It calls ttimelock.set_pending_admin()
// The test expects to succeed
#[test]
fn when_caller_is_timelock_contract_should_work() {
    let (timelock, timelock_address) = init();
    let admin_address = contract_address_const::<'admin'>();
    start_prank(CheatTarget::One(timelock_address), timelock_address);
    let mut spy = spy_events(SpyOn::One(timelock_address));
    timelock.set_pending_admin(admin_address);
    spy
        .assert_emitted(
            @array![
                (
                    timelock_address,
                    Timelock::Event::NewPendingAdmin(
                        Timelock::NewPendingAdmin { new_pending_admin: admin_address }
                    )
                )
            ]
        );
    assert(spy.events.len() == 0, 'There should be no events');
    assert(admin_address == timelock.get_pending_admin(), 'Wrong pending admin set');
}


fn init() -> (ITimelockDispatcher, ContractAddress) {
    tests::tests_lib::deploy_timelock_mock(MINIMUM_DELAY + 1, contract_address_const::<'admin'>())
}
