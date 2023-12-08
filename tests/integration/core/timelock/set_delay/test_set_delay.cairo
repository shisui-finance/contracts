use snforge_std::cheatcodes::events::EventFetcher;
use starknet::{ContractAddress, contract_address_const,};
use shisui::core::timelock::{ITimelockDispatcher, ITimelockDispatcherTrait, Timelock};
use snforge_std::{
    start_prank, stop_prank, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions
};

const MINIMUM_DELAY: u256 = consteval_int!(2 * 24 * 60 * 60); // 2 days
const MAXIMUM_DELAY: u256 = consteval_int!(15 * 24 * 60 * 60); // 15 days
const GRACE_PERIOD: u256 = consteval_int!(14 * 24 * 60 * 60); // 14 days

// This testscheck set delay with value below minimum
// It calls timelock.set_delay()
// The test expects to fails with error Delay must exceed mininum delay
#[test]
#[should_panic(expected: ('Delay must exceed mininum delay',))]
fn given_delay_below_minimum_it_should_revert() {
    let (timelock, _) = init();
    timelock.set_delay(MINIMUM_DELAY);
}

// This test check set delay with value above maximum
// It calls timelock.set_delay()
// The test expects to fails with error Delay must under maximum delay
#[test]
#[should_panic(expected: ('Delay must under maximum delay',))]
fn given_delay_above_maximum_it_should_revert() {
    let (timelock, _) = init();
    timelock.set_delay(MAXIMUM_DELAY);
}

// This test check set delay with correct value but caller isn't timelock contract
// It calls timelock.set_delay()
// The test expects to fails with error Timelock only
#[test]
#[should_panic(expected: ('Timelock only',))]
fn given_valid_delay_and_caller_not_timelock_contract_it_should_revert() {
    let (timelock, _) = init();
    timelock.set_delay(MAXIMUM_DELAY - 1);
}

// This tests check set delay with correct value and caller = timelock contract
// It calls timelock.set_delay()
// The test expects to succeed
#[test]
fn given_valid_delay_and_caller_timelock_contract_it_should_set_delay_and_sent_event() {
    let delay = MAXIMUM_DELAY - 1;
    let (timelock, timelock_address) = init();
    start_prank(CheatTarget::One(timelock_address), timelock_address);
    let mut spy = spy_events(SpyOn::One(timelock_address));
    timelock.set_delay(delay);
    spy
        .assert_emitted(
            @array![
                (
                    timelock_address,
                    Timelock::Event::NewDelay(Timelock::NewDelay { new_delay: delay })
                )
            ]
        );
    assert(spy.events.len() == 0, 'There should be no events');
    assert(timelock.get_delay() == MAXIMUM_DELAY - 1, 'Wrong delay set')
}

fn init() -> (ITimelockDispatcher, ContractAddress) {
    tests::tests_lib::deploy_timelock_mock(MINIMUM_DELAY + 1, contract_address_const::<'admin'>())
}
