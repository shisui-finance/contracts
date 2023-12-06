use starknet::ContractAddress;
use shisui::utils::array::{StoreContractAddressSpan};


#[starknet::interface]
trait IAddressProvider<TContractState> {
    fn set_addresses(ref self: TContractState, _addresses: Span<ContractAddress>);
    fn set_community_issuance(ref self: TContractState, _community_issuance: ContractAddress);
    fn set_shvt_staking(ref self: TContractState, _shvt_staking: ContractAddress);
    fn get_active_pool(ref self: TContractState) -> ContractAddress;
    fn get_admin_contract(ref self: TContractState) -> ContractAddress;
    fn get_borrower_operations(ref self: TContractState) -> ContractAddress;
    fn get_coll_surplus_pool(ref self: TContractState) -> ContractAddress;
    fn get_community_issuance(ref self: TContractState) -> ContractAddress;
    fn get_debt_token(ref self: TContractState) -> ContractAddress;
    fn get_default_pool(ref self: TContractState) -> ContractAddress;
    fn get_fee_collector(ref self: TContractState) -> ContractAddress;
    fn get_gas_pool_address(ref self: TContractState) -> ContractAddress;
    fn get_shvt_staking(ref self: TContractState) -> ContractAddress;
    fn get_price_feed(ref self: TContractState) -> ContractAddress;
    fn get_sorted_vessels(ref self: TContractState) -> ContractAddress;
    fn get_stability_pool(ref self: TContractState) -> ContractAddress;
    fn get_timelock_address(ref self: TContractState) -> ContractAddress;
    fn get_treasury_address(ref self: TContractState) -> ContractAddress;
    fn get_vessel_manager(ref self: TContractState) -> ContractAddress;
    fn get_vessel_manager_operations(ref self: TContractState) -> ContractAddress;
}

#[starknet::contract]
mod AddressProvider {
    use openzeppelin::access::ownable::ownable::OwnableComponent::InternalTrait;
    use starknet::{ContractAddress, get_caller_address};
    use openzeppelin::access::ownable::OwnableComponent;
    use shisui::utils::errors::CommunErrors;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        is_address_setup_initialized: bool,
        active_pool: ContractAddress,
        admin_contract: ContractAddress,
        borrower_operations: ContractAddress,
        coll_surplus_pool: ContractAddress,
        community_issuance: ContractAddress,
        debt_token: ContractAddress,
        default_pool: ContractAddress,
        fee_collector: ContractAddress,
        gas_pool_address: ContractAddress,
        shvt_staking: ContractAddress,
        price_feed: ContractAddress,
        sorted_vessels: ContractAddress,
        stability_pool: ContractAddress,
        timelock_address: ContractAddress,
        treasury_address: ContractAddress,
        vessel_manager: ContractAddress,
        vessel_manager_operations: ContractAddress,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event
    }

    mod Errors {
        const AddressProvider__AlreadySet: felt252 = 'Protocol addresses already set';
        const AddressProvider__Expected15Addresses: felt252 = 'Expected 15 addresses';
    }
    #[constructor]
    fn constructor(ref self: ContractState) {
        self.ownable.initializer(get_caller_address());
    }

    #[external(v0)]
    impl AddressProviderImpl of super::IAddressProvider<ContractState> {
        fn set_addresses(ref self: ContractState, _addresses: Span<ContractAddress>) {
            self.ownable.assert_only_owner();
            if (self.is_address_setup_initialized.read()) {
                panic_with_felt252(Errors::AddressProvider__AlreadySet);
            }
            if (_addresses.len() != 15) {
                panic_with_felt252(Errors::AddressProvider__Expected15Addresses);
            }

            let mut addr = _addresses;
            loop {
                match addr.pop_front() {
                    Option::Some(elem) => self.assert_not_address_zero(*elem),
                    Option::None => { break; },
                }
            };

            self.active_pool.write(*_addresses[0]);
            self.admin_contract.write(*_addresses[1]);
            self.borrower_operations.write(*_addresses[2]);
            self.coll_surplus_pool.write(*_addresses[3]);
            self.debt_token.write(*_addresses[4]);
            self.default_pool.write(*_addresses[5]);
            self.fee_collector.write(*_addresses[6]);
            self.gas_pool_address.write(*_addresses[7]);
            self.price_feed.write(*_addresses[8]);
            self.sorted_vessels.write(*_addresses[9]);
            self.stability_pool.write(*_addresses[10]);
            self.timelock_address.write(*_addresses[11]);
            self.treasury_address.write(*_addresses[12]);
            self.vessel_manager.write(*_addresses[13]);
            self.vessel_manager_operations.write(*_addresses[14]);
            self.is_address_setup_initialized.write(true);
        }


        fn set_community_issuance(ref self: ContractState, _community_issuance: ContractAddress) {
            self.ownable.assert_only_owner();
            self.assert_not_address_zero(_community_issuance);
            self.community_issuance.write(_community_issuance);
        }

        fn set_shvt_staking(ref self: ContractState, _shvt_staking: ContractAddress) {
            self.ownable.assert_only_owner();
            self.assert_not_address_zero(_shvt_staking);
            self.community_issuance.write(_shvt_staking);
        }

        fn get_active_pool(ref self: ContractState) -> ContractAddress {
            return self.active_pool.read();
        }

        fn get_admin_contract(ref self: ContractState) -> ContractAddress {
            return self.admin_contract.read();
        }

        fn get_borrower_operations(ref self: ContractState) -> ContractAddress {
            return self.borrower_operations.read();
        }

        fn get_coll_surplus_pool(ref self: ContractState) -> ContractAddress {
            return self.coll_surplus_pool.read();
        }

        fn get_community_issuance(ref self: ContractState) -> ContractAddress {
            return self.community_issuance.read();
        }

        fn get_debt_token(ref self: ContractState) -> ContractAddress {
            return self.debt_token.read();
        }

        fn get_default_pool(ref self: ContractState) -> ContractAddress {
            return self.default_pool.read();
        }

        fn get_fee_collector(ref self: ContractState) -> ContractAddress {
            return self.fee_collector.read();
        }

        fn get_gas_pool_address(ref self: ContractState) -> ContractAddress {
            return self.gas_pool_address.read();
        }

        fn get_shvt_staking(ref self: ContractState) -> ContractAddress {
            return self.shvt_staking.read();
        }

        fn get_price_feed(ref self: ContractState) -> ContractAddress {
            return self.price_feed.read();
        }

        fn get_sorted_vessels(ref self: ContractState) -> ContractAddress {
            return self.sorted_vessels.read();
        }

        fn get_stability_pool(ref self: ContractState) -> ContractAddress {
            return self.stability_pool.read();
        }

        fn get_timelock_address(ref self: ContractState) -> ContractAddress {
            return self.timelock_address.read();
        }

        fn get_treasury_address(ref self: ContractState) -> ContractAddress {
            return self.treasury_address.read();
        }

        fn get_vessel_manager(ref self: ContractState) -> ContractAddress {
            return self.vessel_manager.read();
        }

        fn get_vessel_manager_operations(ref self: ContractState) -> ContractAddress {
            return self.vessel_manager_operations.read();
        }
    }

    #[generate_trait]
    impl AddressProviderInternalImpl of AddressProviderInternalTrait {
        fn assert_not_address_zero(ref self: ContractState, address: ContractAddress) {
            if (address.is_zero()) {
                panic_with_felt252(CommunErrors::CommunErrors__AddressZero);
            }
        }
    }
}

