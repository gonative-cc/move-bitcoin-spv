#[test_only]
module bitcoin_spv::light_client_tests;

use bitcoin_spv::light_client::{insert_header, new_light_client, LightClient, mainnet_params, EBlockHashNotMatch, EDifficultyNotMatch, ETimeTooOld};
use bitcoin_spv::light_block::new_light_block;
use bitcoin_spv::block_header::new_block_header;

use sui::test_scenario;


#[test_only]
fun new_lc_for_test(ctx: &mut TxContext) : LightClient {
    let start_block = 858806;
    let headers = vector[
        x"00a0b434e99097082da749068bd8cc81f7ddd017f3153e1f25b000000000000000000000fbef99870f826601fed79703773deb9122f03b5167c0b7554c00112f9fa99e171320cf66763d03175c560dcc",
        x"00205223ce8791e22d0a1b64cfb0b485af2ddba566cb54292e0c030000000000000000003f5d648740a3a0519c56fce7f230d4c35aa83c9df0478b77be3fc89f0acfb8cc9524cf66763d03171746f213",
        x"0000c72367c8c7e8515c552d74707468a84d2fda2da63d65cbec01000000000000000000ec9d236ac946e604e3272ab775a501ebe05e8b06a8ec70b8c51b7ccba38af21b1c26cf66763d0317c3442435",
        x"00c057251d6ff0cb1d8eb9452f6578fafd41c5435dbfae6dbd5a01000000000000000000a8c4158d905a4fd766328c4717222737d4105220ee3aae80fbe57928689a7544cb27cf66763d0317a29c9617",
        x"00800a2088931286b1c6af1e23730089387def8a89e248de2a6501000000000000000000a6d9635ee5e71023ee76c5569e770d432302593757a0e2e343f083764cd8f3155328cf66763d03175a15982c",
        x"00a06b23d73ad1793c6b81cb331b00023a1c84611ae6fe46b08f00000000000000000000dd4c22396df46efc796ebbdfd82cb74d4c3eaf5e8e18134b7fda9379e82ebd2a752bcf66763d031766c189d5",
        x"00e06c2e314994230081f451d0fba9016cea4be4afd3b4c20d46010000000000000000006e110e2bc3bb80af0fa41dada4829fe5bc8a7a6269b588fff5f708d551130d649d2bcf66763d0317c530dcc8",
        x"00000028f1b88a82b706583e794319f23feb40ef6d9b42ee9817020000000000000000003a899be6d63b05795d9b5da4d091fb9e37a5bf4783faaf1ae9e8aafa861462e7682dcf66763d0317844b2ed2",
        x"00007f300670de9a5071f41ff3efdfede97d98b9044d71d77dd700000000000000000000835f42b3d177c5d7b5b844efa4a6ac682bacc4d2862169ee8607da3ec5f4ef3ab32dcf66763d031759921deb",
        x"00800120451bed6d330bd942a708b0858fdbb7d265e5b7caa3c00000000000000000000025ba876f2efbd1522e36a7cd807879eeec843f95da8a01993556100e3226900b8d30cf66763d0317bd91acc5",
        x"0060b0329fd61df7a284ba2f7debbfaef9c5152271ef8165037300000000000000000000562139850fcfc2eb3204b1e790005aaba44e63a2633252fdbced58d2a9a87e2cdb34cf665b250317245ddc6a"
    ];
    let params = mainnet_params();
    let lc = new_light_client(params, start_block, headers, 0,  ctx);
    return lc
}


#[test]
fun test_set_get_block_happy_case() {
    let sender = @0x01;
    let mut scenario = test_scenario::begin(sender);
    let ctx = scenario.ctx();
    let lc = new_lc_for_test(ctx);
    let header = new_block_header(x"0060b0329fd61df7a284ba2f7debbfaef9c5152271ef8165037300000000000000000000562139850fcfc2eb3204b1e790005aaba44e63a2633252fdbced58d2a9a87e2cdb34cf665b250317245ddc6a");
    assert!(lc.latest_finalized_height() == 858816);
    assert!(lc.latest_finalized_block().header().block_hash() == header.block_hash());
    sui::test_utils::destroy(lc);
    scenario.end();
}


#[test]
#[expected_failure]
fun test_set_get_block_failed_case() {
    let sender = @0x01;
    let mut scenario = test_scenario::begin(sender);
    let ctx = scenario.ctx();
    let lc = new_lc_for_test(ctx);

    lc.get_light_block_by_hash(x"011011");

    sui::test_utils::destroy(lc);
    scenario.end();
}

#[test]
fun test_insert_header_happy_cases() {
    let sender = @0x01;
    let mut scenario = test_scenario::begin(sender);

    let ctx = scenario.ctx();
    let mut lc = new_lc_for_test(ctx);

    let raw_header = x"00801e31c24ae25304cbac7c3d3b076e241abb20ff2da1d3ddfc00000000000000000000530e6745eca48e937428b0f15669efdce807a071703ed5a4df0e85a3f6cc0f601c35cf665b25031780f1e351";
    lc.insert_header(raw_header, ctx);
    let latest_height = lc.latest_finalized_height();
    let block_hash = lc.get_block_header_by_height(latest_height).block_hash();
    assert!(lc.get_light_block_by_hash(block_hash).header() == new_block_header(raw_header));

    let last_block = new_light_block(
        860831,
        x"0040a320aa52a8971f61e56bf5a45117e3e224eabfef9237cb9a0100000000000000000060a9a5edd4e39b70ee803e3d22673799ae6ec733ea7549442324f9e3a790e4e4b806e1665b250317807427ca",
        0,
        ctx
    );
    let latest_height = lc.latest_finalized_height();
    lc.add_light_block(last_block);
    let new_header = x"006089239c7c45da6d872c93dc9e8389d52b04bdd0a824eb308002000000000000000000fb4c3ac894ebc99c7a7b76ded35ec1c719907320ab781689ba1dedca40c5a9d7c50de1668c09031716c80c0d";
    lc.insert_header(new_header, ctx);
    let block_hash = lc.get_block_header_by_height(latest_height).block_hash();
    assert!(lc.get_light_block_by_hash(block_hash).header() == new_block_header(raw_header));

    sui::test_utils::destroy(lc);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = EBlockHashNotMatch)]
