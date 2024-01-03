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
    fn get_size(self: @TContractState, asset: ContractAddress) -> usize;
    fn get_first(self: @TContractState, asset: ContractAddress) -> ContractAddress;
    fn get_last(self: @TContractState, asset: ContractAddress) -> ContractAddress;
    fn get_next(
        self: @TContractState, asset: ContractAddress, id: ContractAddress
    ) -> ContractAddress;
    fn get_prev(
        self: @TContractState, asset: ContractAddress, id: ContractAddress
    ) -> ContractAddress;
    fn is_valid_insert_position(
        self: @TContractState,
        asset: ContractAddress,
        NICR: u256,
        prev_id: ContractAddress,
        next_id: ContractAddress
    ) -> bool;
    fn get_insert_position(
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
    // use shisui::pools::sorted_vessels::ISortedVessels;
    use core::option::{OptionTrait};
    use zeroable::Zeroable;
    use starknet::{ContractAddress, contract_address_const, get_caller_address};
    use shisui::{
        utils::{traits::ContractAddressDefault, errors::{CommunErrors, SortedVesselsErrors}},
        core::{
            address_provider::{
                IAddressProviderDispatcher, IAddressProviderDispatcherTrait, AddressesKey
            }
        },
        pools::vessel_manager::{IVesselManagerDispatcher, IVesselManagerDispatcherTrait}
    };

    use debug::PrintTrait;

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        NodeAdded: NodeAdded,
        NodeRemoved: NodeRemoved
    }

    #[derive(Drop, starknet::Event)]
    struct NodeAdded {
        asset: ContractAddress,
        id: ContractAddress,
        NICR: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct NodeRemoved {
        asset: ContractAddress,
        id: ContractAddress,
    }

    // Information for a node in the list
    #[derive(Serde, Drop, Copy, starknet::Store, Default)]
    struct Node {
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
        nodes: LegacyMap<(ContractAddress, ContractAddress), Option<Node>>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, address_provider: IAddressProviderDispatcher) {
        self.address_provider.write(address_provider);
    }

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
        ) {
            self.require_caller_is_bo_or_vm();
            self.int_insert(asset, id, NICR, prev_id, next_id);
        }

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
        ) {
            self.require_caller_is_bo_or_vm();
            // List must contain the node
            assert(self.nodes.read((asset, id)).is_some(), SortedVesselsErrors::NodeDoesntExist);
            // NICR must be non-zero
            assert(new_NICR.is_non_zero(), SortedVesselsErrors::NICRMustBePositive);

            self.int_remove(asset, id);
            self.int_insert(asset, id, new_NICR, prev_id, next_id);
        }

        /// @dev Remove a node from the list
        /// @param id Node's id
        fn remove(ref self: ContractState, asset: ContractAddress, id: ContractAddress) {
            let caller = get_caller_address();
            let vessel_manager = self
                .address_provider
                .read()
                .get_address(AddressesKey::vessel_manager);
            assert(caller == vessel_manager, CommunErrors::CommunErrors__CallerNotAuthorized);
            self.int_remove(asset, id);
        }

        /// @dev Checks if the list contains a node
        fn contains(
            self: @ContractState,
            asset: ContractAddress,
            id: ContractAddress,
            NICR: u256,
            prev_id: ContractAddress,
            next_id: ContractAddress
        ) -> bool {
            match self.nodes.read((asset, id)) {
                Option::Some(node) => true,
                Option::None => false
            }
        }

        /// @dev Checks if the list is empty
        fn is_empty(self: @ContractState, asset: ContractAddress) -> bool {
            return self.data.read(asset).size == 0;
        }

        /// @dev Returns the current size of the list
        fn get_size(self: @ContractState, asset: ContractAddress) -> usize {
            return self.data.read(asset).size;
        }

        /// @dev Returns the first node in the list (node with the largest NICR)
        fn get_first(self: @ContractState, asset: ContractAddress) -> ContractAddress {
            return self.data.read(asset).head;
        }

        /// @dev Returns the last node in the list (node with the smallest NICR)
        fn get_last(self: @ContractState, asset: ContractAddress) -> ContractAddress {
            return self.data.read(asset).tail;
        }

        /// @dev Returns the next node (with a smaller NICR) in the list for a given node
        /// @param id Node's id
        fn get_next(
            self: @ContractState, asset: ContractAddress, id: ContractAddress
        ) -> ContractAddress {
            return self.nodes.read((asset, id)).unwrap().next_id;
        }

        /// @dev Returns the previous node (with a larger NICR) in the list for a given node
        /// @param _id Node's id
        fn get_prev(
            self: @ContractState, asset: ContractAddress, id: ContractAddress
        ) -> ContractAddress {
            return self.nodes.read((asset, id)).unwrap().prev_id;
        }

        /// @dev Check if a pair of nodes is a valid insertion point for a new node with the given NICR
        /// @param NICR Node's NICR
        /// @param prev_id Id of previous node for the insert position
        /// @param next_id Id of next node for the insert position
        fn is_valid_insert_position(
            self: @ContractState,
            asset: ContractAddress,
            NICR: u256,
            prev_id: ContractAddress,
            next_id: ContractAddress
        ) -> bool {
            return self.int_valid_insert_position(asset, NICR, prev_id, next_id);
        }

        /// @dev Find the insert position for a new node with the given NICR
        /// @param NICR Node's NICR
        /// @param prev_id Id of previous node for the insert position
        /// @param next_id Id of next node for the insert position
        fn get_insert_position(
            self: @ContractState,
            asset: ContractAddress,
            NICR: u256,
            prev_id: ContractAddress,
            next_id: ContractAddress
        ) -> (ContractAddress, ContractAddress) {
            return self.int_find_insert_point(asset, NICR, prev_id, next_id);
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        #[inline(always)]
        fn int_insert(
            ref self: ContractState,
            asset: ContractAddress,
            id: ContractAddress,
            NICR: u256,
            prev_id: ContractAddress,
            next_id: ContractAddress
        ) {
            assert(self.nodes.read((asset, id)).is_none(), SortedVesselsErrors::NodeAlreadyExists);
            assert(id.is_non_zero(), CommunErrors::CommunErrors__AddressZero);
            assert(NICR.is_non_zero(), SortedVesselsErrors::NICRMustBePositive);

            let mut prev_id = prev_id;
            let mut next_id = next_id;

            if (!self.int_valid_insert_position(asset, NICR, prev_id, next_id)) {
                'invalid insert position'.print();
                // Sender's hint was not a valid insert position
                // Use sender's hint to find a valid insert position
                let (new_prev_id, new_next_id) = self
                    .int_find_insert_point(asset, NICR, prev_id, next_id);
                prev_id = new_prev_id;
                next_id = new_next_id;

                prev_id.print();
                next_id.print();
            }

            let mut new_node = Node { prev_id: prev_id, next_id: next_id, };
            let mut new_data = self.data.read(asset);
            new_data.size += 1;

            if (prev_id.is_zero() && next_id.is_zero()) {
                // Insert as head and tail
                new_data.head = id;
                new_data.tail = id;
            } else if (prev_id.is_zero()) {
                // Insert before `prevId` as the head
                new_node.next_id = new_data.head;
                let mut head_node = self.nodes.read((asset, new_data.head)).unwrap();
                head_node.prev_id = id;
                self.nodes.write((asset, new_data.head), Option::Some(head_node));
                new_data.head = id;
            } else if (next_id.is_zero()) {
                // Insert after `nextId` as the tail
                new_node.prev_id = new_data.tail;
                let mut tail_node = self.nodes.read((asset, new_data.tail)).unwrap();
                tail_node.next_id = id;
                self.nodes.write((asset, new_data.tail), Option::Some(tail_node));
                new_data.tail = id;
            } else {
                // Insert at insert position between `prevId` and `nextId`
                new_node.prev_id = prev_id;
                new_node.next_id = next_id;
                let mut prev_node = self.nodes.read((asset, prev_id)).unwrap();
                let mut next_node = self.nodes.read((asset, next_id)).unwrap();
                prev_node.next_id = id;
                next_node.prev_id = id;
                self.nodes.write((asset, prev_id), Option::Some(prev_node));
                self.nodes.write((asset, next_id), Option::Some(next_node));
            }

            self.nodes.write((asset, id), Option::Some(new_node));
            self.data.write(asset, new_data);

            self.emit(NodeAdded { asset: asset, id: id, NICR: NICR, })
        }

        #[inline(always)]
        fn int_remove(ref self: ContractState, asset: ContractAddress, id: ContractAddress) {
            // List must contain the node
            assert(self.nodes.read((asset, id)).is_some(), SortedVesselsErrors::NodeDoesntExist);

            let mut node = self.nodes.read((asset, id)).unwrap();
            let mut data = self.data.read(asset);
            data.size -= 1;

            if (data.size > 1) {
                // List contains more than a single node
                if (id == data.head) {
                    // The removed node is the head
                    // Set head to next node
                    data.head = node.next_id;
                    // Set prev pointer of new head to null
                    let mut head_node = self.nodes.read((asset, data.head)).unwrap();
                    head_node.prev_id = contract_address_const::<0>();
                    self.nodes.write((asset, data.head), Option::Some(head_node));
                } else if (id == data.tail) {
                    // The removed node is the tail
                    // Set tail to previous node
                    data.tail = node.prev_id;
                    // Set next pointer of new tail to null
                    let mut tail_node = self.nodes.read((asset, data.tail)).unwrap();
                    tail_node.next_id = contract_address_const::<0>();
                    self.nodes.write((asset, data.tail), Option::Some(tail_node));
                } else {
                    // The removed node is in the middle of the list
                    // Set next pointer of previous node to next node
                    let mut prev_node = self.nodes.read((asset, node.prev_id)).unwrap();
                    prev_node.next_id = node.next_id;
                    self.nodes.write((asset, node.prev_id), Option::Some(prev_node));
                    // Set prev pointer of next node to previous node
                    let mut next_node = self.nodes.read((asset, node.next_id)).unwrap();
                    next_node.prev_id = node.prev_id;
                    self.nodes.write((asset, node.next_id), Option::Some(next_node));
                }
            } else {
                // List contains a single node
                // Set the head and tail to null
                data.head = contract_address_const::<0>();
                data.tail = contract_address_const::<0>();
            }

            self.nodes.write((asset, id), Option::None);
            self.data.write(asset, data);

            self.emit(NodeRemoved { asset: asset, id: id, })
        }

        #[inline(always)]
        fn int_valid_insert_position(
            self: @ContractState,
            asset: ContractAddress,
            NICR: u256,
            prev_id: ContractAddress,
            next_id: ContractAddress
        ) -> bool {
            let vessel_manager = IVesselManagerDispatcher {
                contract_address: self
                    .address_provider
                    .read()
                    .get_address(AddressesKey::vessel_manager)
            };
            if (prev_id.is_zero() && next_id.is_zero()) {
                // `(null, null)` is a valid insert position if the list is empty
                return self.data.read(asset).size == 0;
            } else if (prev_id.is_zero()) {
                // `(null, _nextId)` is a valid insert position if `_nextId` is the head of the list
                return self.data.read(asset).head == next_id
                    && NICR >= vessel_manager.get_nominal_icr(asset, next_id);
            } else if (next_id.is_zero()) {
                // `(_prevId, null)` is a valid insert position if `_prevId` is the tail of the list
                return self.data.read(asset).tail == prev_id
                    && NICR <= vessel_manager.get_nominal_icr(asset, prev_id);
            } else {
                // `(_prevId, _nextId)` is a valid insert position if `_prevId` and `_nextId` are adjacent nodes in the list
                return self.nodes.read((asset, prev_id)).unwrap().next_id == next_id
                    && vessel_manager.get_nominal_icr(asset, prev_id) >= NICR
                    && NICR >= vessel_manager.get_nominal_icr(asset, next_id);
            }
        }

        #[inline(always)]
        fn int_find_insert_point(
            self: @ContractState,
            asset: ContractAddress,
            NICR: u256,
            prev_id: ContractAddress,
            next_id: ContractAddress
        ) -> (ContractAddress, ContractAddress) {
            let mut prev_id = prev_id;
            let mut next_id = next_id;
            let vessel_manager = IVesselManagerDispatcher {
                contract_address: self
                    .address_provider
                    .read()
                    .get_address(AddressesKey::vessel_manager)
            };
            if (prev_id.is_non_zero()
                && (self.nodes.read((asset, prev_id)).is_none())
                    || NICR > vessel_manager.get_nominal_icr(asset, prev_id)) {
                prev_id = contract_address_const::<0>();
            }

            if (next_id.is_zero()
                && (self.nodes.read((asset, next_id)).is_none()
                    || NICR < vessel_manager.get_nominal_icr(asset, next_id))) {
                next_id = contract_address_const::<0>();
            }

            if (prev_id.is_zero() && next_id.is_zero()) {
                // No hint - descend list starting from head
                return self.descend_list(asset, NICR, self.data.read(asset).head);
            } else if (prev_id.is_zero()) {
                // No `prevId` for hint - ascend list starting from `nextId`
                return self.ascend_list(asset, NICR, next_id);
            } else {
                // Descend list starting from `prevId`
                return self.descend_list(asset, NICR, prev_id);
            }
        }

        fn descend_list(
            self: @ContractState, asset: ContractAddress, NICR: u256, start_id: ContractAddress
        ) -> (ContractAddress, ContractAddress) {
            // If `_startId` is the head, check if the insert position is before the head
            if (start_id == self.data.read(asset).head) {
                return (contract_address_const::<0>(), start_id);
            }

            let mut prev_id = start_id;
            let mut next_id = self.nodes.read((asset, prev_id)).unwrap().next_id;

            // Descend the list until we reach the end or until we find a valid insert position
            loop {
                if (prev_id.is_zero()
                    || !self.int_valid_insert_position(asset, NICR, prev_id, next_id)) {
                    break;
                }

                prev_id = self.nodes.read((asset, prev_id)).unwrap().next_id;
                next_id = self.nodes.read((asset, prev_id)).unwrap().next_id;
            };

            (prev_id, next_id)
        }

        fn ascend_list(
            self: @ContractState, asset: ContractAddress, NICR: u256, start_id: ContractAddress
        ) -> (ContractAddress, ContractAddress) {
            let vessel_manager = IVesselManagerDispatcher {
                contract_address: self
                    .address_provider
                    .read()
                    .get_address(AddressesKey::vessel_manager)
            };
            // If `_startId` is the tail, check if the insert position is after the tail
            if (start_id == self.data.read(asset).tail
                && NICR <= vessel_manager.get_nominal_icr(asset, start_id)) {
                return (start_id, contract_address_const::<0>());
            }

            let mut prev_id = self.nodes.read((asset, start_id)).unwrap().prev_id;
            let mut next_id = start_id;

            // Ascend the list until we reach the end or until we find a valid insert position
            loop {
                if (next_id.is_zero()
                    || !self.int_valid_insert_position(asset, NICR, prev_id, next_id)) {
                    break;
                }

                next_id = self.nodes.read((asset, next_id)).unwrap().prev_id;
                prev_id = self.nodes.read((asset, next_id)).unwrap().prev_id;
            };

            (prev_id, next_id)
        }

        #[inline(always)]
        fn require_caller_is_bo_or_vm(self: @ContractState) {
            let caller = get_caller_address();
            let borrower_operations = self
                .address_provider
                .read()
                .get_address(AddressesKey::borrower_operations);
            let vessel_manager = self
                .address_provider
                .read()
                .get_address(AddressesKey::vessel_manager);
            assert(
                caller == borrower_operations || caller == vessel_manager,
                CommunErrors::CommunErrors__CallerNotAuthorized
            );
        }
    }
}
