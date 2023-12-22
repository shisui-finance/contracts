mod interfaces{
    mod deposit;
}
mod core {
    mod address_provider;
    mod timelock;
    mod gas_pool;
    mod price_feed;
    mod fee_collector;
    mod admin_contract;
    mod debt_token;
}

mod pools {
    mod stability_pool;
    mod sorted_vessels;
    mod default_pool;
    mod collateral_surplus_pool;
    mod active_pool;
}

mod utils {
    mod asserts;
    mod errors;
    mod constants;
    mod array;
    mod traits;
    mod math;
    mod shisui_math;
    mod shisui_base;
    mod convert;
}

mod mocks {
    mod erc20_mock;
    mod pragma_oracle_mock;
    mod receive_erc20_mock;
}

