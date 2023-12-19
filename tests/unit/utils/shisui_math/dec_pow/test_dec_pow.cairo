use core::integer::BoundedU256;
use shisui::utils::{shisui_math::{dec_pow, get_absolute_difference}, constants::ONE};
use tests::helpers::constants::TimeValues;


#[test]
fn when_exponent_is_0_it_should_return_1() {
    let res = dec_pow(0, 0);
    assert(res == ONE, 'Wrong result base 0');

    let res = dec_pow(1, 0);
    assert(res == ONE, 'Wrong result base 1');

    let res = dec_pow(ONE, 0);
    assert(res == ONE, 'Wrong result base 10^18');

    let res = dec_pow(123244254546, 0);
    assert(res == ONE, 'Wrong result base 123244254546');

    let res = dec_pow(990000000000000000, 0);
    assert(res == ONE, 'Wrong result base 99*10^16');

    let res = dec_pow(897890990909098978678609090, 0);
    assert(res == ONE, 'Wrong result base big number');

    let res = dec_pow(8789789000000000000000000000000000, 0);
    assert(res == ONE, 'Wrong result base huge number');

    let res = dec_pow(BoundedU256::max(), 0);
    assert(res == ONE, 'Wrong result base max u256');
}


#[test]
fn when_exponent_is_0_it_should_return_base() {
    let res = dec_pow(0, 1);
    assert(res == 0, 'Wrong result base 0');

    let res = dec_pow(1, 1);
    assert(res == 1, 'Wrong result base 1');

    let res = dec_pow(ONE, 1);
    assert(res == ONE, 'Wrong result base 10^18');

    let res = dec_pow(123244254546, 1);
    assert(res == 123244254546, 'Wrong result base 123244254546');

    let res = dec_pow(990000000000000000, 1);
    assert(res == 990000000000000000, 'Wrong result base 99*10^16');

    let res = dec_pow(897890990909098978678609090, 1);
    assert(res == 897890990909098978678609090, 'Wrong result base big number');

    let res = dec_pow(8789789000000000000000000000000000, 1);
    assert(res == 8789789000000000000000000000000000, 'Wrong result base huge number');

    let res = dec_pow(BoundedU256::max(), 1);
    assert(res == BoundedU256::max(), 'Wrong result base max u256');
}


#[test]
fn when_base_is_0_it_should_return_0() {
    let res = dec_pow(0, 1);
    assert(res == 0, 'Wrong result exponent 1');

    let res = dec_pow(0, 3);
    assert(res == 0, 'Wrong result exponent 3');

    let res = dec_pow(0, 17);
    assert(res == 0, 'Wrong result exponent 17');

    let res = dec_pow(0, 44);
    assert(res == 0, 'Wrong result exponent 44');

    let res = dec_pow(0, 118);
    assert(res == 0, 'Wrong result exponent 118');

    let res = dec_pow(0, 1000);
    assert(res == 0, 'Wrong result exponent 1000');

    let res = dec_pow(0, 1000000);
    assert(res == 0, 'Wrong result exponent 10^6');

    let res = dec_pow(0, 1000000000);
    assert(res == 0, 'Wrong result exponent 10^9');

    let res = dec_pow(0, 1000000000000);
    assert(res == 0, 'Wrong result exponent 10^12');

    let res = dec_pow(0, ONE);
    assert(res == 0, 'Wrong result exponent 10^18');
}


#[test]
fn when_base_is_1_it_should_return_1() {
    let res = dec_pow(ONE, 1);
    assert(res == ONE, 'Wrong result exponent 1');

    let res = dec_pow(ONE, 3);
    assert(res == ONE, 'Wrong result exponent 3');

    let res = dec_pow(ONE, 17);
    assert(res == ONE, 'Wrong result exponent 17');

    let res = dec_pow(ONE, 44);
    assert(res == ONE, 'Wrong result exponent 44');

    let res = dec_pow(ONE, 118);
    assert(res == ONE, 'Wrong result exponent 118');

    let res = dec_pow(ONE, 1000);
    assert(res == ONE, 'Wrong result exponent 1000');

    let res = dec_pow(ONE, 1000000);
    assert(res == ONE, 'Wrong result exponent 10^6');

    let res = dec_pow(ONE, 1000000000);
    assert(res == ONE, 'Wrong result exponent 10^9');

    let res = dec_pow(ONE, 1000000000000);
    assert(res == ONE, 'Wrong result exponent 10^12');

    let res = dec_pow(ONE, ONE);
    assert(res == ONE, 'Wrong result exponent 10^18');
}


