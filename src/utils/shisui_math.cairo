use core::integer::BoundedU256;
use super::constants::{DECIMAL_PRECISION, HALF_DECIMAL_PRECISION};

const EXPONENT_CAP: u256 = 525600000;
const NICR_PRECSION: u256 = 100000000000000000000;


// Multiply two decimal numbers and use normal rounding rules:
// - round product up if 19'th mantissa digit >= 5
// - round product down if 19'th mantissa digit < 5
// Used only inside the exponentiation, dec_pow().
fn dec_mul(a: u256, b: u256) -> u256 {
    let prod_ab = a * b;
    (prod_ab + HALF_DECIMAL_PRECISION) / DECIMAL_PRECISION
}

// dec_pow: Exponentiation function for 18-digit decimal base, and integer exponent n.
//
// Uses the efficient "exponentiation by squaring" algorithm. O(log(n)) complexity.
//
// Called by two functions that represent time in units of minutes:
// 1) VesselManager._calc_decayed_base_rate
// 2) CommunityIssuance._get_cumulative_issuance_fraction
//
// The exponent is capped to avoid reverting due to overflow. The cap 525600000 equals
// "minutes in 1000 years": 60 * 24 * 365 * 1000
//
// If a period of > 1000 years is ever used as an exponent in either of the above functions, the result will be
// negligibly different from just passing the cap, since:
//
// In function 1), the decayed base rate will be 0 for 1000 years or > 1000 years
// In function 2), the difference in tokens issued at 1000 years and any time > 1000 years, will be negligible
fn dec_pow(base: u256, mut minutes: u256) -> u256 {
    if (minutes > EXPONENT_CAP) {
        minutes = EXPONENT_CAP;
    } // cap to avoid overflow

    if (minutes == 0) {
        return DECIMAL_PRECISION;
    }

    if (minutes == 1) {
        return base;
    }

    let mut y = DECIMAL_PRECISION;
    let mut x = base;
    let mut n = minutes;

    // Exponentiation-by-squaring
    loop {
        if (n == 1) {
            break;
        }
        if (n % 2 == 0) {
            x = dec_mul(x, x);
            n = n / 2;
        } else {
            y = dec_mul(x, y);
            x = dec_mul(x, x);
            n = (n - 1) / 2;
        }
    };

    dec_mul(x, y)
}

fn get_absolute_difference(a: u256, b: u256) -> u256 {
    if (a >= b) {
        return a - b;
    }
    return b - a;
}

fn compute_nominal_cr(coll: u256, debt: u256) -> u256 {
    // Return the maximal value for u256 if the Vessel has a debt of 0. Represents "infinite" CR.
    if (debt.is_zero()) {
        return BoundedU256::max();
    }
    return (coll * NICR_PRECSION) / debt;
}


fn compute_cr(coll: u256, debt: u256, price: u256) -> u256 {
    // Return the maximal value for uint256 if the Vessel has a debt of 0. Represents "infinite" CR.
    if (debt.is_zero()) {
        return BoundedU256::max();
    }
    return (coll * price) / debt;
}

