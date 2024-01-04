use starknet::ContractAddress;
use shisui::core::{
    vessel_manager::{IVesselManagerDispatcher, IVesselManagerDispatcherTrait},
    address_provider::{IAddressProviderDispatcher, IAddressProviderDispatcherTrait},
    admin_contract::{IAdminContractDispatcher, IAdminContractDispatcherTrait},
    fee_collector::{IFeeCollectorDispatcher, IFeeCollectorDispatcherTrait},
    debt_token::{IDebtTokenDispatcher, IDebtTokenDispatcherTrait},
};


use tests::tests_lib::{
    deploy_address_provider, deploy_fee_collector, deploy_debt_token, deploy_admin_contract,
    deploy_vessel_manager
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

    let admin_contract_address: ContractAddress = deploy_admin_contract();
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
