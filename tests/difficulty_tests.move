#[test_only]
module bitcoin_spv::difficulty_test;

use bitcoin_spv::light_client::{mainnet_params, regtest_params, new_light_client_with_params, retarget_algorithm, calc_next_required_difficulty};
use bitcoin_spv::light_block::{new_light_block};
use bitcoin_spv::btc_math::{bits_to_target, target_to_bits};
use bitcoin_spv::block_header::new_block_header;

use sui::test_scenario;

#[test_only]
fun is_equal_target(x: u256, y: u256): bool {
    target_to_bits(x) == target_to_bits(y)
}

#[test]
fun retarget_algorithm_test() {
    let p = mainnet_params();

    // sources: https://learnmeabitcoin.com/explorer/block/00000000000000000002819359a9af460f342404bec23e7478512a619584083b
    // NOTES: In Move, we are using big endian. So format here is big endian.
    // this is reverse order of data in raw block
    let previous_target = bits_to_target(0x1702905c);
    let first_timestamp = 0x6771c559;

    let expected = bits_to_target(0x17028c61);
    let second_timestamp = 0x67841db6;
    let actual = retarget_algorithm(&p, previous_target, first_timestamp, second_timestamp);
    assert!(actual == 244084856254285558118414851546990328505140483644194816);
    assert!(is_equal_target(expected, actual));


    // source:https://learnmeabitcoin.com/explorer/block/00000000000000000002819359a9af460f342404bec23e7478512a619584083b
    let previous_target = bits_to_target(0x1703098c);
    let first_timestamp = 0x66e10dc5;
    let expected = bits_to_target(0x17032f14);
    let second_timestamp = 0x66f466dc;
    let actual = retarget_algorithm(&p, previous_target, first_timestamp, second_timestamp);
    assert!(is_equal_target(expected, actual));


    // overflow tests
    // 2000ffff
    let previous_target = bits_to_target(0x2000ffff);
    let first_timestamp = 0x00000000;
    let second_timestamp = 0xffffffff;
    // second_timestamp - first_timestamp always greater than target_timespan * 4
    let actual = retarget_algorithm(&p, previous_target, first_timestamp, second_timestamp);
    let expected = 26959946667150639794667015087019630673637144422540572481103610249215;
    assert!(actual == expected);

    sui::test_utils::destroy(p);
}

#[test]
fun test_difficulty_computation_mainnet() {
    let sender = @0x01;
    let mut scenario = test_scenario::begin(sender);

    let p = mainnet_params();
    let mut lc = new_light_client_with_params(p, 0, vector[x"0100000000000000000000000000000000000000000000000000000000000000000000003ba3edfd7a7b12b27ac72c3e67768f617fc81bc3888a51323a9fb8aa4b1e5e4a29ab5f49ffff001d1dac2b7c"], 0, scenario.ctx());

    let block_hash = lc.get_block_hash_by_height(0);

    // The next difficulty at genesis block is equal power of limit.
    assert!(calc_next_required_difficulty(&lc, lc.get_light_block_by_hash(block_hash), 0) == target_to_bits(lc.params().power_limit()));

    let header = new_block_header(x"0040a320aa52a8971f61e56bf5a45117e3e224eabfef9237cb9a0100000000000000000060a9a5edd4e39b70ee803e3d22673799ae6ec733ea7549442324f9e3a790e4e4b806e1665b250317807427ca");
    let last_block = new_light_block(
        860831,
        header,
        0
    );

    let last_block_hash = last_block.header().block_hash();
    lc.set_block_hash_by_height(last_block.height(), last_block_hash);
    lc.add_light_block(last_block);
    let header = new_block_header(x"0060b0329fd61df7a284ba2f7debbfaef9c5152271ef8165037300000000000000000000562139850fcfc2eb3204b1e790005aaba44e63a2633252fdbced58d2a9a87e2cdb34cf665b250317245ddc6a");
    let first_block = new_light_block(858816,   header, 0);
    lc.set_block_hash_by_height(first_block.height(), first_block.header().block_hash());
    lc.add_light_block(first_block);


    let new_bits = calc_next_required_difficulty(&lc, lc.get_light_block_by_hash(last_block_hash), 0);

    // 0x1703098c is bits of block 860832
    assert!(new_bits == 0x1703098c);
    sui::test_utils::destroy(lc);
    scenario.end();
}

#[test]
fun test_difficulty_computation_regtest() {
    let sender = @0x01;
    let mut scenario = test_scenario::begin(sender);

    let p = regtest_params();
    let lc = new_light_client_with_params(
        p,
        10,
        // note: this is random header and when compute a new target in regtest mode this alway return constant
        // this is power_limit.
        vector[x"0040a320aa52a8971f61e56bf5a45117e3e224eabfef9237cb9a0100000000000000000060a9a5edd4e39b70ee803e3d22673799ae6ec733ea7549442324f9e3a790e4e4b806e1665b250317807427ca"],
        0,
        scenario.ctx()
    );

    let block_hash = lc.get_block_hash_by_height(10);
    let new_bits = calc_next_required_difficulty(&lc, lc.get_light_block_by_hash(block_hash), 0);
    assert!(new_bits == target_to_bits(lc.params().power_limit()));
    sui::test_utils::destroy(lc);
    scenario.end();
}