#[test]
fn when_exponent_is_2_it_should_return_the_square_of_base() {
    let res = dec_pow(ONE, 2);
    assert(res == ONE, 'Wrong result base 1');

    let res = dec_pow(1500000000000000000, 2);
    assert(res == 2250000000000000000, 'Wrong result base 1.5');

    let res = dec_pow(500000000000000000, 2);
    assert(res == 250000000000000000, 'Wrong result base 0.5');

    let res = dec_pow(321000000000000000, 2);
    assert(res == 103041000000000000, 'Wrong result base 0.321');

    let res = dec_pow(2000000000000000000, 2);
    assert(res == 4000000000000000000, 'Wrong result base 2');

    let res = dec_pow(100000000000000000, 2);
    assert(res == 10000000000000000, 'Wrong result base 0.1');

    let res = dec_pow(10000000000000000, 2);
    assert(res == 100000000000000, 'Wrong result base 0.01');

    let res = dec_pow(990000000000000000, 2);
    assert(res == 980100000000000000, 'Wrong result base 0.99');

    let res = dec_pow(125435000000000000000, 2);
    assert(res == 15733939225000000000000, 'Wrong result base 125.435');

    let res = dec_pow(99999000000000000000000, 2);
    assert(res == 9999800001000000000000000000, 'Wrong result base 99999');
}

#[test]
fn when_various_base_and_exponent_value_it_should_return_right_value() {
    let tolerance_value = 10000;

    // Exponent in range [2, 300]
    // [base, exponent, expected_result]
    let mut exponentiation_results = array![
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

    loop {
        match exponentiation_results.pop_front() {
            Option::Some(values) => {
                let base = *values[0];
                let exponent = *values[1];
                let expected_result = *values[2];

                let res = dec_pow(base, exponent);

                // Allow absolute error tolerance of 1e-14
                assert(
                    get_absolute_difference(res, expected_result) <= tolerance_value, 'Wrong result'
                );
            },
            Option::None => { break; },
        }
    };
}

#[test]
fn when_limit_range_value_are_selected_it_should_should_be_acceptable() {
    let tolerance_value = 1000000000;

    // [base, exponent, expected_result]
    let mut bases = array![
        array![999999000000000000, TimeValues::SECONDS_IN_ONE_MONTH * 3, 419685940126918],
        array![999999900000000000, TimeValues::SECONDS_IN_ONE_MONTH * 3, 459507489132817380],
        array![999999999999999999, TimeValues::SECONDS_IN_ONE_MONTH * 3, 999999999992224000],
        array![999999000000000000, TimeValues::SECONDS_IN_ONE_MONTH, 74870052913543610],
        array![999999900000000000, TimeValues::SECONDS_IN_ONE_MONTH, 771668663873699542],
        array![999999999999999999, TimeValues::SECONDS_IN_ONE_MONTH, 999999999997408000],
        array![999999000000000000, TimeValues::MINUTES_IN_ONE_MONTH, 957719806259206083],
        array![999999900000000000, TimeValues::MINUTES_IN_ONE_MONTH, 995689317562502446],
        array![999999999999999999, TimeValues::MINUTES_IN_ONE_MONTH, 999999999999956800],
        array![999999000000000000, TimeValues::MINUTES_IN_ONE_YEAR, 591200382239283334],
        array![999999900000000000, TimeValues::MINUTES_IN_ONE_YEAR, 948797389011001844],
        array![999999999999999999, TimeValues::MINUTES_IN_ONE_YEAR, 999999999999474400],
        array![999999000000000000, TimeValues::MINUTES_IN_ONE_YEAR * 5, 72222668515608747],
        array![999999900000000000, TimeValues::MINUTES_IN_ONE_YEAR * 5, 768895650963195928],
        array![999999999999999999, TimeValues::MINUTES_IN_ONE_YEAR * 5, 999999999997372000],
        array![999999000000000000, TimeValues::MINUTES_IN_ONE_YEAR * 10, 5216113847515503],
        array![999999900000000000, TimeValues::MINUTES_IN_ONE_YEAR * 10, 591200522070116820],
        array![999999999999999999, TimeValues::MINUTES_IN_ONE_YEAR * 10, 999999999994744000],
        array![999999000000000000, TimeValues::MINUTES_IN_ONE_YEAR * 100, 0],
        array![999999900000000000, TimeValues::MINUTES_IN_ONE_YEAR * 100, 5216126184691612],
        array![999999999999999999, TimeValues::MINUTES_IN_ONE_YEAR * 100, 999999999947440000],
    ];

    loop {
        match bases.pop_front() {
            Option::Some(values) => {
                let base = *values[0];
                let exponent = *values[1];
                let expected_result = *values[2];

                let res = dec_pow(base, exponent);

                // Allow absolute error tolerance of 1e-9
                assert(
                    get_absolute_difference(res, expected_result) <= tolerance_value, 'Wrong result'
                );
            },
            Option::None => { break; },
        }
    };
}


#[test]
fn when_exponent_greater_than_1000_years_in_minutes_it_should_not_overflow() {
    let exponent = TimeValues::MINUTES_IN_ONE_YEAR * 1000 + 9;
    let mut bases = array![000000000000000001, 999999999999900000, 999999999999999999];
    loop {
        match bases.pop_front() {
            Option::Some(base) => { dec_pow(base, exponent); },
            Option::None => { break; },
        }
    };
}
