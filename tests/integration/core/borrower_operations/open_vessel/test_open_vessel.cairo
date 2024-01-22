use openzeppelin::token::erc20::interface::IERC20DispatcherTrait;
use shisui::core::price_feed::IPriceFeedDispatcherTrait;
use shisui::core::borrower_operations::IBorrowerOperationsDispatcherTrait;
use starknet::{ContractAddress, contract_address_const, get_caller_address};
use snforge_std::{
    start_prank, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions, start_mock_call
};
use shisui::core::admin_contract::{
    IAdminContractDispatcher, IAdminContractDispatcherTrait, AdminContract
};
use tests::utils::{
    constant::DEFAULT_TIMEOUT, aggregator::update_pragma_response,
    callers::{timelock_address, not_owner_address}
};
use shisui::utils::math::pow;
use super::super::setup::setup;
use integer::BoundedInt;
use snforge_std::PrintTrait;

const valid_decimals: u8 = 18;
const debt_token_gas_compensation: u256 = 1000;

#[test]
fn given_normal_condition_should_open_vessel() {
    let (
        borrower_operations,
        vessel_manager,
        adress_provider,
        admin_contract,
        fee_collector,
        debt_token,
        price_feed,
        pragma_mock,
        active_pool,
        default_pool,
        asset
    ) =
        setup();

    let collateral_address = asset.contract_address;
    let upper_hint_address = contract_address_const::<'upper_hint'>();
    let lower_hint_address = contract_address_const::<'lower_hint'>();

    // declare new collateral
    admin_contract
        .add_new_collateral(collateral_address, debt_token_gas_compensation, valid_decimals);

    // active new collateral    
    admin_contract.set_is_active(collateral_address, true);

    // set oracle price to 1 ETH = 1600 $
    update_pragma_response(pragma_mock, 1600_000000000000000000, 18_u32, 0_u64);
    price_feed.set_oracle(collateral_address, 'ETH/USD', DEFAULT_TIMEOUT);

    // no vessel previously open, return 0 for balance
    start_mock_call(active_pool.contract_address, 'get_asset_balance', 0_u256);
    start_mock_call(default_pool.contract_address, 'get_asset_balance', 0_u256);
    start_mock_call(active_pool.contract_address, 'get_debt_token_balance', 0_u256);
    start_mock_call(default_pool.contract_address, 'get_debt_token_balance', 0_u256);

    start_prank(
        CheatTarget::One(debt_token.contract_address), borrower_operations.contract_address
    );
    start_prank(
        CheatTarget::One(vessel_manager.contract_address), borrower_operations.contract_address
    );

    // approve unlimited 
    asset.approve(borrower_operations.contract_address, BoundedInt::max());

    // open vessel with min debt of 2000. Let's define 1.5 ETH (2400 USD) for 2000 debt token.
    borrower_operations
        .open_vessel(
            collateral_address,
            2400_000000000000000000, // deposit
            2000_000000000000000000, // debt token amount
            upper_hint_address,
            lower_hint_address
        );
}
