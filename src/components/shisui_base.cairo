use starknet::ContractAddress;
use shisui::utils::array::{StoreContractAddressArray, StoreU256Array};

#[derive(Drop, Clone, starknet::Store, Serde)]
struct Colls {
    tokens: Array<ContractAddress>,
    amounts: Array<u256>,
}

#[starknet::component]
mod ShisuiBaseComponent {
    use starknet::ContractAddress;

    #[storage]
    struct Storage {
        address_provider: ContractAddress,
    }

    #[generate_trait]
    impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        fn get_composite_debt(_asset: ContractAddress, _debt: u256) -> u256 {
            return 0;
        }

        fn get_net_debt(_asset: ContractAddress, _debt: u256) -> u256 {
            return 0;
        }

        // Return the amount of ETH to be drawn from a vessel's collateral and sent as gas compensation.
        fn get_coll_gas_compensation(_asset: ContractAddress, _entire_coll: u256,) -> u256 {
            return 0;
        }

        fn get_entire_system_coll(_asset: ContractAddress) -> u256 {
            return 0;
        }

        fn get_entire_system_debt(_asset: ContractAddress) -> u256 {
            return 0;
        }

        fn get_TCR(
            self: @ComponentState<TContractState>, _asset: ContractAddress, _price: u256
        ) -> u256 {
            return 0;
        }

        fn check_recovery_mode(
            self: @ComponentState<TContractState>, _asset: ContractAddress, _price: u256
        ) -> bool {
            return true;
        }

        fn require_user_accepts_fee(_fee: u256, _amount: u256, _max_fee_percentage: u256) {}
    }
}
