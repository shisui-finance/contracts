use starknet::ContractAddress;
use snforge_std::{start_prank, CheatTarget};

use shisui::core::fee_collector::{
    IFeeCollectorDispatcher, IFeeCollectorDispatcherTrait, FeeCollector
};
use tests::utils::callers::timelock_address;


use super::super::setup::setup;

#[test]
#[should_panic(expected: ('Caller not authorized',))]
fn when_caller_is_not_timelock_it_should_revert() {
    let (_, fee_collector, _, _) = setup();
    fee_collector.set_is_route_to_SHVT_staking(true);
}

#[test]
fn when_caller_is_timelock_it_should_update_shvt_staking_value() {
    let (_, fee_collector, _, _) = setup();
    start_prank(CheatTarget::One(fee_collector.contract_address), timelock_address());
    fee_collector.set_is_route_to_SHVT_staking(true);
    assert(fee_collector.get_is_route_to_SHVT_staking(), 'is route to SHVT not updated');
}
