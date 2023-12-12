use shisui::components::shisui_math::ShisuiMathComponent::InternalImpl;
use core::integer::BoundedU256;

#[test]
fn test_dec_mul() {
    let res = InternalImpl::_dec_mul(1000000000000000000, 2);
    assert(res == 2, 'wrong product');
}

#[test]
fn test_dec_mul_rounding_up() {
    let res = InternalImpl::_dec_mul(1500000000000000000, 3);
    assert(res == 5, 'wrong product');
}

#[test]
fn test_dec_mul_rounding_down() {
    let res = InternalImpl::_dec_mul(140000000000000000, 10);
    assert(res == 1, 'wrong product');
}

//Following tests are taken from : https://github.com/Gravita-Protocol/Gravita-SmartContracts/blob/95e3b30d877540eecda276deaff6e21e19e51460/test/gravita/FeeArithmeticTest.js#L375

#[test]
// For exponent = 0, returns 1, regardless of base
fn test_dec_pow_exponent_0() {
    let res = InternalImpl::_dec_pow(0, 0);
    assert(res == 1000000000000000000, 'wrong result base 0');

    let res = InternalImpl::_dec_pow(1, 0);
    assert(res == 1000000000000000000, 'wrong result base 1');

    let res = InternalImpl::_dec_pow(1000000000000000000, 0);
    assert(res == 1000000000000000000, 'wrong result base 10^18');

    let res = InternalImpl::_dec_pow(123244254546, 0);
    assert(res == 1000000000000000000, 'wrong result base 123244254546');

    let res = InternalImpl::_dec_pow(990000000000000000, 0);
    assert(res == 1000000000000000000, 'wrong result base 99*10^16');

    let res = InternalImpl::_dec_pow(897890990909098978678609090, 0);
    assert(res == 1000000000000000000, 'wrong result base big number');

    let res = InternalImpl::_dec_pow(8789789000000000000000000000000000, 0);
    assert(res == 1000000000000000000, 'wrong result base huge number');

    let res = InternalImpl::_dec_pow(BoundedU256::max(), 0);
    assert(res == 1000000000000000000, 'wrong result base max u256');
}

#[test]
// For exponent = 1, returns base, regardless of base
fn test_dec_pow_exponent_1() {
    let res = InternalImpl::_dec_pow(0, 1);
    assert(res == 0, 'wrong result base 0');

    let res = InternalImpl::_dec_pow(1, 1);
    assert(res == 1, 'wrong result base 1');

    let res = InternalImpl::_dec_pow(1000000000000000000, 1);
    assert(res == 1000000000000000000, 'wrong result base 10^18');

    let res = InternalImpl::_dec_pow(123244254546, 1);
    assert(res == 123244254546, 'wrong result base 123244254546');

    let res = InternalImpl::_dec_pow(990000000000000000, 1);
    assert(res == 990000000000000000, 'wrong result base 99*10^16');

    let res = InternalImpl::_dec_pow(897890990909098978678609090, 1);
    assert(res == 897890990909098978678609090, 'wrong result base big number');

    let res = InternalImpl::_dec_pow(8789789000000000000000000000000000, 1);
    assert(res == 8789789000000000000000000000000000, 'wrong result base huge number');

    let res = InternalImpl::_dec_pow(BoundedU256::max(), 1);
    assert(res == BoundedU256::max(), 'wrong result base max u256');
}

#[test]
// For base = 0, returns 0 for any exponent other than 0
fn test_dec_pow_base_0() {
    let res = InternalImpl::_dec_pow(0, 1);
    assert(res == 0, 'wrong result exponent 1');

    let res = InternalImpl::_dec_pow(0, 3);
    assert(res == 0, 'wrong result exponent 3');

    let res = InternalImpl::_dec_pow(0, 17);
    assert(res == 0, 'wrong result exponent 17');

    let res = InternalImpl::_dec_pow(0, 44);
    assert(res == 0, 'wrong result exponent 44');

    let res = InternalImpl::_dec_pow(0, 118);
    assert(res == 0, 'wrong result exponent 118');

    let res = InternalImpl::_dec_pow(0, 1000);
    assert(res == 0, 'wrong result exponent 1000');

    let res = InternalImpl::_dec_pow(0, 1000000);
    assert(res == 0, 'wrong result exponent 10^6');

    let res = InternalImpl::_dec_pow(0, 1000000000);
    assert(res == 0, 'wrong result exponent 10^9');

    let res = InternalImpl::_dec_pow(0, 1000000000000);
    assert(res == 0, 'wrong result exponent 10^12');

    let res = InternalImpl::_dec_pow(0, 1000000000000000000);
    assert(res == 0, 'wrong result exponent 10^18');
}

