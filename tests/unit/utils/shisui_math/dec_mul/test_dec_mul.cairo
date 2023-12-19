use core::integer::BoundedU256;
use shisui::utils::{shisui_math::dec_mul, constants::ONE};


#[test]
fn when_product_is_exact_it_return_exact_value() {
    assert(dec_mul(ONE, 2) == 2, 'Wrong product');
}

#[test]
fn when_product_not_exact_but_lower_than_5_bps_it_return_rounding_down_value() {
    assert(dec_mul(140000000000000000, 10) == 1, 'Wrong product');
}

#[test]
fn when_product_not_exact_but_greater_than_5_bps_it_return_rounding_up_value() {
    assert(dec_mul(1500000000000000000, 3) == 5, 'Wrong product');
}
