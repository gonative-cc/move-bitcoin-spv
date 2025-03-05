#[test_only]
module bitcoin_spv::btc_math_tests;
use bitcoin_spv::btc_math::{target_to_bits, bits_to_target, compact_size, Self};


#[test]
fun btc_hash_test() {
    let pre_image =
        x"00000020acb9babeb35bf86a3298cd13cac47c860d82866ebf9302000000000000000000dd0258540ffa51df2af80bd4e3ae82b7781c167ec84d4001e09c2e4053cdc4410d0f8864697e0517893b3045";
    let result = x"37ed684e163e76275a38fc0a318730c0aed92967f64c03000000000000000000";

    assert!(btc_math::btc_hash(pre_image) == result);
}

#[test]
fun to_u32_test() {
    //  Bytes vector is in little-endian format.
    assert!(btc_math::to_u32(x"00000000") == 0u32);
    assert!(btc_math::to_u32(x"01000000") == 1u32);
    assert!(btc_math::to_u32(x"ff000000") == 255u32);
    assert!(btc_math::to_u32(x"00010000") == 256u32);
    assert!(btc_math::to_u32(x"ffffffff") == 4294967295u32);
    assert!(btc_math::to_u32(x"01020304") == 67305985u32);
}


#[test]
fun to_u256_test() {
    //  Bytes vector is in little-endian format.
    assert!(
        btc_math::to_u256(x"0000000000000000000000000000000000000000000000000000000000000000") == 0,
    );
    assert!(
        btc_math::to_u256(x"0100000000000000000000000000000000000000000000000000000000000000") == 1,
    );
    assert!(
        btc_math::to_u256(x"ff00000000000000000000000000000000000000000000000000000000000000") == 255,
    );
    assert!(
        btc_math::to_u256(x"0001000000000000000000000000000000000000000000000000000000000000") == 256,
    );
    assert!(
        btc_math::to_u256(x"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff") == (1 << 255) - 1 + (1 << 255),
    );
    assert!(
        btc_math::to_u256(x"0102030400000000000000000000000000000000000000000000000000000000") == 67305985,
    );
}

#[test]
fun bits_to_target_tests() {
    // Data get from btc main net at block 880,086
    let bits = 0x17028c61;
    let target = bits_to_target(bits);
    assert!(target == 0x000000000000000000028c610000000000000000000000000000000000000000);
    assert!(bits == target_to_bits(target));

    // data from block 489,888
    let bits = 0x1800eb30;
    let target = bits_to_target(bits);
    assert!(target == 0x000000000000000000eb30000000000000000000000000000000000000000000);
    assert!(bits == target_to_bits(target));


    // block 860832
    let bits = 0x1703098c;
    let target = bits_to_target(bits);
    assert!(target == 0x00000000000000000003098c0000000000000000000000000000000000000000);
    assert!(bits == target_to_bits(target));

    let bits = 0x2000ffff;
    let target = bits_to_target(bits);
    assert!(target == 0x00ffff0000000000000000000000000000000000000000000000000000000000);
    assert!(bits == target_to_bits(target));
}



#[test]
fun compact_size_tests() {
    let inputs = vector[
        x"fa",
        x"fc",
        x"fdfd00",
        x"fdd007",
        x"fdffff",
        x"fe00000100",
        x"fe005a6202",
        x"feffffffff",
        x"ff0000000001000000",
        x"ff98fdffffffffffff",
        x"ffffffffffffffffff",
    ];
    let outputs = vector[
        vector[250, 1],
        vector[252, 1],
        vector[253, 3],
        vector[2000, 3],
        vector[65535, 3],
        vector[65536, 5],
        vector[40000000, 5],
        vector[4294967295, 5],
        vector[4294967296, 9],
        vector[18446744073709551000, 9],
        vector[18446744073709551615, 9]
    ];

    let mut i = 0;
    while (i < inputs.length()) {
        let (x, y) = compact_size(inputs[i], 0);
        assert!(x == outputs[i][0] && (y as u256) == outputs[i][1]);
        i = i + 1;
    }

}
