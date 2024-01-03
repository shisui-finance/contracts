use zeroable::Zeroable;

#[derive(Drop)]
struct Felt252Node {
    value: felt252,
    next: felt252,
    prev: felt252,
}

struct Felt252List {
    size: felt252,
    head: Felt252Node,
    tail: Felt252Node,
}

trait Felt252NodeTrait {
    fn new(value: felt252) -> Felt252Node;
}

trait Felt252DoublyLinkedListTrait {
    // fn new() -> List<T>;
    fn insert(ref self: Felt252List, value: felt252);
// fn remove(&mut self, value: N);
// fn search(&self, value: N) -> Option<&N>;
// fn is_empty(&self) -> bool;
// fn size(&self) -> usize;
// fn print(&self);
}

impl Felt252NodeImplementation of Felt252NodeTrait {
    fn new(value: felt252) -> Felt252Node {
        Felt252Node { value: value, next: 0, prev: 0, }
    }
}

impl Felt252DoublyLinkedListImpl of Felt252DoublyLinkedListTrait {
    // fn new() -> List<T> {
    //     List {
    //         size: 0,
    //         head: Option::None,
    //         tail: Option::None,
    //         data: Felt252Dict::new(),
    //     }
    // }

    fn insert(ref self: Felt252List, value: felt252) {
        if (self.size.is_zero()) {
            self.head = Felt252Node { value: value, next: 0, prev: 0, };
            self.tail = Felt252Node { value: value, next: 0, prev: 0, };
        } else {
            let mut node = Felt252Node { value: value, next: 0, prev: 0, };
        }
    }
// fn remove(&mut self, value: N) {
//     let mut current = self.head.take();
//     while let Some(mut node) = current {
//         current = node.next.take();
//         if node.value == value {
//             self.size -= 1;
//             if let Some(mut next) = node.next.take() {
//                 next.prev = node.prev.take();
//                 current = Some(next);
//             } else {
//                 self.tail = node.prev.take();
//             }
//             if let Some(mut prev) = node.prev.take() {
//                 prev.next = node.next.take();
//                 current = Some(prev);
//             } else {
//                 self.head = node.next.take();
//             }
//         } else {
//             current = Some(node);
//         }
//     }
// }

// fn search(&self, value: N) -> Option<&N> {
//     let mut current = self.head.take();
//     while let Some(node) = current {
//         if node.value == value {
//             return Some(&node.value);
//         }
//         current = node.next.take();
//     }
//     None
// }

// fn is_empty(&self) -> bool {
//     self.head.is_none()
// }

// fn size(&self) -> usize {
//     self.size
// }

// fn print(&self) {
//     let mut current = self.head.take();
//     while let Some(node) = current {
//         print!("{} ", node.value);
//         current = node.next.take();
//     }
//     println!("");
// }
}
