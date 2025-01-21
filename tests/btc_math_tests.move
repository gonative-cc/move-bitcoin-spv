#[test_only]
module bitcoin_spv::btc_math_tests;

// Data get from btc main net at block 880,086

#[test]
fun target_to_bits_test() {
    let bits = bitcoin_spv::btc_math::target_to_bits(0x000000000000000000028c610000000000000000000000000000000000000000);
    assert!(bits == 0x17028c61)
}

#[test]
fun bits_to_target_test() {
    let target = bitcoin_spv::btc_math::bits_to_target(0x17028c61);
    assert!(target == 0x000000000000000000028c610000000000000000000000000000000000000000)
}
