use core::zeroable::Zeroable;
use snforge_std::cheatcodes::events::EventFetcher;
use starknet::{ContractAddress, contract_address_const,};
use shisui::core::timelock::{ITimelockDispatcher, ITimelockDispatcherTrait, Timelock};
use snforge_std::{
    start_prank, stop_prank, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions
};

const MINIMUM_DELAY: u256 = consteval_int!(2 * 24 * 60 * 60); // 2 days

// This test check accept admin with caller isn't timelock contract
// It calls timelock.accept_admin()
// The test expects to fails with error Pending admin only
#[test]
#[should_panic(expected: ('Pending admin only',))]
fn when_caller_not_timelock_contract_it_should_revert() {
    let (timelock, _) = init();
    timelock.accept_admin();
}

// This test check accept admin with caller is pending admin
// It calls timelock.accept_admin()
// The test expects to succeed
#[test]
fn when_caller_is_pending_admin_it_should_work() {
    let (timelock, timelock_address) = init();
    let old_admin_address = timelock.get_admin();
    let new_admin_address = contract_address_const::<'new_admin'>();
    // set pending admin
    start_prank(CheatTarget::One(timelock_address), timelock_address);
    timelock.set_pending_admin(new_admin_address);
    stop_prank(CheatTarget::One(timelock_address));
    // accept admin
    start_prank(CheatTarget::One(timelock_address), new_admin_address);
    let mut spy = spy_events(SpyOn::One(timelock_address));
    timelock.accept_admin();
    spy
        .assert_emitted(
            @array![
                (
                    timelock_address,
                    Timelock::Event::NewAdmin(
                        Timelock::NewAdmin {
                            old_admin: old_admin_address, new_admin: new_admin_address
                        }
                    )
                )
            ]
        );
    assert(spy.events.len() == 0, 'There should be no events');
    assert(timelock.get_pending_admin().is_zero(), 'Pending admin not reset');
    assert(timelock.get_admin() == new_admin_address, 'Wrong admin set');
}

fn init() -> (ITimelockDispatcher, ContractAddress) {
    tests::tests_lib::deploy_timelock_mock(MINIMUM_DELAY + 1, contract_address_const::<'admin'>())
}
