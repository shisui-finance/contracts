mod unit {
    mod concrete {
        mod core {
            mod address_provider {
                mod set_addresses {
                    mod test_set_addresses;
                }
                mod set_community_issuance {
                    mod test_set_community_issuance;
                }
                mod set_SHVT_staking {
                    mod test_set_SHVT_staking;
                }
            }
        }
    }
    mod fuzz {
        mod components {
            mod shisui_math {
                mod dec_pow {
                    mod test_dec_pow;
                }
            }
        }
    }
}

mod integration {
    mod concrete {
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
    }
}

