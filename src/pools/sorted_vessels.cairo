use starknet::ContractAddress;


#[starknet::interface]
trait ISortedVessels<TContractState> {
    fn insert(
        ref self: TContractState,
        asset: ContractAddress,
        id: ContractAddress,
        NICR: u256,
        prev_id: ContractAddress,
        next_id: ContractAddress
    );
    fn re_insert(
        ref self: TContractState,
        asset: ContractAddress,
        id: ContractAddress,
        new_NICR: u256,
        prev_id: ContractAddress,
        next_id: ContractAddress
    );
    fn remove(ref self: TContractState, asset: ContractAddress, id: ContractAddress);
    fn contains(
        self: @TContractState,
        asset: ContractAddress,
        id: ContractAddress,
        NICR: u256,
        prev_id: ContractAddress,
        next_id: ContractAddress
    ) -> bool;
    fn is_empty(self: @TContractState, asset: ContractAddress) -> bool;
    fn get_size(self: @TContractState) -> usize;
    fn get_first(self: @TContractState, asset: ContractAddress) -> ContractAddress;
    fn get_last(self: @TContractState, asset: ContractAddress) -> ContractAddress;
    fn get_next(
        self: @TContractState, asset: ContractAddress, id: ContractAddress
    ) -> ContractAddress;
    fn get_prev(
        self: @TContractState, asset: ContractAddress, id: ContractAddress
    ) -> ContractAddress;
    fn valid_insert_position(
        self: @TContractState,
        asset: ContractAddress,
        NICR: u256,
        prev_id: ContractAddress,
        next_id: ContractAddress
    ) -> bool;
    fn find_insert_position(
        self: @TContractState,
        asset: ContractAddress,
        NICR: u256,
        prev_id: ContractAddress,
        next_id: ContractAddress
    ) -> (ContractAddress, ContractAddress);
}

/// A sorted doubly linked list with nodes sorted in descending order.
///
/// Nodes map to active Vessels in the system - the ID property is the address of a Vessel owner.
/// Nodes are ordered according to their current nominal individual collateral ratio (NICR),
/// which is like the ICR but without the price, i.e., just collateral / debt.
///
/// The list optionally accepts insert position hints.
///
/// NICRs are computed dynamically at runtime, and not stored on the Node. This is because NICRs of active Vessels
/// change dynamically as liquidation events occur.
///
/// The list relies on the fact that liquidation events preserve ordering: a liquidation decreases the NICRs of all active Vessels,
/// but maintains their order. A node inserted based on current NICR will maintain the correct position,
/// relative to it's peers, as rewards accumulate, as long as it's raw collateral and debt have not changed.
/// Thus, Nodes remain sorted by current NICR.
///
/// Nodes need only be re-inserted upon a Vessel operation - when the owner adds or removes collateral or debt
/// to their position.
///
/// The list is a modification of the following audited SortedDoublyLinkedList:
/// https://github.com/livepeer/protocol/blob/master/contracts/libraries/SortedDoublyLL.sol
///
///
/// Changes made in the Gravita implementation:
///
/// - Keys have been removed from nodes
///
/// - Ordering checks for insertion are performed by comparing an NICR argument to the current NICR, calculated at runtime.
///   The list relies on the property that ordering by ICR is maintained as the ETH:USD price varies.
///
/// - Public functions with parameters have been made internal to save gas, and given an external wrapper function for external access
#[starknet::contract]
mod SortedVessels {
    use starknet::ContractAddress;
    use shisui::utils::traits::ContractAddressDefault;
    use shisui::core::address_provider::{
        IAddressProviderDispatcher, IAddressProviderDispatcherTrait
    };

    // Information for a node in the list
    #[derive(Serde, Drop, Copy, starknet::Store, Default)]
    struct Node {
        exist: bool,
        // Id of next node (smaller NICR) in the list
        next_id: ContractAddress,
        // Id of previous node (larger NICR) in the list
        prev_id: ContractAddress,
    }

