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
        mod dependencies {
            mod shisui_math {
                mod dec_pow {
                    mod test_dec_pow;
                }
            }
        }
    }
}

