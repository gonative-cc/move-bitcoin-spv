module bitcoin_spv::btc_math;

use std::hash;
use std::u64::do;

/// === Errors ===
const EInvalidLength: u64 = 0;
const EInvalidCompactSizeDecode: u64 = 1;
const EInvalidCompactSizeEncode: u64 = 2;
/// convert 4 bytes in little endian format to u32 number
public fun to_u32(v: vector<u8>): u32 {
    assert!(v.length() == 4, EInvalidLength);
    let mut ans = 0u32;
    let mut i = 0u8;
    while (i < 4) {
        ans = ans + ((v[i as u64] as u32) << i*8);
        i = i + 1;
    };

    ans
}

/// convert 32 bytes in little endian format to u256 number.
public fun to_u256(v: vector<u8>): u256 {
    assert!(v.length() == 32, EInvalidLength);
    let mut ans = 0u256;
    let mut i = 0;
    while (i < 32) {
        ans = ans +  ((v[i] as u256)  << (i * 8 as u8));
        i = i + 1;
    };
    ans
}

/// double hash of value
public fun btc_hash(data: vector<u8>): vector<u8> {
    let first_hash = hash::sha2_256(data);
    let second_hash = hash::sha2_256(first_hash);
    return second_hash
}


fun compact_size_offset(start_byte: u8): u64 {
    if (start_byte <= 0xfc) {
        return 0
    };
    if (start_byte == 0xfd) {
        return 2
    };
    if (start_byte == 0xfe) {
        return 4
    };
    // 0xff
    return 8
}


/// decode compact size from vector
public fun compact_size(v: vector<u8>, start: u64): (u256, u64) {
    let offset = compact_size_offset(v[start]);
    assert!(start + offset < v.length(), EInvalidCompactSizeDecode);
    if (offset == 0) {
        return (v[start] as u256, start + 1)
    };
    (to_number(v, start + 1, start + offset + 1), start + offset + 1)
}

/// TODO: replace to_u256 and to_u32
public fun to_number(v: vector<u8>, start: u64, end: u64): u256{
    let size = end - start;
    assert!(size <= 32, EInvalidLength);
    let mut ans = 0u256;
    let mut i = start;
    let mut j = 0;
    while (i < end) {
        ans = ans +  ((v[i] as u256)  << (j * 8 as u8));
        i = i + 1;
        j = j + 1;
    };
    ans
}

/// number of bytes to represent number.
fun bytes_of(number: u256) : u8 {
    let mut b : u8 = 255;
    while (number & (1 << b) == 0 && b > 0) {
        b = b - 1;
    };
    // Follow logic in bitcoin core
    ((b as u32 + 7 ) / 8) as u8
}


/// get last 32 bits of number
fun get_last_32_bits(number: u256): u32 {
    return (number & 0xffffffff) as u32
}

/// target => bits conversion function.
/// target is the number you need to get below to mine a block - it defines the difficulty.
/// The bits field contains a compact representation of the target.
/// format of bits = <1 byte for exponent><3 bytes for coefficient>
/// target = coefficient * 2^ (coefficient - 3) (note: 3 = bytes length of the coefficient).
/// Caution:
///    The first significant byte for the coefficient must be below 80. If it's not, you have to take the preceding 00 as the first byte.
/// More & examples: https://learnmeabitcoin.com/technical/block/bits.
public fun target_to_bits(target: u256): u32 {
    // TODO: Handle case nagative target?
    // I checked bitcoin-code. They did't create any negative target.

    let mut exponent = bytes_of(target);
    let mut coefficient;
    if (exponent <= 3) {
        let bits_shift: u8 = 8 * ( 3 - exponent);
        coefficient = get_last_32_bits(target) << bits_shift;
    } else {
        let bits_shift : u8 = 8 * (exponent - 3);
        let bn = target >> bits_shift;
        coefficient = get_last_32_bits(bn)
    };


    // handle case target is nagative number.
    // 0x00800000 is set then it indicates a negative value
    // and target can be nagative
    if (coefficient & 0x00800000 > 0) {
        // we push 00 before coefficet
        coefficient = coefficient >> 8;
        exponent = exponent + 1;
    };

    let compact = coefficient | ((exponent as u32) << 24);

    // TODO: Check case target is a negative number.
    // However, the target mustn't be a negative number

    compact
}

/// converts bits to target. See documentation to the function above for more details.
public fun bits_to_target(bits: u32): u256 {
    let exponent = bits >> 3*8;

    // extract coefficient path or get last 24 bit of `bits`
    let mut target = (bits & 0x007fffff) as u256;

    if (exponent <= 3) {
        let bits_shift = (8 * (3 - exponent)) as u8;
        target = target >> bits_shift;
    } else {
        let bits_shift = (8 * (exponent - 3)) as u8;
        target = target << bits_shift;
    };
    return target
}


public fun covert_to_compact_size(number: u256): vector<u8> {
    let mut ans = vector[];
    let mut n = number;
    if (n <= 252) {
        ans.push_back(n as u8);
    } else if (n <= 65535) {
        ans.push_back(0xfd);
        do!(3, |_i| {
            ans.push_back((n & 256) as u8);
            n = n >> 8;
        });
    } else if (n <= 4294967295) {
        ans.push_back(0xfe);
        do!(5, |_i| {
            ans.push_back((n & 256) as u8);
            n = n >> 8;
        });
    } else if (n <= 18446744073709551615) {
        ans.push_back(0xff);
        do!(9, |_i| {
            ans.push_back((n & 256) as u8);
            n = n >> 8;
        });
    } else {
        abort EInvalidCompactSizeEncode
    };

    return ans
}

// internal test
// TODO: Check best practice to improve test
#[test]
fun bytes_of_test() {
    assert!(bytes_of(0) == 0);
    assert!(bytes_of(7) == 1);
    assert!(bytes_of(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) == 32);
}

#[test]
/// get last 32 bits of number
fun get_last_32_bits_test() {
    assert!(get_last_32_bits(0) == 0);
    assert!(get_last_32_bits(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) == 0xffffffff);
    assert!(get_last_32_bits(0x0123456789) == 0x23456789);
}

#[test]
fun check_compact_size_format_test() {
    let inputs = vector[
        0x0a,
        0xfc,
        0xfd,
        0xfe,
        0xff,

    ];
    let outputs = vector[
        0,
        0,
        2,
        4,
        8,
    ];

    let mut i = 0;
    while (i < inputs.length()) {
        assert!(compact_size_offset(inputs[i]) == outputs[i]);
        i = i + 1;
    }

}
