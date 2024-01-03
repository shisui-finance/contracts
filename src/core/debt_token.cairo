use starknet::ContractAddress;

#[starknet::interface]
trait IDebtToken<TContractState> {
    fn mint(ref self: TContractState, account: ContractAddress, amount: u256);

    fn mint_from_whitelisted_contract(ref self: TContractState, amount: u256);

    fn burn_from_whitelisted_contract(ref self: TContractState, amount: u256);

    fn burn(ref self: TContractState, account: ContractAddress, amount: u256);

    fn add_whitelist(ref self: TContractState, address: ContractAddress);

    fn remove_whitelist(ref self: TContractState, address: ContractAddress);

    fn is_whitelisted(self: @TContractState, address: ContractAddress) -> bool;
}


#[starknet::contract]
mod DebtToken {
    use openzeppelin::access::ownable::ownable::OwnableComponent::InternalTrait as OwnableInternalTrait;
    use shisui::core::debt_token::IDebtToken;
    use openzeppelin::token::erc20::erc20::ERC20Component::InternalTrait as ERC20InternalTrait;
    use shisui::core::address_provider::IAddressProviderDispatcherTrait;
    use starknet::{ContractAddress, get_caller_address};
    use openzeppelin::{
        access::ownable::{OwnableComponent, OwnableComponent::InternalImpl},
        token::erc20::ERC20Component
    };
    use shisui::{
        utils::errors::{CommunErrors, DebtTokenErrors},
        core::address_provider::{IAddressProviderDispatcher, AddressesKey}
    };

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl OwnableImp = OwnableComponent::OwnableImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;

    #[storage]
    struct Storage {
        address_provider: ContractAddress,
        emergency_stop_minting_collateral: LegacyMap::<ContractAddress, bool>,
        whitelisted_contracts: LegacyMap::<ContractAddress, bool>,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        erc20: ERC20Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        ERC20Event: ERC20Component::Event,
        WhitelistChanged: WhitelistChanged,
    }

    #[derive(Drop, starknet::Event)]
    struct WhitelistChanged {
        address: ContractAddress,
        is_whitelisted: bool,
    }

    #[constructor]
    fn constructor(ref self: ContractState, address_provider: ContractAddress) {
        self.ownable.initializer(get_caller_address());
        self.address_provider.write(address_provider);
    }


    #[external(v0)]
    impl DebtTokenImpl of super::IDebtToken<ContractState> {
        fn mint(ref self: ContractState, account: ContractAddress, amount: u256) {
            self.require_caller_is_borrower_operations();
            self.erc20._mint(account, amount);
        }

        fn mint_from_whitelisted_contract(ref self: ContractState, amount: u256) {
            self.require_caller_is_whitelisted_contract();
            self.erc20._mint(get_caller_address(), amount);
        }

        fn burn_from_whitelisted_contract(ref self: ContractState, amount: u256) {
            self.require_caller_is_whitelisted_contract();
            self.erc20._burn(get_caller_address(), amount);
        }

        fn burn(ref self: ContractState, account: ContractAddress, amount: u256) {
            self.require_caller_is_bo_or_vesselm_or_sp();
            self.erc20._burn(account, amount);
        }

        fn add_whitelist(ref self: ContractState, address: ContractAddress) {
            self.ownable.assert_only_owner();
            assert(address.is_non_zero(), CommunErrors::AddressZero);
            self.whitelisted_contracts.write(address, true);
            self.emit(WhitelistChanged { address: address, is_whitelisted: true });
        }

        fn remove_whitelist(ref self: ContractState, address: ContractAddress) {
            self.ownable.assert_only_owner();
            self.whitelisted_contracts.write(address, false);
            self.emit(WhitelistChanged { address: address, is_whitelisted: false });
        }

        fn is_whitelisted(self: @ContractState, address: ContractAddress) -> bool {
            self.whitelisted_contracts.read(address)
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        #[inline(always)]
        fn require_caller_is_whitelisted_contract(self: @ContractState) {
            let caller = get_caller_address();
            assert(self.is_whitelisted(caller) == true, CommunErrors::CallerNotAuthorized);
        }
        #[inline(always)]
        fn require_caller_is_borrower_operations(self: @ContractState) {
            let caller = get_caller_address();
            let address_provider = IAddressProviderDispatcher {
                contract_address: (self.address_provider.read())
            };
            let borrower_operations_manager = address_provider
                .get_address(AddressesKey::borrower_operations);
            assert(caller == borrower_operations_manager, CommunErrors::CallerNotAuthorized);
        }
        #[inline(always)]
        fn require_caller_is_bo_or_vesselm_or_sp(self: @ContractState) {
            let caller = get_caller_address();
            let address_provider = IAddressProviderDispatcher {
                contract_address: (self.address_provider.read())
            };
            let borrower_operations_manager = address_provider
                .get_address(AddressesKey::borrower_operations);
            let vessel_manager = address_provider.get_address(AddressesKey::vessel_manager);
            let stability_pool = address_provider.get_address(AddressesKey::stability_pool);
            assert(
                caller == borrower_operations_manager
                    || caller == vessel_manager
                    || caller == stability_pool,
                CommunErrors::CallerNotAuthorized
            );
        }
        #[inline(always)]
        fn require_caller_is_stability_pool(self: @ContractState) {
            let caller = get_caller_address();
            let address_provider = IAddressProviderDispatcher {
                contract_address: (self.address_provider.read())
            };
            let stability_pool = address_provider.get_address(AddressesKey::stability_pool);
            assert(caller == stability_pool, CommunErrors::CallerNotAuthorized);
        }
        #[inline(always)]
        fn require_caller_is_vesselm_or_sp(self: @ContractState) {
            let caller = get_caller_address();
            let address_provider = IAddressProviderDispatcher {
                contract_address: (self.address_provider.read())
            };
            let vessel_manager = address_provider.get_address(AddressesKey::vessel_manager);
            let stability_pool = address_provider.get_address(AddressesKey::stability_pool);
            assert(
                caller == vessel_manager || caller == stability_pool,
                CommunErrors::CallerNotAuthorized
            );
        }
    }
}
