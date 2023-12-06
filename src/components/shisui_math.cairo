#[starknet::component]
mod ShisuiMathComponent {
    use core::integer::BoundedU256;

    const DECIMAL_PRECISION: u256 = 1000000000000000000;
    const EXPONENT_CAP: u256 = 525600000;
    const NICR_PRECSION: u256 = 100000000000000000000;

    #[storage]
    struct Storage {}

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        // Multiply two decimal numbers and use normal rounding rules:
        // -round product up if 19'th mantissa digit >= 5
        // -round product down if 19'th mantissa digit < 5
        // Used only inside the exponentiation, _dec_pow().
        fn dec_mul(a: u256, b: u256) -> u256 {
            let prod_ab = a * b;

            (prod_ab + (DECIMAL_PRECISION / 2)) / DECIMAL_PRECISION
        }

        // _dec_pow: Exponentiation function for 18-digit decimal base, and integer exponent n.
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
        fn _dec_pow(_base: u256, mut _minutes: u256) -> u256 {
            if (_minutes > EXPONENT_CAP) {
                _minutes = EXPONENT_CAP;
            } // cap to avoid overflow

            if (_minutes == 0) {
                return DECIMAL_PRECISION;
            }

            let mut y = DECIMAL_PRECISION;
            let mut x = _base;
            let mut n = _minutes;

            // Exponentiation-by-squaring
            loop {
                if (n == 1) {
                    break;
                }
                if (n % 2 == 0) {
                    x = InternalImpl::dec_mul(x, x);
                    n = n / 2;
                } else {
                    // if (n % 2 != 0)
                    y = InternalImpl::dec_mul(x, y);
                    x = InternalImpl::dec_mul(x, x);
                    n = (n - 1) / 2;
                }
            };

            InternalImpl::dec_mul(x, y)
        }

        fn _get_absolute_difference(_a: u256, _b: u256) -> u256 {
            if _a >= _b {
                _a - _b
            } else {
                _b - _a
            }
        }

        fn _compute_nominal_cr(_coll: u256, _debt: u256) -> u256 {
            if _debt != 0 {
                _coll * NICR_PRECSION / _debt
            } else {
                // Return the maximal value for u256 if the Vessel has a debt of 0. Represents "infinite" CR.
                BoundedU256::max()
            }
        }

        fn _compute_cr(_coll: u256, _debt: u256, _price: u256) -> u256 {
            if (_debt != 0) {
                let newCollRatio = _coll * _price / _debt;

                return newCollRatio;
            }// Return the maximal value for uint256 if the Vessel has a debt of 0. Represents "infinite" CR.
            else {
                BoundedU256::max()
            }
            return 0;
        }
    }
}

