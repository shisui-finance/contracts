use openzeppelin::token::erc20::interface::IERC20DispatcherTrait;
use shisui::core::price_feed::IPriceFeedDispatcherTrait;
use shisui::core::borrower_operations::IBorrowerOperationsDispatcherTrait;
use shisui::mocks::erc20_mock::{IERC20MintBurnDispatcher, IERC20MintBurnDispatcherTrait};
use starknet::{ContractAddress, contract_address_const, get_caller_address};
use snforge_std::{
    start_prank, stop_prank, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions,
    start_mock_call
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
    let caller = contract_address_const::<'caller'>();
    let caller2 = contract_address_const::<'caller2'>();

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

    // mint token for caller
    IERC20MintBurnDispatcher { contract_address: asset.contract_address }
        .mint(caller, 10000_000000000000000000);

    IERC20MintBurnDispatcher { contract_address: asset.contract_address }
        .mint(caller2, 10000_000000000000000000);

    // approve borrower operation to transfer asset from caller to active pool when opening vessel
    start_prank(CheatTarget::One(asset.contract_address), caller);
    asset.approve(borrower_operations.contract_address, 10000_000000000000000000);
    stop_prank(CheatTarget::One(asset.contract_address));

    // approve borrower operation to transfer asset from caller to active pool when opening vessel
    start_prank(CheatTarget::One(asset.contract_address), caller2);
    asset.approve(borrower_operations.contract_address, 10000_000000000000000000);
    stop_prank(CheatTarget::One(asset.contract_address));

    start_prank(CheatTarget::One(asset.contract_address), borrower_operations.contract_address);
    start_prank(CheatTarget::One(borrower_operations.contract_address), caller);
    // open vessel with min debt of 2000. Let's define 1.89 ETH (3024 USD) for 2000 debt token. We get icr >=MCR and tcr >=CCR
    borrower_operations
        .open_vessel(
            collateral_address,
            1_890000000000000000, // deposit
            2000_000000000000000000, // debt token amount
            upper_hint_address,
            lower_hint_address
        );

    stop_prank(CheatTarget::One(borrower_operations.contract_address));
    start_prank(CheatTarget::One(borrower_operations.contract_address), caller2);
    borrower_operations
        .open_vessel(
            collateral_address,
            2_400000000000000000, // deposit
            2000_000000000000000000, // debt token amount
            upper_hint_address,
            lower_hint_address
        );
    stop_prank(CheatTarget::One(borrower_operations.contract_address));
}