    // Information for the list
    #[derive(Serde, Drop, Copy, starknet::Store, Default)]
    struct Data {
        // Head of the list. Also the node in the list with the largest NICR
        head: ContractAddress,
        // Tail of the list. Also the node in the list with the smallest NICR
        tail: ContractAddress,
        // Current size of the list
        size: usize,
    }

    #[storage]
    struct Storage {
        address_provider: IAddressProviderDispatcher,
        // asset => ordered list
        data: LegacyMap<ContractAddress, Data>,
        // asset address => depositor address => node | Track the corresponding ids for each node in the list
        nodes: LegacyMap<(ContractAddress, ContractAddress), Node>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, address_provider: IAddressProviderDispatcher) {}

    #[external(v0)]
    impl SortedVesselsImpl of super::ISortedVessels<ContractState> {
        /// @dev Add a node to the list
        /// @param id Node's id
        /// @param NICR Node's NICR
        /// @param prev_id Id of previous node for the insert position
        /// @param next_id Id of next node for the insert position
        fn insert(
            ref self: ContractState,
            asset: ContractAddress,
            id: ContractAddress,
            NICR: u256,
            prev_id: ContractAddress,
            next_id: ContractAddress
        ) {}

        /// @dev Re-insert the node at a new position, based on its new NICR
        /// @param id Node's id
        /// @param new_nicr Node's new NICR
        /// @param prev_id Id of previous node for the new insert position
        /// @param next_id Id of next node for the new insert position
        fn re_insert(
            ref self: ContractState,
            asset: ContractAddress,
            id: ContractAddress,
            new_NICR: u256,
            prev_id: ContractAddress,
            next_id: ContractAddress
        ) {}

        /// @dev Remove a node from the list
        /// @param id Node's id
        fn remove(ref self: ContractState, asset: ContractAddress, id: ContractAddress) {}

        /// @dev Checks if the list contains a node
        fn contains(
            self: @ContractState,
            asset: ContractAddress,
            id: ContractAddress,
            NICR: u256,
            prev_id: ContractAddress,
            next_id: ContractAddress
        ) -> bool {
            return false;
        }

        /// @dev Checks if the list is empty
        fn is_empty(self: @ContractState, asset: ContractAddress) -> bool {
            return false;
        }

        /// @dev Returns the current size of the list
        fn get_size(self: @ContractState) -> usize {
            return 0;
        }

        /// @dev Returns the first node in the list (node with the largest NICR)
        fn get_first(self: @ContractState, asset: ContractAddress) -> ContractAddress {
            return Default::default();
        }

        /// @dev Returns the last node in the list (node with the smallest NICR)
        fn get_last(self: @ContractState, asset: ContractAddress) -> ContractAddress {
            return Default::default();
        }

        /// @dev Returns the next node (with a smaller NICR) in the list for a given node
        /// @param id Node's id
        fn get_next(
            self: @ContractState, asset: ContractAddress, id: ContractAddress
        ) -> ContractAddress {
            return Default::default();
        }

        /// @dev Returns the previous node (with a larger NICR) in the list for a given node
        /// @param _id Node's id
        fn get_prev(
            self: @ContractState, asset: ContractAddress, id: ContractAddress
        ) -> ContractAddress {
            return Default::default();
        }

        /// @dev Check if a pair of nodes is a valid insertion point for a new node with the given NICR
        /// @param NICR Node's NICR
        /// @param prev_id Id of previous node for the insert position
        /// @param next_id Id of next node for the insert position
        fn valid_insert_position(
            self: @ContractState,
            asset: ContractAddress,
            NICR: u256,
            prev_id: ContractAddress,
            next_id: ContractAddress
        ) -> bool {
            return false;
        }

        /// @dev Find the insert position for a new node with the given NICR
        /// @param NICR Node's NICR
        /// @param prev_id Id of previous node for the insert position
        /// @param next_id Id of next node for the insert position
        fn find_insert_position(
            self: @ContractState,
            asset: ContractAddress,
            NICR: u256,
            prev_id: ContractAddress,
            next_id: ContractAddress
        ) -> (ContractAddress, ContractAddress) {
            return (Default::default(), Default::default());
        }
    }
}
