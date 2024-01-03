use shisui::utils::shisui_math::get_absolute_difference;
use snforge_std::PrintTrait;
fn assert_is_approximately_equal(a: u256, b: u256, margin_error: u256, msg: felt252) {
    let abs_diff = get_absolute_difference(a, b);
    assert(abs_diff <= margin_error, msg);
}