#[test]
// For base = 1, returns 1 for any exponent
fn test_dec_pow_base_1() {
    let res = InternalImpl::_dec_pow(1000000000000000000, 1);
    assert(res == 1000000000000000000, 'wrong result exponent 1');

    let res = InternalImpl::_dec_pow(1000000000000000000, 3);
    assert(res == 1000000000000000000, 'wrong result exponent 3');

    let res = InternalImpl::_dec_pow(1000000000000000000, 17);
    assert(res == 1000000000000000000, 'wrong result exponent 17');

    let res = InternalImpl::_dec_pow(1000000000000000000, 44);
    assert(res == 1000000000000000000, 'wrong result exponent 44');

    let res = InternalImpl::_dec_pow(1000000000000000000, 118);
    assert(res == 1000000000000000000, 'wrong result exponent 118');

    let res = InternalImpl::_dec_pow(1000000000000000000, 1000);
    assert(res == 1000000000000000000, 'wrong result exponent 1000');

    let res = InternalImpl::_dec_pow(1000000000000000000, 1000000);
    assert(res == 1000000000000000000, 'wrong result exponent 10^6');

    let res = InternalImpl::_dec_pow(1000000000000000000, 1000000000);
    assert(res == 1000000000000000000, 'wrong result exponent 10^9');

    let res = InternalImpl::_dec_pow(1000000000000000000, 1000000000000);
    assert(res == 1000000000000000000, 'wrong result exponent 10^12');

    let res = InternalImpl::_dec_pow(1000000000000000000, 1000000000000000000);
    assert(res == 1000000000000000000, 'wrong result exponent 10^18');
}

#[test]
// For exponent = 2, returns the square of the base
fn test_dec_pow_exponent_2() {
    let res = InternalImpl::_dec_pow(1000000000000000000, 2);
    assert(res == 1000000000000000000, 'wrong result base 1');

    let res = InternalImpl::_dec_pow(1500000000000000000, 2);
    assert(res == 2250000000000000000, 'wrong wrong result base 1.5');

    let res = InternalImpl::_dec_pow(500000000000000000, 2);
    assert(res == 250000000000000000, 'wrong wrong result base 0.5');

    let res = InternalImpl::_dec_pow(321000000000000000, 2);
    assert(res == 103041000000000000, 'wrong wrong result base 0.321');

    let res = InternalImpl::_dec_pow(2000000000000000000, 2);
    assert(res == 4000000000000000000, 'wrong wrong result base 2');

    let res = InternalImpl::_dec_pow(100000000000000000, 2);
    assert(res == 10000000000000000, 'wrong wrong result base 0.1');

    let res = InternalImpl::_dec_pow(10000000000000000, 2);
    assert(res == 100000000000000, 'wrong wrong result base 0.01');

    let res = InternalImpl::_dec_pow(990000000000000000, 2);
    assert(res == 980100000000000000, 'wrong wrong result base 0.99');

    let res = InternalImpl::_dec_pow(125435000000000000000, 2);
    assert(res == 15733939225000000000000, 'wrong wrong result base 125.435');

    let res = InternalImpl::_dec_pow(99999000000000000000000, 2);
    assert(res == 9999800001000000000000000000, 'wrong wrong result base 99999');
}

