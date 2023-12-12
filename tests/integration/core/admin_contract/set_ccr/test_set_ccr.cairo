use shisui::components::shisui_math::ShisuiMathComponent::InternalImpl;
use core::integer::BoundedU256;

#[test]
fn test_compute_cr(mut _coll: u256, mut _price: u256, _debt: u256) {
    // Assume _coll and _price being lower or equal to 10^37 to avoid mul_overflow
    _coll = _coll % 10000000000000000000000000000000000000;
    _price = _price % 10000000000000000000000000000000000000;
    let res = InternalImpl::_compute_cr(_coll, _debt, _price);
    if _debt != 0 {
        assert(res == _coll * _price / _debt, 'wrong CR');
    } else {
        assert(res == BoundedU256::max(), 'should be max u256');
    }
}
