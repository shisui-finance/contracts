use shisui::components::shisui_math::ShisuiMathComponent::InternalImpl;

#[test]
fn test_get_absolute_difference(a: u256, b: u256) {
    let res = InternalImpl::_get_absolute_difference(a, b);
    if a >= b {
        assert(res == a - b, 'wrong difference');
    } else {
        assert(res == b - a, 'wrong difference');
    }
}
