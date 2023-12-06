/// Raise a number to a power, computes x^n.
/// * `x` - The number to raise.
/// * `n` - The exponent.
/// # Returns
/// * `u128` - The result of x raised to the power of n.
fn pow(x: u256, n: u8) -> u256 {
    if n == 0 {
        1
    } else if n == 1 {
        x
    } else if (n & 1) == 1 {
        x * pow(x * x, n / 2)
    } else {
        pow(x * x, n / 2)
    }
}

fn pow256(x: u256, mut n: u256) -> u256 {
    let mut result = 1;
    let mut base = x;

    loop {
        if n & 1 == 1 {
            result = result * base;
        }

        n = n / 2;
        if n == 0 {
            break result;
        }

        base = base * base;
    }
}