fun test_insert_header_failed_block_hash_not_match() {
    let sender = @0x01;
    let mut scenario = test_scenario::begin(sender);
    let mut lc = new_lc_for_test(scenario.ctx());
    let ctx = scenario.ctx();

    // we changed the block hash to make new header previous hash not match with last hash
    let new_header = x"00801e31c24ae25304cbac7c3d3b076e241abb20ff2da1d3ddfc00000000000000000001530e6745eca48e937428b0f15669efdce807a071703ed5a4df0e85a3f6cc0f601c35cf665b25031780f1e351";
    lc.insert_header(new_header, ctx);

    sui::test_utils::destroy(lc);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = EDifficultyNotMatch)]
fun test_insert_header_failed_difficulty_not_match() {
    let sender = @0x01;
    let mut scenario = test_scenario::begin(sender);
    let mut lc = new_lc_for_test(scenario.ctx());
    let ctx = scenario.ctx();

    // we changed the block hash to make new header previous hash not match with last hash
    let new_header = x"00801e31c24ae25304cbac7c3d3b076e241abb20ff2da1d3ddfc00000000000000000000530e6745eca48e937428b0f15669efdce807a071703ed5a4df0e85a3f6cc0f601c35cf665b25031880f1e351";
    lc.insert_header(new_header, ctx);
    sui::test_utils::destroy(lc);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = ETimeTooOld)]
fun test_insert_header_failed_timestamp_too_old() {
    let sender = @0x01;
    let mut scenario = test_scenario::begin(sender);
    let mut lc = new_lc_for_test(scenario.ctx());
    let ctx = scenario.ctx();

    // we changed timestamp from 1c35cf66 to 0c35cf46
    let new_header = x"00801e31c24ae25304cbac7c3d3b076e241abb20ff2da1d3ddfc00000000000000000000530e6745eca48e937428b0f15669efdce807a071703ed5a4df0e85a3f6cc0f600c35cf465b25031780f1e351";
    lc.insert_header(new_header, ctx);
    sui::test_utils::destroy(lc);
    scenario.end();
}

#[test_only]
// a sample valid (height, tx_id, proof, tx_index)
fun sample_data(): (u64, vector<u8>, vector<vector<u8>>, u64) {
    let height = 858816;
    let tx_id = x"a1a81fcc85f94d84a7920aadf456c64a93ffab20dba7066124ba9bd7ef2b262a";
    let tx_index = 99;
    let proof = vector[
        x"3226b3fd4e459a18d8e354750ba7802721076ec2b9a0b62704a79362a46d969c",
        x"9f2d6dd28be8e5c90c2c17f23092c0a8837df337cebdead83f0ddee9f18c3bd6",
        x"37270251d5a59dc9e05605918ab701f5bd7a71b11959fd174e28481ec44ef6a2",
        x"6bf0dde760447a1814bdbefc775f1f2a9b1e2b365bf613ac2ed4b1fdd289eeb2",
        x"9337e33010702f63e20f0c3c716ca8c63916d0befb127f6c4049957a3cd46ee8",
        x"338ea697010d9a11a429bc0e251a7c4a42fb15fb3a865933b7af5ea466e80721",
        x"e3c08f9e74e19eff184911eadfff9fdbb8ea871ec9fbc70bff6dcf37ff5777b3",
        x"78497599745687885b63c489f0a9ded6b31137d15e4538a90e1c8a1481d00c53",
        x"ba162237f4c523b95b934b4964ec2906bd75820b6711308f7df7fdb51ad09372",
        x"9637f4b6c63fbdfcb3712f9f784f2e033f429494cb2a78e29c1b62e88c12bb04",
        x"d1bbfbb89045d883e42fe650f698f622219d570f260e8d2880c1597e226448ce",
        x"7e118f94a37ab7cdafd637c61d4eb6c9ade81cdbcd31d1d68d25e2118b712853"
    ];

     (
        height, tx_id, proof, tx_index
    )
}

#[test]
fun test_verify_tx() {
    let sender = @0x01;
    let mut scenario = test_scenario::begin(sender);
    let lc = new_lc_for_test(scenario.ctx());

    let (height, tx_id, proof, tx_index) = sample_data();
    let res = lc.verify_tx(height, tx_id, proof, tx_index);
    assert!(res == true);

    let (height, tx_id, proof, _) = sample_data();
    let tx_index = 100;
    let res = lc.verify_tx(height, tx_id, proof, tx_index);
    assert!(res == false);

    let (height, _, proof, tx_index) = sample_data();
    let tx_id = x"010203";
    let res = lc.verify_tx(height, tx_id, proof, tx_index);
    assert!(res == false);


    let (height, tx_id, _, tx_index) = sample_data();
    let proof = vector[];
    let res = lc.verify_tx(height, tx_id, proof, tx_index);
    assert!(res == false);

    sui::test_utils::destroy(lc);
    scenario.end();
}
