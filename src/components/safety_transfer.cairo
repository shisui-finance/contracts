//! SafetyTransferComponent used to calculate decimals correction

// *************************************************************************
//                                  IMPORTS
// *************************************************************************
use starknet::{ContractAddress};

// *************************************************************************
//                                  INTERFACE
// *************************************************************************
#[starknet::interface]
trait ISafetyTransfer<TContractState> {
    fn decimals_correction(self: @TContractState, token: ContractAddress, amount: u256) -> u256;
}

// *************************************************************************
//                                  COMPONENT
// *************************************************************************
#[starknet::component]
mod SafetyTransferComponent {
    // *************************************************************************
    //                                  IMPORTS
    // *************************************************************************
    use core::traits::Into;
    use core::traits::Destruct;
    use starknet::{ContractAddress, contract_address_const};
    use openzeppelin::token::erc20::interface::{
        IERC20MetadataDispatcher, IERC20MetadataDispatcherTrait
    };
    use shisui::utils::math::pow;

    // *************************************************************************
    //                              STORAGE
    // *************************************************************************
    #[storage]
    struct Storage {}

    // *************************************************************************
    //                              ERRORS
    // *************************************************************************
    mod Errors {
        const address_0: felt252 = 'Token address is 0';
        const invalid_amount: felt252 = 'invalid_amount';
    }

    // *************************************************************************
    //                              EMBEDDABLE FUNCTIONS
    // *************************************************************************
    #[embeddable_as(SafetyTransferImpl)]
    impl SafetyTransfer<
        TContractState, +HasComponent<TContractState>
    > of super::ISafetyTransfer<ComponentState<TContractState>> {
        fn decimals_correction(
            self: @ComponentState<TContractState>, token: ContractAddress, amount: u256
        ) -> u256 {
            self._decimals_correction(token, amount)
        }
    }

    // *************************************************************************
    //                          INTERNAL FUNCTIONS
    // *************************************************************************
    #[generate_trait]
    impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        /// Returns the name of the token.
        fn _decimals_correction(
            self: @ComponentState<TContractState>, token: ContractAddress, amount: u256
        ) -> u256 {
            assert(
                token != contract_address_const::<0>(),
                super::SafetyTransferComponent::Errors::address_0
            );

            if amount == 0 {
                return 0;
            }

            let erc20 = IERC20MetadataDispatcher { contract_address: token };
            let decimals: u8 = erc20.decimals();
            if decimals < 18 {
                let divisor: u256 = pow(10, 18 - decimals);
                assert(
                    amount % divisor != 0, super::SafetyTransferComponent::Errors::invalid_amount
                );
                return amount / divisor;
            } else {
                if decimals > 18 {
                    let multiplier = pow(10, decimals - 18);
                    return amount * multiplier.into();
                }
            }

            return amount;
        }
    }
}
