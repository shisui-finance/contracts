use shisui::core::{
    address_provider::{IAddressProviderDispatcher, IAddressProviderDispatcherTrait, AddressesKey},
    admin_contract::{IAdminContractDispatcher, IAdminContractDispatcherTrait},
    fee_collector::{IFeeCollectorDispatcher, IFeeCollectorDispatcherTrait},
    debt_token::{IDebtTokenDispatcher, IDebtTokenDispatcherTrait},
    price_feed::{IPriceFeedDispatcher, IPriceFeedDispatcherTrait},
};
use shisui::pools::{
    borrower_operations::{IBorrowerOperationsDispatcher, IBorrowerOperationsDispatcherTrait},
    vessel_manager::{IVesselManagerDispatcher, IVesselManagerDispatcherTrait},
};
use shisui::mocks::pragma_oracle_mock::{
    IPragmaOracleMockDispatcher, IPragmaOracleMockDispatcherTrait
};
use shisui::mocks::erc20_mock::{IERC20MintBurnDispatcher, IERC20MintBurnDispatcherTrait};
use shisui::pools::active_pool::{IActivePoolDispatcher, IActivePoolDispatcherTrait};
use shisui::pools::default_pool::{IDefaultPoolDispatcher, IDefaultPoolDispatcherTrait};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

use snforge_std::{
    start_prank, stop_prank, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions,
    start_mock_call
};
use starknet::{ContractAddress, contract_address_const, get_caller_address};

use tests::tests_lib::{
    deploy_address_provider, deploy_fee_collector, deploy_debt_token, deploy_admin_contract,
    deploy_vessel_manager
};
use tests::utils::{
    constant::DEFAULT_TIMEOUT, aggregator::update_pragma_response,
    callers::{timelock_address, not_owner_address}
};

fn setup() -> (
    IVesselManagerDispatcher,
    IAddressProviderDispatcher,
    IAdminContractDispatcher,
    IFeeCollectorDispatcher,
    IDebtTokenDispatcher
) {
    let address_provider_address: ContractAddress = deploy_address_provider();
    let address_provider: IAddressProviderDispatcher = IAddressProviderDispatcher {
        contract_address: address_provider_address
    };

    let admin_contract_address: ContractAddress = deploy_admin_contract(address_provider_address);
    let admin_contract: IAdminContractDispatcher = IAdminContractDispatcher {
        contract_address: admin_contract_address
    };

    let fee_collector_address: ContractAddress = deploy_fee_collector(address_provider_address);
    let fee_collector: IFeeCollectorDispatcher = IFeeCollectorDispatcher {
        contract_address: fee_collector_address
    };

    let debt_token_address: ContractAddress = deploy_debt_token(address_provider_address);
    let debt_token: IDebtTokenDispatcher = IDebtTokenDispatcher {
        contract_address: debt_token_address
    };

    let vessel_manager_address: ContractAddress = deploy_vessel_manager(
        address_provider_address, admin_contract_address, fee_collector_address, debt_token_address
    );
    let vessel_manager: IVesselManagerDispatcher = IVesselManagerDispatcher {
        contract_address: vessel_manager_address
    };

    return (vessel_manager, address_provider, admin_contract, fee_collector, debt_token);
}


fn open_vessel(
    asset: IERC20Dispatcher,
    price_feed: IPriceFeedDispatcher,
    admin_contract: IAdminContractDispatcher,
    active_pool: IActivePoolDispatcher,
    default_pool: IDefaultPoolDispatcher,
    debt_token: IDebtTokenDispatcher,
    borrower_operations: IBorrowerOperationsDispatcher,
    vessel_manager: IVesselManagerDispatcher,
    pragma_mock: IPragmaOracleMockDispatcher,
    asset_price: u256,
    deposit_amount: u256,
    debt_token_amount: u256
) -> ContractAddress {
    let valid_decimals: u8 = 18;
    let debt_token_gas_compensation: u256 = 1000;
    let caller = contract_address_const::<'caller'>();

    let collateral_address = asset.contract_address;
    let upper_hint_address = contract_address_const::<'upper_hint'>();
    let lower_hint_address = contract_address_const::<'lower_hint'>();

    // declare new collateral
    admin_contract
        .add_new_collateral(collateral_address, debt_token_gas_compensation, valid_decimals);

    // active new collateral    
    admin_contract.set_is_active(collateral_address, true);

    // set oracle price to 1 ETH = 1600 $
    update_pragma_response(pragma_mock, asset_price, 18_u32, 0_u64);
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

    // approve borrower operation to transfer asset from caller to active pool when opening vessel
    start_prank(CheatTarget::One(asset.contract_address), caller);
    asset.approve(borrower_operations.contract_address, 10000_000000000000000000);
    stop_prank(CheatTarget::One(asset.contract_address));

    start_prank(CheatTarget::One(asset.contract_address), borrower_operations.contract_address);
    start_prank(CheatTarget::One(borrower_operations.contract_address), caller);
    // open vessel with min debt of 2000. Let's define 1.89 ETH (3024 USD) for 2000 debt token. We get icr >=MCR and tcr >=CCR
    borrower_operations
        .open_vessel(
            collateral_address,
            deposit_amount, // deposit
            debt_token_amount, // debt token amount
            upper_hint_address,
            lower_hint_address
        );

    stop_prank(CheatTarget::One(borrower_operations.contract_address));
    caller
}
