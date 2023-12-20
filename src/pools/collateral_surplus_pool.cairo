use starknet::ContractAddress;

#[starknet::interface]
trait ICollateralSurplusPool<TContractState> {
    fn account_surplus(
        ref self: TContractState, asset: ContractAddress, account: ContractAddress, amount: u256
    );

    fn claim_coll(ref self: TContractState, asset: ContractAddress, account: ContractAddress);

    fn received_erc20(ref self: TContractState, asset: ContractAddress, amount: u256);

    fn get_asset_balance(self: @TContractState, asset: ContractAddress) -> u256;

    fn get_collateral(
        self: @TContractState, asset: ContractAddress, account: ContractAddress
    ) -> u256;
}


#[starknet::contract]
mod CollateralSurplusPool {
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use openzeppelin::{
        token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait},
        access::ownable::{OwnableComponent, OwnableComponent::InternalImpl}
    };
    use shisui::core::address_provider::{
        IAddressProviderDispatcher, IAddressProviderDispatcherTrait, AddressesKey
    };
    use shisui::utils::{
        errors::CommunErrors, asserts::assert_address_non_zero, convert::decimals_correction
    };

    use snforge_std::PrintTrait;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);


    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;

    #[storage]
    struct Storage {
        address_provider: IAddressProviderDispatcher,
        // deposited ether tracker
        balances: LegacyMap<ContractAddress, u256>,
        // Collateral surplus claimable by vessel owners
        user_balances: LegacyMap<(ContractAddress, ContractAddress), u256>,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        CollBalanceUpdated: CollBalanceUpdated,
        AssetSent: AssetSent
    }


    #[derive(Drop, starknet::Event)]
    struct CollBalanceUpdated {
        account: ContractAddress,
        asset: ContractAddress,
        old_balance: u256,
        new_balance: u256,
    }


    #[derive(Drop, starknet::Event)]
    struct AssetSent {
        account: ContractAddress,
        asset: ContractAddress,
        amount: u256,
    }

    mod Errors {
        const CollateralSurplusPool__CallerNotVesselManager: felt252 = 'Caller not Vessel Manager';
        const CollateralSurplusPool__CallerNotActivePool: felt252 = 'Caller not Active Pool';
        const CollateralSurplusPool__CallerNotBorrowerOperation: felt252 =
            'Caller not Borrower Operation';
        const CollateralSurplusPool__NoCollateralToClaim: felt252 = 'No collateral to claim';
    }

    #[constructor]
    fn constructor(ref self: ContractState, address_provider: IAddressProviderDispatcher) {
        assert_address_non_zero(address_provider.contract_address);
        self.address_provider.write(address_provider);
    }

    #[external(v0)]
    impl CollateralSurplusPoolImpl of super::ICollateralSurplusPool<ContractState> {
        fn account_surplus(
            ref self: ContractState, asset: ContractAddress, account: ContractAddress, amount: u256
        ) {
            self.assert_caller_is_vessel_manager();
            let user_balance = self.user_balances.read((account, asset));
            self.user_balances.write((account, asset), user_balance + amount);
            self
                .emit(
                    CollBalanceUpdated {
                        account,
                        asset,
                        old_balance: user_balance,
                        new_balance: user_balance + amount
                    }
                )
        }

        fn claim_coll(ref self: ContractState, asset: ContractAddress, account: ContractAddress) {
            self.assert_caller_is_borrower_operation();
            let claimable_coll_ether = self.user_balances.read((account, asset));
            let safety_transferclaimable_coll = decimals_correction(asset, claimable_coll_ether);
            assert(
                safety_transferclaimable_coll.is_non_zero(),
                Errors::CollateralSurplusPool__NoCollateralToClaim
            );
            self.user_balances.write((account, asset), 0);
            self
                .emit(
                    CollBalanceUpdated {
                        account, asset, old_balance: claimable_coll_ether, new_balance: 0
                    }
                );
            self.balances.write(asset, self.balances.read(asset) - safety_transferclaimable_coll);
            self.emit(AssetSent { account, asset, amount: safety_transferclaimable_coll });
            // TODO : NO TRANSFER HPN
            IERC20Dispatcher { contract_address: asset }
                .transfer(account, safety_transferclaimable_coll);
        }

        fn received_erc20(ref self: ContractState, asset: ContractAddress, amount: u256) {
            self.assert_caller_is_active_pool();
            self.balances.write(asset, self.balances.read(asset) + amount);
        }

        /// Returns the Asset state variable at ActivePool address.
        /// Not necessarily equal to the raw ether balance - ether can be forcibly sent to contracts.
        fn get_asset_balance(self: @ContractState, asset: ContractAddress) -> u256 {
            return self.balances.read(asset);
        }

        fn get_collateral(
            self: @ContractState, asset: ContractAddress, account: ContractAddress
        ) -> u256 {
            return self.user_balances.read((account, asset));
        }
    }

    #[generate_trait]
    impl CollSurplusPoolInternalImpl of CollSurplusPoolInternalImplTrait {
        #[inline(always)]
        fn assert_caller_is_vessel_manager(self: @ContractState) {
            let caller = get_caller_address();
            let address_provider = self.address_provider.read();
            assert(
                caller == address_provider.get_address(AddressesKey::vessel_manager)
                    || caller == address_provider
                        .get_address(AddressesKey::vessel_manager_operations),
                Errors::CollateralSurplusPool__CallerNotVesselManager
            );
        }

        #[inline(always)]
        fn assert_caller_is_active_pool(self: @ContractState) {
            let caller = get_caller_address();
            let address_provider = self.address_provider.read();
            assert(
                caller == address_provider.get_address(AddressesKey::active_pool),
                Errors::CollateralSurplusPool__CallerNotActivePool
            );
        }

        #[inline(always)]
        fn assert_caller_is_borrower_operation(self: @ContractState) {
            let caller = get_caller_address();
            let address_provider = self.address_provider.read();
            assert(
                caller == address_provider.get_address(AddressesKey::borrower_operations),
                Errors::CollateralSurplusPool__CallerNotBorrowerOperation
            );
        }
    }
}
