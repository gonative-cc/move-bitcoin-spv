#[test_only]
module bitcoin_spv::handle_fork_tests;
use bitcoin_spv::block_header::{new_block_header, BlockHeader};
use bitcoin_spv::light_client::{LightClient, new_light_client_with_params, regtest_params, EForkChainWorkTooSmall, EBlockNotFound};
use sui::test_scenario;

// Test for fork handle
// All data gen from https://github.com/gonative-cc/relayer/blob/master/contrib/create-fork.sh

#[test_only]
fun new_lc_for_test(ctx: &mut TxContext): (LightClient, vector<BlockHeader>) {
    let headers = vector[
        x"00000030759e91f85448e42780695a7c71a6e4f4e845ecd895b19fafaeb6f5e3c030e62233287429255f254a463d90b998ba5523634da7c67ef873268e1db40d1526d5583d5b6167ffff7f2000000000",
        x"0000003058deb19a44c75df6d732d4dc085df09dd053c9f0db5eee57cdbfbe09fe47237776bb7462ac45b258ea7c464a19c11fef595f3e5dfbef2fc31bc94d8aefc7223c3d5b6167ffff7f2000000000",
        x"00000030e89c7f970db47ef7253c982270200f7009eaa3ef698d4b06c1f55848b56f24744ba0355deefd42dbd10deced2fdcf6a0f950a4f02aacd1f9fbb7efde7566d2d53d5b6167ffff7f2000000000",
        x"00000030792fe6e81fc1eeea11ae6a88a67060c6e8e492eeff7439168611996864119b1cace3ddc3203b8686e44d2739c45697d47c8e83b8a0e83f036b6991bf3f64ee2c3d5b6167ffff7f2002000000",
        x"0000003043de7b00670f41c1e92368da064553088a75374d7aac4b0a1b645658febf9e1f02ce53a61def0d99c08db78ac3d98696306fd74ece04e2a58a61ffb73dda6d963e5b6167ffff7f2001000000",
        x"00000030c38dec9b487eec7702a9b208cc61046e313aedfeea24192933539244d341805e0ebfd749972b2d5952585b82276afddfb22fc487f23098b98055904034170c843e5b6167ffff7f2000000000",
        x"00000030292e580e3b694eabbbb18b30fa22863de2de6abb7dd156c611500c801b01d845e922b7b37db1fc5a11b02998192e75a6baf7904e5b22431cd94f3ee03e93f4323e5b6167ffff7f2000000000",
        x"0000003010b335151fec6cd0be3fff1322e8e7b6a84ffc09682e07da040157ec0cd9d33022636b8b8cf102f3e47c2af1fd8ddceec7b46216a618d4f1af813484c031d6b13e5b6167ffff7f2000000000",
        x"00000030828f08644e5e78c2d99bdbcd3d0d4ba5eb10f74909b113fd8a7fa4a45febb625da3bc639c7d2c0ed61ec76f6257d4a84fe7aebeeb6c69131290c647dbefc1cad3e5b6167ffff7f2001000000",
        x"00000030486697206d79c9f68c60c259e9ec913c117ac6da35f44bbc57d9e4362d1ea233ed34bda2c331cb007039d7d085b08977cf21b2aad1a50a788106302d25ff79f43e5b6167ffff7f2003000000",
        x"0000003085bbc10dc8694fe36144c87f7737c35f9e3e8e304c61427a7cbce8b1e97004153fb8582bc04a0abb67965f6c139445bdc5d173ddc80008aa219929ab7285278f3f5b6167ffff7f2000000000",
        x"00000030516567e505288fe41b2fc6be9b96318c406418c7d338168fe75a26111490eb2fec401c3902aa39842e53a0c641af518957ec3aa5984a44d32e2a9f7fee2fa67a3f5b6167ffff7f2004000000",
        x"000000307306011c31d1f14a422c50c70cbedb1233757505cb887d82d51ae3f27e23062d6be46c161e69696c1c83ba3a1ea52f071fcdada5a6bce28f5da591b969b42da139c5b167ffff7f2000000000",
        x"00000030e98bb046cd25a629c91f0c7623cc2ed0c12ef6db5e41956536c261eb673d0b0f813b60988eadd1961289bf5f2098f6ca0c7dd35ae95e78807c6582a46e00107f39c5b167ffff7f2004000000",
        x"000000304f58550f49b5c9dce6328bc8d7b8f5941823efcc51741a024c17d9745ba21111cb2db51b4bf0858c2318820adafa1c8640703dca1faceea0205f388f160d452539c5b167ffff7f2004000000",
        x"00000030aa8bd6ce82edf1f9c03abc2243281f622594bc3aec5106a17f612371f76060084e05aaf29bda3424553cb4636006d006030690b91875fe96fdb4c52d4a38ba8a39c5b167ffff7f2003000000",
        x"0000003040ce8b407650044a4294fd43c6d78cbb4f78ac98527f858f3950dad92fc5982ddebd5d70e4be4f6f5cc474416137a697f1fca22bf87e9066eb9b43dd7882d23239c5b167ffff7f2002000000"
    ];

    let params = regtest_params();
    let lc = new_light_client_with_params(params, 0, headers, 0, ctx);

    let block_headers = headers.map!(|h| new_block_header(h));
    (lc, block_headers)
}


