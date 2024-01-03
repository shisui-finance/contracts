const DEFAULT_TIMEOUT: u64 = consteval_int!(30 * 60); // 30 minutes
const MAX_FEE_FRACTION: u256 = 5000000000000000; // 0.5% fee
const MIN_FEE_FRACTION: u256 = 38461538000000000; // (1/26)e18 fee divided by 26 weeks
const MIN_FEE_DURATION: u64 = consteval_int!(7 * 24 * 60 * 60); // 7 days
const FEE_EXPIRATION_SECONDS: u64 =
    consteval_int!(175 * 24 * 60 * 60); // ~ 6 months, minus one week (MIN_FEE_DURATION)

