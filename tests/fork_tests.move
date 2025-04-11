// SPDX-License-Identifier: MPL-2.0

#[test_only]
module bitcoin_spv::handle_fork_tests;

use bitcoin_spv::params;
use bitcoin_spv::block_header::{new_block_header, BlockHeader};
use bitcoin_spv::light_client::{LightClient, new_light_client, EForkChainWorkTooSmall, EBlockNotFound};
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
        // {
        //     "version": "00000030",
        //     "previous_block_hash": "7306011c31d1f14a422c50c70cbedb1233757505cb887d82d51ae3f27e23062d",
        //     "merkle_root": "6be46c161e69696c1c83ba3a1ea52f071fcdada5a6bce28f5da591b969b42da1",
        //     "timestamp": "39c5b167",
        //     "difficulty_target": "ffff7f20",
        //     "nonce": "00000000"
        // }
        // fork starts here.
        x"000000307306011c31d1f14a422c50c70cbedb1233757505cb887d82d51ae3f27e23062d6be46c161e69696c1c83ba3a1ea52f071fcdada5a6bce28f5da591b969b42da139c5b167ffff7f2000000000",
        x"00000030e98bb046cd25a629c91f0c7623cc2ed0c12ef6db5e41956536c261eb673d0b0f813b60988eadd1961289bf5f2098f6ca0c7dd35ae95e78807c6582a46e00107f39c5b167ffff7f2004000000",
        x"000000304f58550f49b5c9dce6328bc8d7b8f5941823efcc51741a024c17d9745ba21111cb2db51b4bf0858c2318820adafa1c8640703dca1faceea0205f388f160d452539c5b167ffff7f2004000000",
        x"00000030aa8bd6ce82edf1f9c03abc2243281f622594bc3aec5106a17f612371f76060084e05aaf29bda3424553cb4636006d006030690b91875fe96fdb4c52d4a38ba8a39c5b167ffff7f2003000000",
        x"0000003040ce8b407650044a4294fd43c6d78cbb4f78ac98527f858f3950dad92fc5982ddebd5d70e4be4f6f5cc474416137a697f1fca22bf87e9066eb9b43dd7882d23239c5b167ffff7f2002000000"
    ];

    let lc = new_light_client(params::regtest(), 0, headers, 0, 8, ctx);

    let block_headers = headers.map!(|h| new_block_header(h));
    (lc, block_headers)
}


#[test]
fun insert_headers_switch_fork_tests() {
    let headers = vector[
        //         {
        //     "version": "00000030",
        //     "previous_block_hash": "7306011c31d1f14a422c50c70cbedb1233757505cb887d82d51ae3f27e23062d",
        //     "merkle_root": "6be46c161e69696c1c83ba3a1ea52f071fcdada5a6bce28f5da591b969b42da1",
        //     "timestamp": "9dc5b167",
        //     "difficulty_target": "ffff7f20",
        //     "nonce": "01000000"
        // }
        // fork starts at block with `previous_block_hash` = 7306011c31d1f14a422c50c70cbedb1233757505cb887d82d51ae3f27e23062d. Check data in new_lc_for_test
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
    let mut insert_point = lc.get_light_block_by_hash(first_header.parent()).height() + 1;

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

    assert!(lc.head().height() == insert_point - 1);
    assert!(lc.head().header() == last_header);
    sui::test_utils::destroy(lc);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = EForkChainWorkTooSmall)]
