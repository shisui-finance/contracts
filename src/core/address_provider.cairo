use starknet::ContractAddress;

#[starknet::interface]
trait IAddressProvider<TContractState> {
    fn set_addresses(ref self: TContractState, _addresses: Array<ContractAddress>);
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
    fn get_grvt_staking(ref self: TContractState) -> ContractAddress;
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
    use starknet::ContractAddress;

    #[storage]
    struct Storage {
        active_pool: ContractAddress,
        admin_contract: ContractAddress,
        borrower_operations: ContractAddress,
        coll_surplus_pool: ContractAddress,
        community_issuance: ContractAddress,
        debt_token: ContractAddress,
        default_pool: ContractAddress,
        fee_collector: ContractAddress,
        gas_pool_address: ContractAddress,
        grvt_staking: ContractAddress,
        price_feed: ContractAddress,
        sorted_vessels: ContractAddress,
        stability_pool: ContractAddress,
        timelock_address: ContractAddress,
        treasury_address: ContractAddress,
        vessel_manager: ContractAddress,
        vessel_manager_operations: ContractAddress,
    }

    #[external(v0)]
    impl AddressProviderImpl of super::IAddressProvider<ContractState> {
        fn set_addresses(ref self: ContractState, _addresses: Array<ContractAddress>) {}

        fn set_community_issuance(ref self: ContractState, _community_issuance: ContractAddress) {}

        fn set_shvt_staking(ref self: ContractState, _shvt_staking: ContractAddress) {}

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

        fn get_grvt_staking(ref self: ContractState) -> ContractAddress {
            return self.grvt_staking.read();
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
}

