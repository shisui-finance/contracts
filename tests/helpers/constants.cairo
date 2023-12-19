mod TimeValues {
    const SECONDS_IN_ONE_MINUTE: u256 = 60;
    const SECONDS_IN_ONE_HOUR: u256 = consteval_int!(60 * 60);
    const SECONDS_IN_ONE_DAY: u256 = consteval_int!(24 * 60 * 60);
    const SECONDS_IN_ONE_WEEK: u256 = consteval_int!(7 * 24 * 60 * 60);
    const SECONDS_IN_ONE_MONTH: u256 = consteval_int!(30 * 24 * 60 * 60);
    const SECONDS_IN_ONE_YEAR: u256 = consteval_int!(365 * 24 * 60 * 60);
    const MINUTES_IN_ONE_HOUR: u256 = 60;
    const MINUTES_IN_ONE_DAY: u256 = consteval_int!(24 * 60);
    const MINUTES_IN_ONE_WEEK: u256 = consteval_int!(7 * 24 * 60);
    const MINUTES_IN_ONE_MONTH: u256 = consteval_int!(30 * 24 * 60);
    const MINUTES_IN_ONE_YEAR: u256 = consteval_int!(365 * 24 * 60);
}