fun insert_headers_fork_not_enought_power_tests() {
    let headers = vector[
        // fork starts here
        // but not enough chain power
        // {
        //     "version": "00000030",
        //     "previous_block_hash": "7306011c31d1f14a422c50c70cbedb1233757505cb887d82d51ae3f27e23062d",
        //     "merkle_root": "6be46c161e69696c1c83ba3a1ea52f071fcdada5a6bce28f5da591b969b42da1",
        //     "timestamp": "9dc5b167",
        //     "difficulty_target": "ffff7f20",
        //     "nonce": "01000000"
        // }
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
fun cleanup_tests() {
    let sender = @0x01;
    let mut scenario = test_scenario::begin(sender);
    let ctx = scenario.ctx();
    let (mut lc, headers) =  new_lc_for_test(ctx);

    let checkpoint = headers[5].block_hash();
    let head_hash = lc.head_hash();
    lc.cleanup(checkpoint, head_hash);

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

#[test]
fun test_reorg() {
    let sender = @0x01;
    let mut scenario = test_scenario::begin(sender);
    let ctx = scenario.ctx();

    // init chain in in light client
    let headers = vector[
        x"04000000605e6a4291a997994d314801de6ab2aae67bfcb343bc5884678e4001b47e2303201c882d9de99c0137ee538d34f7c473e6a9b5a37901330250a2c62a4b171393fd088653ffff7f20f2ffffef",
        x"04000000762f7efa4640465c8a86f476f27f8f520bdc898776e9207471696e4135530928d0b4cd66abe660e66297ce81bb6d2b192589937400a0b5cd471782668d0574db0c0a8653ffff7f20f3ffffef",
        x"04000000aa56f7acf2d7b0514131d1207f96964bb51e098b8e94a3acccd009dce55cb9739439d226539ec843c85c052bff9a60f4406bd45505d386e6dbfb634a3c8b9aef050b8653ffff7f2001000000",
        x"040000007f8afe86438bacdf44e7d43775a149ae00258e425cae8444a8d0139edf74b70123ef08e6863d7dac586ff2ce6917ef4fd148432aa7845ef0af113775083a211ba70c8653ffff7f20f2ffffef",
        x"0400000087f380f8ca6f3171df96bfafe7d50f619054f31924392d9adc50b520d7a9e55534a006a28d11bc751389ae146b1468ab485d1437edcfc3a8267040fb90226df4d80d8653ffff7f20feffff3f", // <- fork start here
        // {
        //     "version": "04000000",
        //     "previous_block_hash": "43f67f2fa04b9de8d29a29fab30e1468db5036f31243729a09c40fd2854f8b21",
        //     "merkle_root": "2daf618d14e76326f5ee702eacfd886a525c36cf2cbe756c93a5ce54196a6021",
        //     "timestamp": "8b108653",
        //     "difficulty_target": "ffff7f20",
        //     "nonce": "f3ffffef"
        // }
        x"0400000043f67f2fa04b9de8d29a29fab30e1468db5036f31243729a09c40fd2854f8b212daf618d14e76326f5ee702eacfd886a525c36cf2cbe756c93a5ce54196a60218b108653ffff7f20f3ffffef",
        x"0400000089e74025c7ea5152e131bd1ae0b307bde5972e4451b431416ef194abafde6b3f9f8d7b24c42c0f5be70aa5f7f30130fcbaa50928721149c486261a0c8dffd5b22b138653ffff7f20f8ffff9f",
        x"040000000217ca583ab80b6eda0cc99e814b2aa9750497de8e98901f5cfc76235f4e7365db612186fbd125fd83a05d9ccd75a5abf6453cd60e69b5d6e623e782d8e390b66b148653ffff7f20f4ffffef",
        x"04000000cd61864c5790c7903f049f6f2247eb961f492c09a1c17ebec52a7e22a10a1d41f1d563bcbebd74d8bf517b1021ebaef7b9beb24c376fd6f1d695383b5fd4a86216178653ffff7f2002000000",
        x"0400000048e30418dc91e17527e7b169aba58331e5627a4a1b434295149442fcb779040030128d2428f272019fd5047fef2eb5e74f60c360bd6c26603df7e1bc8a54a08058188653ffff7f20f3ffffef",
    ];

    // bits at height 0 always equal power_limit_bits
    // so we start at height 1 for easy testing.
    // previous_power = 2, just follow the context in test
    let mut lc =  new_light_client(params::mainnet(), 1, headers, 2, 8, ctx);

    let forks = vector[
        // {
        //     "version": "04000000",
        //     "previous_block_hash": "43f67f2fa04b9de8d29a29fab30e1468db5036f31243729a09c40fd2854f8b21",
        //     "merkle_root": "0d1457f5e34637e00460b955f89537b152e95c2cfa91a16b0c48e00b3aa273dc",
        //     "timestamp": "a3108653",
        //     "difficulty_target": "ffff7f20",
        //     "nonce": "f2ffffef"
        // }
        x"0400000043f67f2fa04b9de8d29a29fab30e1468db5036f31243729a09c40fd2854f8b210d1457f5e34637e00460b955f89537b152e95c2cfa91a16b0c48e00b3aa273dca3108653ffff7f20f2ffffef",
        x"040000009124a72f8afc0db55c03fd243d7bb51db1e72fcbf93fded941470768b2ea903f974ba0cf28a6ab523b722fa102db6c43e68c266862b7ef5979b2b28bd0a389b06f138653ffff7f20f2ffffef",
        x"040000000a826811ccd882ecdc079b5ee6cd2bda4a4f04ab2fd0257ec6f650d9dfdf233e2d94e282552d4ce5c258a57009a2d48fa39eee8d3996036e53de7fe443b1a625f2158653ffff7f20f3ffffef",
        x"0400000063a5e76433bdc3aa405d3cf12cc6f33fbb70a625171adbcba5567bf7c257cd4f67a59729b4722101f3b4910ee751a8361ddc15efe9b9c7222d57f2f85f152c6c91178653ffff7f20f2ffffef",
        x"04000000febd659bef753ef8f7f5106d7f174338d02a17b189aa80fcb63bc11d92395278d5e29869677b514091b0a4e488d55cdfd622dad58d03230e8ae3b9fda8282594fd198653ffff7f20fdffff3f",
        x"04000000d21a6dc07deb7024af7cbb3f48f070a1bd8dbd662e616a79f6ec4de7ffbf4627ca9fa20b71b45c2a5e57b7d8700ea6a0039d6c95edc4b6a157d7c55669d25246071c8653ffff7f20ffffff1f",
        x"04000000935eedde7761ac153e42f7ecb907d11a1001261f1054e716f72e9aacb525853826ab076c5188def652adf57d5b9fb172fe1d06ffff97a89d12d70a94dc3e41fae51d8653ffff7f20fdffff3f",
        x"04000000884f51b3aa3d0238d67237e4b34b2ec314614c1b1d66b0d6e3e88854f182d345742255cf3c6612e5f48f9f52e12f4027ae80ac0aca190f18f2f5f12dda1778418e208653ffff7f2000000020",
        x"04000000d210ea0ef4e782a69f4d432b4b4c2ef14742b4ac809fa20b96e0954787a7627bf574fb5ae5e24c10757bca282491c71940a9decd05fb8ac3eef6ef55c849c80259238653ffff7f20feffff3f",
        x"040000008802bdc21ceae91f054de0cac3084b593c040d3b4b3deee7f59a9e1c1a4daa56467b33c8a2525e0b9c2478eb0f820126068ff069672228141721f7447582ff19a8248653ffff7f2000000010",
        x"04000000f730991db2e701b1fc513e040659ecba43e1853653b7b9116f520641a7501e0182d1752e28447ca227fa6a53ded4b02d2d631a8d002f4328a257802ae8151278e7258653ffff7f2001000030",
        x"040000001715f0348ab391ba994ede0f5f8d66b9f3d1c3b914e728b4ba0306bad0da3227348e4b5852b238fab986d3eb413a3d7e54740089213c30bbdfc885953f281ea834278653ffff7f20f2ffffef",
        x"0400000006e987c62f156bc326ae7afd84dfaa765b98d5ad27639a2ecf75b462e0b0e729a3fbd86074a06ee5ec47c94e5b77eb1849010c10a07c43b48058655d8e5c7f66d2288653ffff7f2001000020",
        x"040000008e3caa88f2e32ce528ec63255de09176cf081ec7e51f123d5775b4425539fb514aae597bc1bf9e17d1601471a70542e7ac52e09b5eaf85e8acb2f0e3bd6086d89a2b8653ffff7f2001000000",
        x"0400000061f68cf3904a77101fe0a41cfc605d40564bdf693712a8684fded6b01b7ecb5ca8f039285b833d6c93e42d714669e90de06c143d11fba13cd66e1f2735eb219b302e8653ffff7f20f2ffffef",
    ];

    // update light client with better chain.
    // the fork start at block 43f67f2fa04b9de8d29a29fab30e1468db5036f31243729a09c40fd2854f8b21
    // or headers[4]
    lc.insert_headers(forks);

    // validate new chain after update
    let head = lc.head();
    // new chain head should identical last header in `forks`.
    assert!(head.header().block_hash() == new_block_header(forks[forks.length() - 1]).block_hash());
    assert!(head.chain_work() == 42);

    sui::test_utils::destroy(lc);
    scenario.end();
}