#[test]
fn test_dec_pow_exponent() {
    // Exponent in range [2, 300]
    let mut exponentiationResults = array![
        array![187706062567632000, 17, 445791],
        array![549137589365708000, 2, 301552092054380000],
        array![14163921244333700, 3, 2841518643583],
        array![173482812472018000, 2, 30096286223201300],
        array![089043101634399300, 2, 7928673948673970],
        array![228676956496486000, 2, 52293150432495800],
        array![690422882634616000, 8, 51632293155573900],
        array![88730376626724100, 11, 2684081],
        array![73384846339964600, 5, 2128295594269],
        array![332854710158557000, 10, 16693487237081],
        array![543415023125456000, 24, 439702946262],
        array![289299391854347000, 2, 83694138127294900],
        array![356290645277924000, 2, 126943023912560000],
        array![477806998132950000, 8, 2716564683301040],
        array![410750871076822000, 6, 4802539645325750],
        array![475222270242414000, 4, 51001992001158600],
        array![121455252120304000, 22, 0],
        array![9639247474367520, 4, 8633214298],
        array![637853277178133000, 2, 406856803206885000],
        array![484746955319000000, 6, 12974497294315000],
        array![370594630844984000, 14, 921696040698],
        array![289829200819417000, 12, 351322263034],
        array![229325825269870000, 8, 7649335694527],
        array![265776787719080000, 12, 124223733254],
        array![461409786304156000, 27, 851811777],
        array![240236841088914000, 11, 153828106713],
        array![23036079879643700, 2, 530660976221324],
        array![861616242485528000, 97, 531430041443],
        array![72241661275119400, 212, 0],
        array![924071964863292000, 17, 261215237312535000],
        array![977575971186712000, 19, 649919912701292000],
        array![904200910071210000, 15, 220787304397256000],
        array![858551742150349000, 143, 337758087],
        array![581850663606974000, 68, 102],
        array![354836074035232000, 16, 63160309272],
        array![968639062260900000, 37, 307604877091227000],
        array![784478611520428000, 140, 1743],
        array![61314555619941600, 13, 173],
        array![562295998606858000, 71, 000000000000000002],
        array![896709855620154000, 20, 112989701464696000],
        array![8484527608110470, 111, 0],
        array![33987471529490900, 190, 0],
        array![109333102690035000, 59, 0],
        array![352436592744656000, 4, 15428509626763400],
        array![940730690913636000, 111, 1134095778412580],
        array![665800835711181000, 87, 428],
        array![365267526644046000, 208, 0],
        array![432669515365048000, 171, 0],
        array![457498365370101000, 40, 26036],
        array![487046034636363000, 12, 178172281758289],
        array![919877008002166000, 85, 826094891277916],
    ];

    let mut i = 0;
    let mut values_len = exponentiationResults.len();
    loop {
        if i == values_len {
            break;
        }

        let values = exponentiationResults.pop_front().unwrap();

        let base = *values[0];
        let exponent = *values[1];
        let expectedResult = *values[2];

        let res = InternalImpl::_dec_pow(base, exponent);

        // Allow absolute error tolerance of 1e-14
        if (expectedResult >= 10000) {
            assert(res >= expectedResult - 10000, 'wrong result');
        } else {
            assert(res >= 0, 'wrong result');
        }
        assert(res <= expectedResult + 10000, 'wrong result');

        i += 1;
    };
}

//Following tests are taken from : https://github.com/Gravita-Protocol/Gravita-SmartContracts/blob/95e3b30d877540eecda276deaff6e21e19e51460/test/gravita/VesselManagerTest.js#L6649C13-L6649C13

#[test]
// Returns 0 if vessel's coll is worth 0
fn test_compute_cr_with_price_0() {
    let price = 0;
    let coll = 1000000000000000000;
    let debt = 100000000000000000000;

    let res = InternalImpl::_compute_cr(coll, debt, price);
    assert(res == 0, 'wrong cr');
}

#[test]
// Returns 2^256-1 for ETH:USD = 100, coll = 1 ETH, debt = 100 GRAI
fn test_compute_cr_with_coll_1_eth() {
    let price = 100000000000000000000;
    let coll = 1000000000000000000;
    let debt = 100000000000000000000;

    let res = InternalImpl::_compute_cr(coll, debt, price);
    assert(res == 1000000000000000000, 'wrong cr');
}

#[test]
// Returns correct ICR for ETH:USD = 100, coll = 200 ETH, debt = 30 GRAI
fn test_compute_cr_with_coll_200_eth() {
    let price = 100000000000000000000;
    let coll = 200000000000000000000;
    let debt = 30000000000000000000;

    let res = InternalImpl::_compute_cr(coll, debt, price);
    assert(res >= 666666666666666665666, 'wrong cr');
    assert(res <= 666666666666666667666, 'wrong cr');
}

#[test]
// Returns correct ICR for ETH:USD = 250, coll = 1350 ETH, debt = 127 GRAI
fn test_compute_cr_with_coll_1350_eth() {
    let price = 250000000000000000000;
    let coll = 1350000000000000000000;
    let debt = 127000000000000000000;

    let res = InternalImpl::_compute_cr(coll, debt, price);
    assert(res >= 2657480314960629000000, 'wrong cr');
    assert(res <= 2657480314960631000000, 'wrong cr');
}

#[test]
// Returns correct ICR for ETH:USD = 100, coll = 1 ETH, debt = 54321 GRAI
fn test_compute_cr_with_coll_1_eth_debt_54321() {
    let price = 100000000000000000000;
    let coll = 1000000000000000000;
    let debt = 54321000000000000000000;

    let res = InternalImpl::_compute_cr(coll, debt, price);
    assert(res >= 1840908672519756, 'wrong cr');
    assert(res <= 1840908672521756, 'wrong cr');
}

#[test]
// Returns 2^256-1 if vessel has non-zero coll and zero debt
fn test_compute_cr_with_debt_0() {
    let price = 100000000000000000000;
    let coll = 1000000000000000000;
    let debt = 0;

    let res = InternalImpl::_compute_cr(coll, debt, price);
    assert(res == BoundedU256::max(), 'wrong cr');
}
