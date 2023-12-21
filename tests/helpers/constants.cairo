mod TimeValues {
    const SECONDS_IN_ONE_MINUTE: u64 = 60;
    const SECONDS_IN_ONE_HOUR: u64 = consteval_int!(60 * 60);
    const SECONDS_IN_ONE_DAY: u64 = consteval_int!(24 * 60 * 60);
    const SECONDS_IN_ONE_WEEK: u64 = consteval_int!(7 * 24 * 60 * 60);
    const SECONDS_IN_ONE_MONTH: u64 = consteval_int!(30 * 24 * 60 * 60);
    const SECONDS_IN_ONE_YEAR: u64 = consteval_int!(365 * 24 * 60 * 60);
    const MINUTES_IN_ONE_HOUR: u64 = 60;
    const MINUTES_IN_ONE_DAY: u64 = consteval_int!(24 * 60);
    const MINUTES_IN_ONE_WEEK: u64 = consteval_int!(7 * 24 * 60);
    const MINUTES_IN_ONE_MONTH: u64 = consteval_int!(30 * 24 * 60);
    const MINUTES_IN_ONE_YEAR: u64 = consteval_int!(365 * 24 * 60);
}
