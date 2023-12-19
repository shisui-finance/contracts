use core::zeroable::Zeroable;
use starknet::{ContractAddress};
use openzeppelin::token::erc20::interface::{
    IERC20MetadataDispatcher, IERC20MetadataDispatcherTrait
};
use core::traits::Into;
use shisui::utils::math::pow;
use shisui::utils::errors::CommunErrors;

fn decimals_correction(token: ContractAddress, amount: u256) -> u256 {
    assert(token.is_non_zero(), CommunErrors::CommunErrors__AddressZero);

    if amount == 0 {
        return 0;
    }

    let decimals: u8 = IERC20MetadataDispatcher { contract_address: token }.decimals();
    if decimals < 18 {
        let divisor: u256 = pow(10, 18 - decimals);
        assert(amount % divisor != 0, CommunErrors::CommunErrors__Invalid_amount);
        return amount / divisor;
    } else if decimals > 18 {
        let multiplier = pow(10, decimals - 18);
        return amount * multiplier.into();
    }

    return amount;
}
