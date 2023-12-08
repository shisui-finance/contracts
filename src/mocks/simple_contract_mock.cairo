#[starknet::interface]
trait ISimpleStorage<TContractState> {
    fn set(ref self: TContractState, x: u8);
    fn get(self: @TContractState) -> u8;
}

#[starknet::contract]
mod SimpleStorage {
    use starknet::get_caller_address;
    use starknet::ContractAddress;
    use debug::PrintTrait;

    #[storage]
    struct Storage {
        stored_data: u8
    }

    #[external(v0)]
    impl SimpleStorage of super::ISimpleStorage<ContractState> {
        fn set(ref self: ContractState, x: u8) {
            assert(x < 200, 'Invalid int, must be <= 200');
            self.stored_data.write(x);
        }
        fn get(self: @ContractState) -> u8 {
            self.stored_data.read()
        }
    }
}
