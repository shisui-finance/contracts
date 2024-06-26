#[starknet::component]
mod ShisuiMathComponent {
    #[storage]
    struct Storage {}


    #[generate_trait]
    impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        // Multiply two decimal numbers and use normal rounding rules:
        // -round product up if 19'th mantissa digit >= 5
        // -round product down if 19'th mantissa digit < 5
        // Used only inside the exponentiation, _dec_pow().
        fn dec_mul(a: u256, b: u256) -> u256 {
            return 0;
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
        fn _dec_pow(_base: u256, _minutes: u256) -> u256 {
            return 0;
        }

        fn _get_absolute_difference(_a: u256, _b: u256) -> u256 {
            return 0;
        }

        fn _compute_nominal_cr(_coll: u256, _debt: u256) -> u256 {
            return 0;
        }

        fn _compute_cr(_coll: u256, _debt: u256, _price: u256) -> u256 {
            return 0;
        }
    }
}

