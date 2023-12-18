mod unit {
    mod components {
        mod safety_transfer {
            mod test_decimals_correction;
        }
        mod shisui_math {
            mod dec_pow {
                mod test_dec_pow;
            }
            mod compute_cr {
                mod test_compute_cr;
            }
            mod compute_nominal_cr {
                mod test_compute_nominal_cr;
            }
            mod get_absolute_difference {
                mod test_get_absolute_difference;
            }
        }
    }
    mod core {
        mod address_provider {
            mod set_address {
                mod test_set_address;
            }
        }
    }
}

mod integration {
    mod components {
        mod shisui_base {
            mod check_recovery_mode {
                mod test_check_recovery_mode;
            }
            mod get_coll_gas_compensation {
                mod test_get_coll_gas_compensation;
            }
            mod get_composite_debt {
                mod test_get_composite_debt;
            }
            mod get_entire_system_coll {
                mod test_get_entire_system_coll;
            }
            mod get_entire_system_debt {
                mod test_get_entire_system_debt;
            }
            mod get_net_debt {
                mod test_get_net_debt;
            }
            mod get_TCR {
                mod test_get_TCR;
            }
            mod require_user_accepts_fee {
                mod test_require_user_accepts_fee;
            }
        }
    }
    mod core {
        mod admin_contract {
            mod add_new_collateral {
                mod test_add_new_collateral;
            }
            mod set_borrowing_fee {
                mod test_set_borrowing_fee;
            }
            mod set_ccr {
                mod test_set_ccr;
            }
            mod set_collateral_parameters {
                mod test_set_collateral_parameters;
            }
            mod set_is_active {
                mod test_set_is_active;
            }
            mod set_mcr {
                mod test_set_mcr;
            }
            mod set_min_net_debt {
                mod test_set_min_net_debt;
            }
            mod set_mint_cap {
                mod test_set_mint_cap;
            }
            mod set_percent_divisor {
                mod test_set_percent_divisor;
            }
            mod set_redemption_block_timestamp {
                mod test_set_redemption_block_timestamp;
            }
            mod set_redemption_fee_floor {
                mod test_set_redemption_fee_floor;
            }
        }
        mod timelock {
            mod accept_admin {
                mod test_accept_admin;
            }
            mod cancel_transaction {
                mod test_cancel_transaction;
            }
            mod execute_transaction {
                mod test_execute_transaction;
            }
            mod queue_transaction {
                mod test_queue_transaction;
            }
            mod set_delay {
                mod test_set_delay;
            }
            mod set_pending_admin {
                mod test_set_pending_admin;
            }
        }
        mod debt_token {
            mod burn {
                mod test_burn;
            }
            mod mint {
                mod test_mint;
            }
            mod transfer {
                mod test_transfer;
            }
            mod transfer_from {
                mod test_transfer_from;
            }
            mod add_whitelist {
                mod test_add_whitelist;
            }
            mod remove_whitelist {
                mod test_remove_whitelist;
            }
            mod return_from_pool {
                mod test_return_from_pool;
            }
            mod send_to_pool {
                mod test_send_to_pool;
            }
            mod mint_from_whitelisted_contract {
                mod test_mint_from_whitelisted_contract;
            }
            mod emergency_stop_minting {
                mod test_emergency_stop_minting;
            }
            mod burn_from_whitelisted_contract {
                mod test_burn_from_whitelisted_contract;
            }
        }
        mod price_feed {
            mod set_oracle {
                mod test_set_oracle;
            }
            mod fetch_price {
                mod test_fetch_price;
            }
            mod get_oracle {
                mod test_get_oracle;
            }
        }
        mod fee_collector {
            mod increase_debt {
                mod test_increase_debt;
            }
            mod decrease_debt {
                mod test_decrease_debt;
            }
            mod close_debt {
                mod test_close_debt;
            }
            mod liquidate_debt {
                mod test_liquidate_debt;
            }
            mod collect_fees {
                mod test_collect_fees;
            }
            mod handle_redemption_fee {
                mod test_handle_redemption_fee;
            }
            mod set_route_to_SHVT_staking {
                mod test_set_route_to_SHVT_staking;
            }
        }
    }
    mod pools {
        mod collateral_surplus_pool {
            mod account_surplus {
                mod test_account_surplus;
            }
            mod claim_cool {
                mod test_claim_cool;
            }
            mod received_erc20 {
                mod test_received_erc20;
            }
        }
        mod active_pool {
            mod decrease_debt {
                mod test_decrease_debt;
            }
            mod increase_debt {
                mod test_increase_debt;
            }
            mod send_asset {
                mod test_send_asset;
            }
            mod received_erc20 {
                mod test_received_erc20;
            }
        }
        mod default_pool {
            mod decrease_debt {
                mod test_decrease_debt;
            }
            mod increase_debt {
                mod test_increase_debt;
            }
            mod send_asset_to_active_pool {
                mod test_send_asset_to_active_pool;
            }
            mod received_erc20 {
                mod test_received_erc20;
            }
        }
        mod sorted_vessels {
            mod find_insert_position {
                mod test_find_insert_position;
            }
            mod insert {
                mod test_insert;
            }
            mod remove {
                mod test_remove;
            }
            mod re_insert {
                mod test_re_insert;
            }
            mod valid_insert_position {
                mod test_valid_insert_position;
            }
        }
    }
}

mod tests_lib;
