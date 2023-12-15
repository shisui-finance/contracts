use starknet::ContractAddress;
use shisui::utils::array::{StoreContractAddressSpan};

mod AddressesKey {
    const active_pool: felt252 = 'active_pool';
    const admin_contract: felt252 = 'admin_contract';
    const borrower_operations: felt252 = 'borrower_operations';
    const coll_surplus_pool: felt252 = 'coll_surplus_pool';
    const debt_token: felt252 = 'debt_token';
    const default_pool: felt252 = 'default_pool';
    const fee_collector: felt252 = 'fee_collector';
    const gas_pool: felt252 = 'gas_pool';
    const price_feed: felt252 = 'price_feed';
    const sorted_vessels: felt252 = 'sorted_vessels';
    const stability_pool: felt252 = 'stability_pool';
    const timelock: felt252 = 'timelock';
    const treasury: felt252 = 'treasury';
    const vessel_manager: felt252 = 'vessel_manager';
    const vessel_manager_operations: felt252 = 'vessel_manager_operations';
    const shvt_staking: felt252 = 'shvt_staking';
    const community_issuance: felt252 = 'community_issuance';
}

#[starknet::interface]
trait IAddressProvider<TContractState> {
    fn set_address(ref self: TContractState, key: felt252, address: ContractAddress);
    fn get_address(self: @TContractState, key: felt252) -> ContractAddress;
}

#[starknet::contract]
mod AddressProvider {
    use core::zeroable::Zeroable;
    use starknet::{ContractAddress, get_caller_address};
    use openzeppelin::access::ownable::OwnableComponent;
    use shisui::utils::errors::CommunErrors;
    use super::AddressesKey;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        addresses: LegacyMap<felt252, ContractAddress>,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        NewAddressRegistered: NewAddressRegistered,
    }


    #[derive(Drop, starknet::Event)]
    struct NewAddressRegistered {
        key: felt252,
        address: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.ownable.initializer(get_caller_address());
    }

    #[external(v0)]
    impl AddressProviderImpl of super::IAddressProvider<ContractState> {
        fn set_address(ref self: ContractState, key: felt252, address: ContractAddress) {
            self.assert_address_not_zero(address);
            self._require_owner_or_timelock(self.addresses.read(key).is_zero());
            self.addresses.write(key, address);
            self.emit(NewAddressRegistered { key, address });
        }

        fn get_address(self: @ContractState, key: felt252) -> ContractAddress {
            return self.addresses.read(key);
        }
    }

    #[generate_trait]
    impl AddressProviderInternalImpl of AddressProviderInternalTrait {
        #[inline(always)]
        fn assert_address_not_zero(ref self: ContractState, address: ContractAddress) {
            assert(address.is_non_zero(), CommunErrors::CommunErrors__AddressZero);
        }

        #[inline(always)]
        fn _require_owner_or_timelock(self: @ContractState, is_new: bool) {
            let caller = get_caller_address();
            if (is_new) {
                self.ownable.assert_only_owner();
            } else {
                assert(
                    caller == self.addresses.read(AddressesKey::timelock),
                    CommunErrors::CommunErrors__OnlyTimelock
                );
            }
        }
    }
}

