use core::array::ArrayTrait;
use shisui::components::shisui_math::ShisuiMathComponent::{InternalImpl, EXPONENT_CAP};
use shisui::utils::math::pow256;

use debug::PrintTrait;

//Tests are taken from : https://github.com/Gravita-Protocol/Gravita-SmartContracts/blob/95e3b30d877540eecda276deaff6e21e19e51460/test/gravita/FeeArithmeticTest.js#L472

fn bound(input: u256, min: u256, max: u256) -> u256 {
    input % (max - min + 1) + min
}

#[test]
fn test_dec_pow_rand_base_exponent_3_months(mut base: u256) {
    base = bound(base, 999999000000000000, 999999999999999999);
    let exponent = 7776000; // seconds in 3 months

    let res = InternalImpl::_dec_pow(base, exponent);
// assert(res==pow256(base, exponent), 'wrong product'); panic with u256_mul_overflow
}
