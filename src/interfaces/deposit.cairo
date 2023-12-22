use starknet::ContractAddress;

#[starknet::interface]
trait IDeposit<TContractState> {
    fn received_erc20(ref self: TContractState, asset: ContractAddress, amount: u256);
}
