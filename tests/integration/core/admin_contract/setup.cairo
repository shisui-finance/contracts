use starknet::{ContractAddress, contract_address_const};
use shisui::core::{
    address_provider::{IAddressProviderDispatcher, IAddressProviderDispatcherTrait, AddressesKey},
    admin_contract::{IAdminContractDispatcher, IAdminContractDispatcherTrait}
};
use shisui::pools::stability_pool::{IStabilityPoolDispatcher, IStabilityPoolDispatcherTrait};

use tests::tests_lib::{deploy_address_provider, deploy_admin_contract, deploy_stability_pool};

fn setup() -> (IAdminContractDispatcher, ContractAddress) {
    let address_provider_address: ContractAddress = deploy_address_provider();
    let address_provider: IAddressProviderDispatcher = IAddressProviderDispatcher {
        contract_address: address_provider_address
    };

    let admin_contract_address: ContractAddress = deploy_admin_contract(address_provider_address);
    let admin_contract: IAdminContractDispatcher = IAdminContractDispatcher {
        contract_address: admin_contract_address
    };

    let stability_pool_address = deploy_stability_pool(address_provider_address);

    let timelock_address = contract_address_const::<'timelock'>();
    address_provider.set_address(AddressesKey::timelock, timelock_address);
    address_provider.set_address(AddressesKey::stability_pool, stability_pool_address);

    return (admin_contract, timelock_address);
}
