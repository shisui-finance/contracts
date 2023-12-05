// do nothing, as the core contracts have permission to send to and burn from this address
#[starknet::contract]
mod GasPool {
    #[storage]
    struct Storage {}
}
