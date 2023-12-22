#[starknet::interface]
trait IIsCalled<TContractState> {
    fn is_called(self: @TContractState) -> bool;
}

#[starknet::contract]
mod ReceiveERC20Mock {
    use starknet::ContractAddress;
    use shisui::interfaces::deposit::IDeposit;

    #[storage]
    struct Storage {
        is_called: bool,
    }

    #[external(v0)]
    impl DepositImpl of IDeposit<ContractState> {
        fn received_erc20(ref self: ContractState, asset: ContractAddress, amount: u256) {
            self.is_called.write(true);
        }
    }

    #[external(v0)]
    impl IsCalled of super::IIsCalled<ContractState> {
        fn is_called(self: @ContractState) -> bool {
            self.is_called.read()
        }
    }
}