#[test]
fun insert_headers_switch_fork_tests() {
     let headers = vector[
        x"000000307306011c31d1f14a422c50c70cbedb1233757505cb887d82d51ae3f27e23062d6be46c161e69696c1c83ba3a1ea52f071fcdada5a6bce28f5da591b969b42da19dc5b167ffff7f2001000000",
        x"000000302ba076eb907ec3c060954d36dfcf0e735c815c9531f6d44667aa32f5999f412d813b60988eadd1961289bf5f2098f6ca0c7dd35ae95e78807c6582a46e00107f9dc5b167ffff7f2001000000",
        x"00000030525bda2756ff6f9e440c91590490462ac33e0fedb05b1558cfd3f7ce90920d16cb2db51b4bf0858c2318820adafa1c8640703dca1faceea0205f388f160d45259dc5b167ffff7f2002000000",
        x"000000306052592f4f0e4886a0eca2c1d154e8b9761e011b4f7b3a00908e2a830f7f6c6a4e05aaf29bda3424553cb4636006d006030690b91875fe96fdb4c52d4a38ba8a9dc5b167ffff7f2001000000",
        x"000000309c32ae8f3b099ea17563bb425476cf962b84269e09d17e19350b819695970f2cdebd5d70e4be4f6f5cc474416137a697f1fca22bf87e9066eb9b43dd7882d2329dc5b167ffff7f2001000000",
        x"000000307370f207ef4945a89b10b1c60a14770136109de093df4544340251190a5c2436494bba4bf2f3dc3a1d8c1bb592eeadc16c77b6bdd42c6ad2003a704641c3caeb9dc5b167ffff7f2000000000"
    ];
    let sender = @0x01;
    let mut scenario = test_scenario::begin(sender);
    let ctx = scenario.ctx();

    let (mut lc, _) = new_lc_for_test(ctx);

    let first_header = new_block_header(headers[0]);
    let last_header = new_block_header(headers[headers.length() - 1]);
    let mut insert_point = lc.get_light_block_by_hash(first_header.prev_block()).height() + 1;

    lc.insert_headers(headers);

    // assert insert new block correct
    headers.do!(|h| {
        let inserted_block_hash = lc.get_block_hash_by_height(insert_point);
        let inserted_block = lc.get_light_block_by_hash(inserted_block_hash);
        assert!(inserted_block_hash == new_block_header(h).block_hash());
        assert!(inserted_block.height() == insert_point);
        assert!(inserted_block.header().block_hash() == inserted_block_hash);
        insert_point = insert_point + 1;
    });

    assert!(lc.latest_block().height() == insert_point - 1);
    assert!(lc.latest_block().header() == last_header);
    sui::test_utils::destroy(lc);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = EForkChainWorkTooSmall)]
fun insert_headers_fork_not_enought_power_tests() {
    let headers = vector[
        x"000000307306011c31d1f14a422c50c70cbedb1233757505cb887d82d51ae3f27e23062d6be46c161e69696c1c83ba3a1ea52f071fcdada5a6bce28f5da591b969b42da19dc5b167ffff7f2001000000",
        x"000000302ba076eb907ec3c060954d36dfcf0e735c815c9531f6d44667aa32f5999f412d813b60988eadd1961289bf5f2098f6ca0c7dd35ae95e78807c6582a46e00107f9dc5b167ffff7f2001000000",
        x"00000030525bda2756ff6f9e440c91590490462ac33e0fedb05b1558cfd3f7ce90920d16cb2db51b4bf0858c2318820adafa1c8640703dca1faceea0205f388f160d45259dc5b167ffff7f2002000000",
        x"000000306052592f4f0e4886a0eca2c1d154e8b9761e011b4f7b3a00908e2a830f7f6c6a4e05aaf29bda3424553cb4636006d006030690b91875fe96fdb4c52d4a38ba8a9dc5b167ffff7f2001000000",
        x"000000309c32ae8f3b099ea17563bb425476cf962b84269e09d17e19350b819695970f2cdebd5d70e4be4f6f5cc474416137a697f1fca22bf87e9066eb9b43dd7882d2329dc5b167ffff7f2001000000",
    ];
    let sender = @0x01;
    let mut scenario = test_scenario::begin(sender);
    let ctx = scenario.ctx();
    let (mut lc, _) = new_lc_for_test(ctx);
    lc.insert_headers(headers);
    sui::test_utils::destroy(lc);
    scenario.end();
}


#[test]
#[expected_failure(abort_code = EBlockNotFound)]
fun insert_headers_block_doesnot_exist() {

    // we modifed the previous hash
    // previous hash = db0338a432b1242c3bd22c245583e31788feaa6cb189673877b92f2a34eaf460 = sha256("This is null")
    let headers = vector[
        x"00000030db0338a432b1242c3bd22c245583e31788feaa6cb189673877b92f2a34eaf4606be46c161e69696c1c83ba3a1ea52f071fcdada5a6bce28f5da591b969b42da19dc5b167ffff7f2001000000",
    ];
    let sender = @0x01;
    let mut scenario = test_scenario::begin(sender);
    let ctx = scenario.ctx();
    let (mut lc, _) = new_lc_for_test(ctx);
    lc.insert_headers(headers);
    sui::test_utils::destroy(lc);
    scenario.end();
}

#[test]
fun rollback_tests() {
    let sender = @0x01;
    let mut scenario = test_scenario::begin(sender);
    let ctx = scenario.ctx();
    let (mut lc, headers) =  new_lc_for_test(ctx);

    let checkpoint = headers[5].block_hash();
    let latest_block = lc.latest_block().header().block_hash();

    lc.rollback(checkpoint, latest_block);

    let height = lc.get_light_block_by_hash(checkpoint).height();
    let mut i = 0u64;

    while (i < headers.length()) {
        if (i <= height) {
            assert!(lc.exist(headers[i].block_hash()));
        } else {
            assert!(!lc.exist(headers[i].block_hash()));
        };
        i = i + 1;
    };

    sui::test_utils::destroy(lc);
    scenario.end();
}
