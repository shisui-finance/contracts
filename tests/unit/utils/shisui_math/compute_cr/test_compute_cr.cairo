use core::integer::BoundedU256;
use shisui::utils::{shisui_math::{compute_cr, get_absolute_difference}, constants::ONE};

#[test]
fn when_price_is_0_it_should_return_0() {
    let price = 0;
    let coll = ONE;
    let debt = 100 * ONE;

    let res = compute_cr(coll, debt, price);
    assert(res == 0, 'Wrong CR');
}

#[test]
fn when_debt_is_0_it_should_return_max_u256() {
    let price = 100 * ONE;
    let coll = ONE;
    let debt = 0;

    let res = compute_cr(coll, debt, price);
    assert(res == BoundedU256::max(), 'Wrong CR');
}

#[test]
fn when_result_is_exact_it_should_return_it() {
    let price = 100 * ONE;
    let coll = ONE;
    let debt = 100 * ONE;

    let res = compute_cr(coll, debt, price);
    assert(res == ONE, 'Wrong CR');
}

#[test]
fn when_result_not_exact_it_should_be_acceptable() {
    let tolerance = 1000;

    // [price, coll, debt, expected_result]
    let mut values_array = array![
        array![100 * ONE, 200 * ONE, 30 * ONE, 666666666666666666666],
        array![250 * ONE, 1350 * ONE, 127 * ONE, 2657480314960629921259],
        array![100 * ONE, ONE, 54321 * ONE, 1840908672520756],
    ];

    loop {
        match values_array.pop_front() {
            Option::Some(values) => {
                let price = *values[0];
                let coll = *values[1];
                let debt = *values[2];
                let expected_result = *values[3];

                let res = compute_cr(coll, debt, price);

                assert(get_absolute_difference(res, expected_result) <= tolerance, 'Wrong result');
            },
            Option::None => { break; },
        }
    }
}

