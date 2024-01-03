use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
use snforge_std::{
    start_prank, stop_prank, start_warp, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions,
    PrintTrait
};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

use shisui::core::{
    debt_token::{IDebtTokenDispatcher, IDebtTokenDispatcherTrait},
    fee_collector::{IFeeCollectorDispatcher, IFeeCollectorDispatcherTrait, FeeCollector}
};
use shisui::utils::constants::ONE;
use tests::utils::{
    callers::{vessel_manager_address, borrower, timelock_address},
    constant::{MIN_FEE_DURATION, FEE_EXPIRATION_SECONDS}, asserts::assert_is_approximately_equal
};

use super::super::setup::{setup, calc_fees, calc_new_duration, calc_expired_amount};


fn test_setup() -> (IFeeCollectorDispatcher, ContractAddress, ContractAddress) {
    let (_, fee_collector, debt_token_address, asset_address) = setup();

    (fee_collector, debt_token_address, asset_address)
}


#[test]
#[should_panic(expected: ('Caller not authorized',))]
fn when_caller_is_vessel_manager_it_sould_revert() {
    let (fee_collector, _, asset_address) = test_setup();
    fee_collector.handle_redemption_fee(asset_address, ONE);
}


#[test]
fn when_caller_valid_and_is_route_to_shvt_staking_is_false_it_should_just_emit_event() {
    let (fee_collector, debt_token_address, asset_address) = test_setup();
    let mut spy = spy_events(SpyOn::One(fee_collector.contract_address));

    start_prank(CheatTarget::One(fee_collector.contract_address), vessel_manager_address());
    fee_collector.handle_redemption_fee(asset_address, ONE);

    spy
        .assert_emitted(
            @array![
                (
                    fee_collector.contract_address,
                    FeeCollector::Event::RedemptionFeeCollected(
                        FeeCollector::RedemptionFeeCollected { asset: asset_address, amount: ONE }
                    )
                )
            ]
        );
    assert(spy.events.is_empty(), 'There should be no event');
}
// TODO: test when shvt staking contract setup
// #[test]
// fn when_caller_valid_and_is_route_to_shvt_staking_is_true_it_should_call_increase_fee_asset() {
//     let (fee_collector, debt_token_address, asset_address) = test_setup();

//     start_prank(CheatTarget::One(fee_collector.contract_address), timelock_address());
//     fee_collector.set_is_route_to_SHVT_staking(true);

//     let mut spy = spy_events(SpyOn::One(fee_collector.contract_address));

//     start_prank(CheatTarget::One(fee_collector.contract_address), vessel_manager_address());
//     fee_collector.handle_redemption_fee(asset_address, ONE);

//     spy
//         .assert_emitted(
//             @array![
//                 (
//                     fee_collector.contract_address,
//                     FeeCollector::Event::RedemptionFeeCollected(
//                         FeeCollector::RedemptionFeeCollected { asset: asset_address, amount: ONE }
//                     )
//                 )
//             ]
//         );
//     assert(spy.events.is_empty(), 'There should be no event');
// }


