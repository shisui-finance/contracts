use hash::{LegacyHash, HashStateTrait, HashStateExTrait};

trait ISpanFelt252Hash<T> {
    fn hash_span(self: @T) -> felt252;
}


impl HashSpanFelt252 of ISpanFelt252Hash<Span<felt252>> {
    fn hash_span(self: @Span<felt252>) -> felt252 {
        let mut call_data_state = LegacyHash::hash(0, *self);
        call_data_state = LegacyHash::hash(call_data_state, (*self).len());
        call_data_state
    }
}

impl LegacyHashSpanFelt252 of LegacyHash<Span<felt252>> {
    fn hash(mut state: felt252, mut value: Span<felt252>) -> felt252 {
        loop {
            match value.pop_front() {
                Option::Some(item) => { state = LegacyHash::hash(state, *item); },
                Option::None(_) => { break state; },
            };
        }
    }
}
