use core::integer::BoundedU256;
use shisui::utils::{shisui_math::get_absolute_difference, constants::ONE};


#[test]
fn when_a_lower_than_b_should_return_b_minus_a() {
    // [a, b, expected_result]
    let mut abs_diff_results = array![
        array![0, ONE, ONE],
        array![1, BoundedU256::max(), BoundedU256::max() - 1],
        array![ONE, ONE, 0],
    ];

    loop {
        match abs_diff_results.pop_front() {
            Option::Some(values) => {
                let a = *values[0];
                let b = *values[1];
                let expected_result = *values[2];

                assert(get_absolute_difference(a, b) == expected_result, 'Wrong result');
            },
            Option::None => { break; },
        }
    }
}

#[test]
fn when_b_lower_than_a_should_return_a_minus_b() {
    // [a, b, expected_result]
    let mut abs_diff_results = array![
        array![ONE, 0, ONE],
        array![BoundedU256::max(), 1, BoundedU256::max() - 1],
        array![ONE, ONE, 0],
    ];

    loop {
        match abs_diff_results.pop_front() {
            Option::Some(values) => {
                let a = *values[0];
                let b = *values[1];
                let expected_result = *values[2];

                assert(get_absolute_difference(a, b) == expected_result, 'Wrong result');
            },
            Option::None => { break; },
        }
    }
}
