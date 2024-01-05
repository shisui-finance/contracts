use starknet::ContractAddress;
use shisui::core::address_provider::{
    IAddressProviderDispatcher, IAddressProviderDispatcherTrait, AddressesKey
};
use shisui::pools::collateral_surplus_pool::{
    ICollateralSurplusPoolDispatcher, ICollateralSurplusPoolDispatcherTrait
};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use tests::tests_lib::{deploy_address_provider, deploy_erc20_mock, deploy_collateral_surplus_pool};
use tests::utils::callers::{
    active_pool_address, borrower_operations_address, vessel_manager_address
};

fn setup() -> (IAddressProviderDispatcher, ICollateralSurplusPoolDispatcher, IERC20Dispatcher) {
    let address_provider_address: ContractAddress = deploy_address_provider();
    let address_provider: IAddressProviderDispatcher = IAddressProviderDispatcher {
        contract_address: address_provider_address
    };

    let asset_address: ContractAddress = deploy_erc20_mock(6);
    let asset: IERC20Dispatcher = IERC20Dispatcher { contract_address: asset_address };
    let collateral_surplus_pool_address: ContractAddress = deploy_collateral_surplus_pool(
        address_provider_address
    );
    let collateral_surplus_pool: ICollateralSurplusPoolDispatcher =
        ICollateralSurplusPoolDispatcher {
        contract_address: collateral_surplus_pool_address
    };

    address_provider.set_address(AddressesKey::vessel_manager, vessel_manager_address());
    address_provider.set_address(AddressesKey::borrower_operations, borrower_operations_address());
    address_provider.set_address(AddressesKey::active_pool, active_pool_address());

    return (address_provider, collateral_surplus_pool, asset);
}
