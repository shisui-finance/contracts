use starknet::{ContractAddress, contract_address_const};
use shisui::core::{
    borrower_operations::{IBorrowerOperationsDispatcher, IBorrowerOperationsDispatcherTrait},
    vessel_manager::{IVesselManagerDispatcher, IVesselManagerDispatcherTrait},
    address_provider::{IAddressProviderDispatcher, IAddressProviderDispatcherTrait, AddressesKey},
    admin_contract::{IAdminContractDispatcher, IAdminContractDispatcherTrait},
    fee_collector::{IFeeCollectorDispatcher, IFeeCollectorDispatcherTrait},
    debt_token::{IDebtTokenDispatcher, IDebtTokenDispatcherTrait},
    price_feed::{IPriceFeedDispatcher, IPriceFeedDispatcherTrait},
};
use shisui::mocks::pragma_oracle_mock::{
    IPragmaOracleMockDispatcher, IPragmaOracleMockDispatcherTrait
};
use shisui::pools::active_pool::{IActivePoolDispatcher, IActivePoolDispatcherTrait};
use shisui::pools::default_pool::{IDefaultPoolDispatcher, IDefaultPoolDispatcherTrait};
use snforge_std::PrintTrait;


use tests::tests_lib::{
    deploy_address_provider, deploy_fee_collector, deploy_debt_token, deploy_admin_contract,
    deploy_vessel_manager, deploy_pragma_oracle_mock, deploy_price_feed, deploy_borrower_operations,
    deploy_stability_pool, deploy_active_pool, deploy_default_pool
};


fn setup() -> (
    IBorrowerOperationsDispatcher,
    IVesselManagerDispatcher,
    IAddressProviderDispatcher,
    IAdminContractDispatcher,
    IFeeCollectorDispatcher,
    IDebtTokenDispatcher,
    IPriceFeedDispatcher,
    IPragmaOracleMockDispatcher,
    IActivePoolDispatcher,
    IDefaultPoolDispatcher
) {
    // address provider
    let address_provider_address: ContractAddress = deploy_address_provider();
    let address_provider: IAddressProviderDispatcher = IAddressProviderDispatcher {
        contract_address: address_provider_address
    };

    // active pool
    let active_pool_address = deploy_active_pool(address_provider_address);
    let active_pool = IActivePoolDispatcher { contract_address: active_pool_address };

    // default pool
    let default_pool_address = deploy_default_pool(address_provider_address);
    let default_pool = IDefaultPoolDispatcher { contract_address: default_pool_address };

    // admin contract
    let admin_contract_address: ContractAddress = deploy_admin_contract(address_provider_address);
    let admin_contract: IAdminContractDispatcher = IAdminContractDispatcher {
        contract_address: admin_contract_address
    };

    // fee collector
    let fee_collector_address: ContractAddress = deploy_fee_collector(address_provider_address);
    let fee_collector: IFeeCollectorDispatcher = IFeeCollectorDispatcher {
        contract_address: fee_collector_address
    };

    // debt token
    let debt_token_address: ContractAddress = deploy_debt_token(address_provider_address);
    let debt_token: IDebtTokenDispatcher = IDebtTokenDispatcher {
        contract_address: debt_token_address
    };

    // vessel manager
    let vessel_manager_address: ContractAddress = deploy_vessel_manager(
        address_provider_address, admin_contract_address, fee_collector_address, debt_token_address
    );
    let vessel_manager: IVesselManagerDispatcher = IVesselManagerDispatcher {
        contract_address: vessel_manager_address
    };

    // price feed
    let pragma_mock_address: ContractAddress = deploy_pragma_oracle_mock();
    let pragma_mock: IPragmaOracleMockDispatcher = IPragmaOracleMockDispatcher {
        contract_address: pragma_mock_address
    };

    let price_feed_address: ContractAddress = deploy_price_feed(
        address_provider_address, pragma_mock_address
    );

    let price_feed: IPriceFeedDispatcher = IPriceFeedDispatcher {
        contract_address: price_feed_address
    };

    // borrower operations
    let borrower_operations_address: ContractAddress = deploy_borrower_operations(
        address_provider_address,
        admin_contract_address,
        price_feed_address,
        vessel_manager_address,
        debt_token_address,
        fee_collector_address
    );
    let borrower_operations: IBorrowerOperationsDispatcher = IBorrowerOperationsDispatcher {
        contract_address: borrower_operations_address
    };

    //define address_provider address
    let stability_pool_address = deploy_stability_pool(address_provider_address);

    let timelock_address = contract_address_const::<'timelock'>();
    address_provider.set_address(AddressesKey::timelock, timelock_address);
    address_provider.set_address(AddressesKey::stability_pool, stability_pool_address);
    address_provider.set_address(AddressesKey::active_pool, active_pool_address);
    address_provider.set_address(AddressesKey::default_pool, default_pool_address);
    address_provider.set_address(AddressesKey::admin_contract, admin_contract_address);
    address_provider.set_address(AddressesKey::borrower_operations, borrower_operations_address);
    address_provider.set_address(AddressesKey::debt_token, debt_token_address);

    return (
        borrower_operations,
        vessel_manager,
        address_provider,
        admin_contract,
        fee_collector,
        debt_token,
        price_feed,
        pragma_mock,
        active_pool,
        default_pool
    );
}
