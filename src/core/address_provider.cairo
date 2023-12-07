use starknet::ContractAddress;
use shisui::utils::array::{StoreContractAddressSpan};


#[starknet::interface]
trait IAddressProvider<TContractState> {
    fn set_addresses(ref self: TContractState, addresses: Span<ContractAddress>);
    fn set_community_issuance(ref self: TContractState, community_issuance: ContractAddress);
    fn set_shvt_staking(ref self: TContractState, shvt_staking: ContractAddress);
    fn get_active_pool(self: @TContractState) -> ContractAddress;
    fn get_admin_contract(self: @TContractState) -> ContractAddress;
    fn get_borrower_operations(self: @TContractState) -> ContractAddress;
    fn get_coll_surplus_pool(self: @TContractState) -> ContractAddress;
    fn get_community_issuance(self: @TContractState) -> ContractAddress;
    fn get_debt_token(self: @TContractState) -> ContractAddress;
    fn get_default_pool(self: @TContractState) -> ContractAddress;
    fn get_fee_collector(self: @TContractState) -> ContractAddress;
    fn get_gas_pool_address(self: @TContractState) -> ContractAddress;
    fn get_shvt_staking(self: @TContractState) -> ContractAddress;
    fn get_price_feed(self: @TContractState) -> ContractAddress;
    fn get_sorted_vessels(self: @TContractState) -> ContractAddress;
    fn get_stability_pool(self: @TContractState) -> ContractAddress;
    fn get_timelock_address(self: @TContractState) -> ContractAddress;
    fn get_treasury_address(self: @TContractState) -> ContractAddress;
    fn get_vessel_manager(self: @TContractState) -> ContractAddress;
    fn get_vessel_manager_operations(self: @TContractState) -> ContractAddress;
}

#[starknet::contract]
mod AddressProvider {
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
        fn set_addresses(ref self: ContractState, addresses: Span<ContractAddress>) {
            self.ownable.assert_only_owner();
            if (self.is_address_setup_initialized.read()) {
                panic_with_felt252(Errors::AddressProvider__AlreadySet);
            }
            if (addresses.len() != 15) {
                panic_with_felt252(Errors::AddressProvider__Expected15Addresses);
            }

            let mut addr = addresses;
            loop {
                match addr.pop_front() {
                    Option::Some(elem) => self.assert_not_address_zero(*elem),
                    Option::None => { break; },
                }
            };

            self.active_pool.write(*addresses[0]);
            self.admin_contract.write(*addresses[1]);
            self.borrower_operations.write(*addresses[2]);
            self.coll_surplus_pool.write(*addresses[3]);
            self.debt_token.write(*addresses[4]);
            self.default_pool.write(*addresses[5]);
            self.fee_collector.write(*addresses[6]);
            self.gas_pool_address.write(*addresses[7]);
            self.price_feed.write(*addresses[8]);
            self.sorted_vessels.write(*addresses[9]);
            self.stability_pool.write(*addresses[10]);
            self.timelock_address.write(*addresses[11]);
            self.treasury_address.write(*addresses[12]);
            self.vessel_manager.write(*addresses[13]);
            self.vessel_manager_operations.write(*addresses[14]);
            self.is_address_setup_initialized.write(true);
        }


        fn set_community_issuance(ref self: ContractState, community_issuance: ContractAddress) {
            self.ownable.assert_only_owner();
            self.assert_not_address_zero(community_issuance);
            self.community_issuance.write(community_issuance);
        }

        fn set_shvt_staking(ref self: ContractState, shvt_staking: ContractAddress) {
            self.ownable.assert_only_owner();
            self.assert_not_address_zero(shvt_staking);
            self.shvt_staking.write(shvt_staking);
        }

        fn get_active_pool(self: @ContractState) -> ContractAddress {
            return self.active_pool.read();
        }

        fn get_admin_contract(self: @ContractState) -> ContractAddress {
            return self.admin_contract.read();
        }

        fn get_borrower_operations(self: @ContractState) -> ContractAddress {
            return self.borrower_operations.read();
        }

        fn get_coll_surplus_pool(self: @ContractState) -> ContractAddress {
            return self.coll_surplus_pool.read();
        }

        fn get_community_issuance(self: @ContractState) -> ContractAddress {
            return self.community_issuance.read();
        }

        fn get_debt_token(self: @ContractState) -> ContractAddress {
            return self.debt_token.read();
        }

        fn get_default_pool(self: @ContractState) -> ContractAddress {
            return self.default_pool.read();
        }

        fn get_fee_collector(self: @ContractState) -> ContractAddress {
            return self.fee_collector.read();
        }

        fn get_gas_pool_address(self: @ContractState) -> ContractAddress {
            return self.gas_pool_address.read();
        }

        fn get_shvt_staking(self: @ContractState) -> ContractAddress {
            return self.shvt_staking.read();
        }

        fn get_price_feed(self: @ContractState) -> ContractAddress {
            return self.price_feed.read();
        }

        fn get_sorted_vessels(self: @ContractState) -> ContractAddress {
            return self.sorted_vessels.read();
        }

        fn get_stability_pool(self: @ContractState) -> ContractAddress {
            return self.stability_pool.read();
        }

        fn get_timelock_address(self: @ContractState) -> ContractAddress {
            return self.timelock_address.read();
        }

        fn get_treasury_address(self: @ContractState) -> ContractAddress {
            return self.treasury_address.read();
        }

        fn get_vessel_manager(self: @ContractState) -> ContractAddress {
            return self.vessel_manager.read();
        }

        fn get_vessel_manager_operations(self: @ContractState) -> ContractAddress {
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

