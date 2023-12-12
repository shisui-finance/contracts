use poseidon::PoseidonTrait;
use core::hash::HashStateTrait;
use core::hash::HashStateExTrait;


trait ISpanFelt252Hash<T> {
    fn hash_span(self: @T) -> felt252;
}


impl HashSpanFelt252 of ISpanFelt252Hash<Span<felt252>> {
    fn hash_span(self: @Span<felt252>) -> felt252 {
        let mut hash_state = PoseidonTrait::new();
        let mut datas: Span<felt252> = *self;
        loop {
            match datas.pop_front() {
                Option::Some(item) => { hash_state = hash_state.update_with(*item); },
                Option::None(_) => { break; },
            };
        };
        hash_state.finalize()
    }
}

