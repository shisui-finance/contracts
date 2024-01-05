use starknet::ContractAddress;
use shisui::core::address_provider::{
    IAddressProviderDispatcher, IAddressProviderDispatcherTrait, AddressesKey
};
use shisui::pools::active_pool::{IActivePoolDispatcher, IActivePoolDispatcherTrait};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use tests::tests_lib::{deploy_address_provider, deploy_erc20_mock, deploy_active_pool};
use tests::utils::callers::{
    default_pool_address, stability_pool_address, borrower_operations_address,
    vessel_manager_address, vessel_manager_operations_address
};

fn setup() -> (IAddressProviderDispatcher, IActivePoolDispatcher, IERC20Dispatcher) {
    let address_provider_address: ContractAddress = deploy_address_provider();
    let address_provider: IAddressProviderDispatcher = IAddressProviderDispatcher {
        contract_address: address_provider_address
    };

    let asset_address: ContractAddress = deploy_erc20_mock(6);
    let asset: IERC20Dispatcher = IERC20Dispatcher { contract_address: asset_address };
    let active_pool_address: ContractAddress = deploy_active_pool(address_provider_address);
    let active_pool: IActivePoolDispatcher = IActivePoolDispatcher {
        contract_address: active_pool_address
    };

    address_provider.set_address(AddressesKey::vessel_manager, vessel_manager_address());
    address_provider
        .set_address(AddressesKey::vessel_manager_operations, vessel_manager_operations_address());
    address_provider.set_address(AddressesKey::borrower_operations, borrower_operations_address());
    address_provider.set_address(AddressesKey::default_pool, default_pool_address());
    address_provider.set_address(AddressesKey::stability_pool, stability_pool_address());

    return (address_provider, active_pool, asset);
}
