use starknet::ContractAddress;
use shisui::core::address_provider::{
    IAddressProviderDispatcher, IAddressProviderDispatcherTrait, AddressesKey
};
use shisui::mocks::receive_erc20_mock::{IIsCalledDispatcher, IIsCalledDispatcherTrait};

use shisui::pools::default_pool::{IDefaultPoolDispatcher, IDefaultPoolDispatcherTrait};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use tests::tests_lib::{
    deploy_address_provider, deploy_receive_erc20_mock, deploy_erc20_mock, deploy_default_pool
};
use tests::utils::callers::{active_pool_address, vessel_manager_address};


fn setup() -> (
    IAddressProviderDispatcher, IDefaultPoolDispatcher, IERC20Dispatcher, IIsCalledDispatcher
) {
    let address_provider_address: ContractAddress = deploy_address_provider();
    let address_provider: IAddressProviderDispatcher = IAddressProviderDispatcher {
        contract_address: address_provider_address
    };

    let asset_address: ContractAddress = deploy_erc20_mock(6);
    let asset: IERC20Dispatcher = IERC20Dispatcher { contract_address: asset_address };

    let default_pool_address: ContractAddress = deploy_default_pool(address_provider_address);
    let default_pool: IDefaultPoolDispatcher = IDefaultPoolDispatcher {
        contract_address: default_pool_address
    };

    let active_pool_address: ContractAddress = deploy_receive_erc20_mock();
    let active_pool: IIsCalledDispatcher = IIsCalledDispatcher {
        contract_address: active_pool_address
    };

    address_provider.set_address(AddressesKey::active_pool, active_pool_address);
    address_provider.set_address(AddressesKey::vessel_manager, vessel_manager_address());

    return (address_provider, default_pool, asset, active_pool);
}
