use starknet::ContractAddress;
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

#[starknet::interface]
trait ISHVTStaking<TContractState> {
    fn shvt_token(self: @TContractState) -> IERC20Dispatcher;

    fn stake(ref self: TContractState, shvt_amount: u256);

    fn unstake(ref self: TContractState, shvt_amount: u256);

    fn increase_fee_asset(ref self: TContractState, asset: ContractAddress, asset_fee: u256);
    fn increase_fee_debt_token(ref self: TContractState, shvt_fee: u256);
    fn get_pending_asset_gain(
        self: @TContractState, asset: ContractAddress, user: ContractAddress
    ) -> u256;

    fn get_pending_debt_token_gain(self: @TContractState, user: ContractAddress) -> u256;
}

#[starknet::contract]
mod SHVTStaking {
    use starknet::ContractAddress;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};


    #[storage]
    struct Storage {
        shvt_token: IERC20Dispatcher
    }


    #[external(v0)]
    impl SHVTStakingImpl of super::ISHVTStaking<ContractState> {
        fn shvt_token(self: @ContractState) -> IERC20Dispatcher {
            return self.shvt_token.read();
        }

        fn stake(ref self: ContractState, shvt_amount: u256) {}

        fn unstake(ref self: ContractState, shvt_amount: u256) {}

        fn increase_fee_asset(ref self: ContractState, asset: ContractAddress, asset_fee: u256) {}
        fn increase_fee_debt_token(ref self: ContractState, shvt_fee: u256) {}
        fn get_pending_asset_gain(
            self: @ContractState, asset: ContractAddress, user: ContractAddress
        ) -> u256 {
            return 0;
        }

        fn get_pending_debt_token_gain(self: @ContractState, user: ContractAddress) -> u256 {
            return 0;
        }
    }
}
