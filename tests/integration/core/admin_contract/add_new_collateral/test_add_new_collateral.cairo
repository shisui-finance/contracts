use shisui::components::shisui_math::ShisuiMathComponent::{InternalImpl, NICR_PRECSION};
use core::integer::BoundedU256;

#[test]
fn test_compute_nominal_CR(mut _coll: u256, _debt: u256) {
    // assume that _coll is under 10e57 to not overflow
    _coll = _coll % 1000000000000000000000000000000000000000000000000000000000;
    let res = InternalImpl::_compute_nominal_cr(_coll, _debt);

    if _debt != 0 {
        assert(res == _coll * NICR_PRECSION / _debt, 'wrong nominal CR');
    } else {
        assert(res == BoundedU256::max(), 'should be max u256');
    }
}
