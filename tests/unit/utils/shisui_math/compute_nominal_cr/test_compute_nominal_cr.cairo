use core::integer::BoundedU256;
use shisui::utils::{shisui_math::{compute_nominal_cr, get_absolute_difference}, constants::ONE};


#[test]
fn when_debt_is_0_it_should_return_max_u256() {
    let coll = ONE;
    let debt = 0;

    let res = compute_nominal_cr(coll, debt);
    assert(res == BoundedU256::max(), 'Wrong CR');
}

#[test]
fn when_result_is_exact_it_should_return_it() {
    let coll = ONE;
    let debt = 100 * ONE;

    let res = compute_nominal_cr(coll, debt);
    assert(res == ONE, 'Wrong CR');
}

#[test]
fn when_result_not_exact_it_should_be_acceptable() {
    let tolerance = 1000;

    // [coll, debt, expected_result]
    let mut values_array = array![
        array![200 * ONE, 30 * ONE, 666666666666666666666],
        array![1350 * ONE, 127 * ONE, 1062992125984251968503],
        array![ONE, 54321 * ONE, 1840908672520756],
    ];

    loop {
        match values_array.pop_front() {
            Option::Some(values) => {
                let coll = *values[0];
                let debt = *values[1];
                let expected_result = *values[2];

                let res = compute_nominal_cr(coll, debt);

                assert(get_absolute_difference(res, expected_result) <= tolerance, 'Wrong result');
            },
            Option::None => { break; },
        }
    }
}

