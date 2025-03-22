module bitcoin_spv::light_client;

use bitcoin_spv::block_header::{BlockHeader, new_block_header};
use bitcoin_spv::light_block::{LightBlock, new_light_block};
use bitcoin_spv::merkle_tree::verify_merkle_proof;
use bitcoin_spv::btc_math::target_to_bits;
use bitcoin_spv::utils::nth_element;
use bitcoin_spv::transaction::make_transaction;
use bitcoin_spv::params::{Params, Self};


use sui::dynamic_field as df;
use sui::event;

/// === Errors ===
#[error]
const EBlockHashNotMatch: vector<u8> = b"The provided block hash does not match the expected hash";
#[error]
const EDifficultyNotMatch: vector<u8> = b"The difficulty bits in the header do not match the calculated difficulty";
#[error]
const ETimeTooOld: vector<u8> = b"The timestamp of the block is older than the median of the last 11 blocks";
#[error]
const EHeaderListIsEmpty: vector<u8> = b"The provided list of headers is empty";
#[error]
const EBlockNotFound: vector<u8> = b"The specified block could not be found in the light client";
#[error]
const EForkChainWorkTooSmall: vector<u8> = b"The proposed fork has less work than the current chain";
#[error]
const ETxNotInBlock: vector<u8> = b"The transaction is not included in the block according to the Merkle proof";
#[error]
const EInvalidStartHeight: vector<u8> = b"The start height must be a multiple of the retarget period (e.g 2016 for mainnet)";

public struct NewLightClientEvent has copy, drop {
    light_client_id: ID
}

public struct InsertedHeadersEvent has copy, drop {
    chain_work: u256,
    is_forked: bool,
    head_hash: vector<u8>,
    head_height: u64,
}

public struct ForkBeyondFinality has copy, drop {
    parent_hash: vector<u8>,
    parent_height: u64,
}



public struct LightClient has key, store {
    id: UID,
    params: Params,
    head_height: u64,
    head_hash: vector<u8>,
    finality: u64,
}


// === Init function for module ====

fun init(_ctx: &mut TxContext) {
    // LC creation is permissionless and it's done through new new_btc_light_client.
}

/// internal funciton to create a light client
public(package) fun new_light_client_with_params_int(params: Params, start_height: u64, trusted_headers: vector<vector<u8>>, start_chain_work: u256, finality: u64, ctx: &mut TxContext): LightClient {
    if (params.blocks_pre_retarget() != 0 && start_height % params.blocks_pre_retarget() != 0) {
        abort EInvalidStartHeight
    };

    let mut lc = LightClient {
        id: object::new(ctx),
        params: params,
        head_height: 0,
        head_hash: vector[],
        finality,
    };

    let mut current_chain_work = start_chain_work;
    if (!trusted_headers.is_empty()) {
        let mut height = start_height;
        let mut head_hash = vector[];
        trusted_headers.do!(|raw_header| {
            let header = new_block_header(raw_header);
            head_hash = header.block_hash();
            let light_block = new_light_block(height, header, current_chain_work);
            lc.set_block_hash_by_height(height, head_hash);
            lc.insert_light_block(light_block);
            height = height + 1;
            current_chain_work = current_chain_work + header.calc_work();
        });

        lc.head_height = height - 1;
        lc.head_hash = head_hash;
    };

    lc
}


/// Initializes Bitcoin light client by providing a trusted snapshot height and header
/// params: Mainnet, Testnet or Regtest
/// start_height: the height of first trust block
/// trusted_header: The list of trusted header in hex encode.
/// strart_chain_work: the chain_work at first trusted block.
///
/// Encode header reference:
/// https://developer.bitcoin.org/reference/block_chain.html#block-headers
public fun new_light_client_with_params(params: Params, start_height: u64, trusted_headers: vector<vector<u8>>, start_chain_work: u256, ctx: &mut TxContext) {
    let lc = new_light_client_with_params_int(
            params,
            start_height,
            trusted_headers,
            start_chain_work, 
            8, 
            ctx
        );
    event::emit(NewLightClientEvent {
        light_client_id: object::id(&lc)
    });
    transfer::share_object(lc);
}

/// Helper function to initialize new light client.
/// network: 0 = mainnet, 1 = testnet
public fun new_light_client(
    network: u8, start_height: u64, start_headers: vector<vector<u8>>, start_chain_work: u256, ctx: &mut TxContext
)  {
    let params = match (network) {
        0 => params::mainnet(),
        1 => params::testnet(),
        _ => params::regtest()
    };
    new_light_client_with_params(params, start_height, start_headers, start_chain_work, ctx);
}



/*
 * Entry methods
 */


public entry fun insert_headers(lc: &mut LightClient, raw_headers: vector<vector<u8>>) {
    // TODO: check if we can use BlockHeader instead of raw_header or vector<u8>(bytes)
    assert!(!raw_headers.is_empty(), EHeaderListIsEmpty);

    let first_header = new_block_header(raw_headers[0]);
    let head = lc.head();

    let mut is_forked = false;
    if (first_header.parent() == head.header().block_hash()) {
        // extend current fork
        lc.extend_chain(first_header.parent(), raw_headers);
    } else {
        // handle a fork choice
        let parent_id = first_header.parent();
        assert!(lc.exist(parent_id), EBlockNotFound);
        let parent = lc.get_light_block_by_hash(parent_id);
        // NOTE: we can check here if the diff between current head and the parent of
        // the proposed blockcheck is not bigger than the required finality.
        // We decide to not to do it to protect from deadlock:
        // * pro: we protect against double mint for nBTC etc...
        // * cons: we can have a deadlock
        if (lc.head_height - parent.height() > lc.finality) {
            event::emit(ForkBeyondFinality{
                parent_hash: parent_id,
                parent_height: parent.height(),
            });
        };

        let current_chain_work = head.chain_work();
        let current_block_hash = head.header().block_hash();

        let candidate_fork_head_hash = lc.extend_chain(first_header.parent(), raw_headers);
        let candidate_head = lc.get_light_block_by_hash(candidate_fork_head_hash);
        let candidate_chain_work = candidate_head.chain_work();

        assert!(current_chain_work < candidate_chain_work, EForkChainWorkTooSmall);
        // If transaction not abort. This is the current chain is less power than
        // the fork. We will update the fork to main chain and remove the old fork
        // notes: current_block_hash is hash of the old fork/chain in this case.
        // TODO(vu): Make it more simple.
        lc.rollback(first_header.parent(), current_block_hash);
        is_forked = true;
    };

    let b = lc.head();
    event::emit(InsertedHeadersEvent{
        chain_work: b.chain_work(),
        is_forked,
        head_hash: lc.head_hash,
        head_height: lc.head_height,
    });
}


public(package) fun insert_light_block(lc: &mut LightClient, lb: LightBlock) {
    let block_hash = lb.header().block_hash();
    df::add(&mut lc.id, block_hash, lb);
}

public(package) fun remove_light_block(lc: &mut LightClient, block_hash: vector<u8>) {
    df::remove<_, LightBlock>(&mut lc.id, block_hash);
}

public(package) fun set_block_hash_by_height(lc: &mut LightClient, height: u64, block_hash: vector<u8>) {
    let id = &mut lc.id;
    df::remove_if_exists<u64, vector<u8>>(id, height);
    df::add(id, height, block_hash);
}

/// Appends light block to the current branch and overwrites the current blockchain head.
/// Must only be called when we know that we extend the current branch or if we control
/// the rollback.
public(package) fun append_block(lc: &mut LightClient, light_block: LightBlock) {
    let head_hash = light_block.header().block_hash();
    lc.insert_light_block(light_block);
    lc.set_block_hash_by_height(light_block.height(), head_hash);
    lc.head_height = light_block.height();
    lc.head_hash = head_hash;
}

/// Insert new header to bitcoin spv
/// * `parent`: hash of the parent block, must be already recorded in the light client.
/// NOTE: this function doesn't do fork checks and overwrites the current fork. So it must be
/// only called internally.
public(package) fun insert_header(lc: &mut LightClient, parent_block_hash: vector<u8>, next_header: BlockHeader): vector<u8> {
    let parent_block = lc.get_light_block_by_hash(parent_block_hash);
    let parent_header = parent_block.header();

    // verify new header
    assert!(parent_header.block_hash() == next_header.parent(), EBlockHashNotMatch);
    let next_block_difficulty = calc_next_required_difficulty(lc, parent_block, next_header.timestamp());
    assert!(next_block_difficulty == next_header.bits(), EDifficultyNotMatch);


    // we only check the case "A timestamp greater than the median time of the last 11 blocks".
    // because  network adjusted time requires a miners local time.
    // https://learnmeabitcoin.com/technical/block/time
    let median_time = lc.calc_past_median_time(parent_block);
    assert!(next_header.timestamp() > median_time, ETimeTooOld);
    next_header.pow_check();

    // update new header
    let next_height = parent_block.height() + 1;
    let next_chain_work = parent_block.chain_work() + next_header.calc_work();
    let next_light_block = new_light_block(next_height, next_header, next_chain_work);

    lc.append_block(next_light_block);
    next_header.block_hash()
}

fun extend_chain(lc: &mut LightClient, parent_block_hash: vector<u8>, raw_headers: vector<vector<u8>>): vector<u8> {
    let mut previous_block_hash = parent_block_hash;
    raw_headers.do!(|raw_header| {
        let header = new_block_header(raw_header);
        previous_block_hash = lc.insert_header(previous_block_hash, header);
    });
    previous_block_hash
}


/// Delete all blocks between head_hash to checkpoint_hash
public(package) fun rollback(lc: &mut LightClient, checkpoint_hash: vector<u8>, head_hash: vector<u8>) {
    let mut block_hash = head_hash;
    while (checkpoint_hash != block_hash) {
        let previous_block_hash = lc.get_light_block_by_hash(block_hash).header().parent();
        lc.remove_light_block(block_hash);
        block_hash = previous_block_hash;
    }
}

/*
 * Views function
 */

/// Returns height of the blockchain head (latest, not confirmed block).
public fun head_height(lc: &LightClient): u64 {
    lc.head_height
}

/// Returns height of the blockchain head (latest, not confirmed block).
public fun head_hash(lc: &LightClient): vector<u8> {
    lc.head_hash
}

/// Returns blockchain head light block (latest, not confirmed block).
public fun head(lc: &LightClient): &LightBlock {
    lc.get_light_block_by_hash(lc.head_hash)
}

/// Returns latest finalized_block height
public fun finalized_height(lc: &LightClient): u64 {
    lc.head_height - lc.finality
}

/// verify output transaction
/// * `height`: block heigh transacion belong
/// * `proof`: merkle tree proof, this is the vector of 32bytes
/// * `tx_index`: index of transaction in block
/// * `version`: version of transaction - 4 bytes.
/// * `input_count`: number input in transaction
/// * `inputs`: inputs encoded in bytes.
/// * `output_count`: number output in transaction
/// * `outputs`: outputs encode in transaction
/// * `lock_time`: 4 bytes, lock time field in transaction
/// @return address and amount for each output
public fun verify_output(
    lc: &LightClient,
    height: u64,
    proof: vector<vector<u8>>,
    tx_index: u64,
    version: vector<u8>,
    input_count: u256,
    inputs: vector<u8>,
    output_count: u256,
    outputs: vector<u8>,
    lock_time: vector<u8>
): (vector<vector<u8>>, vector<u256>) {
    let tx = make_transaction(version, input_count, inputs, output_count, outputs, lock_time);
    assert!(lc.verify_tx(height, tx.tx_id(), proof, tx_index), ETxNotInBlock);

    let outputs = tx.outputs();
    let mut btc_addresses = vector[];
    let mut amounts = vector[];
    let mut i = 0;
    while (i < outputs.length()) {
        btc_addresses.push_back(outputs[i].p2pkh_address());
        amounts.push_back(outputs[i].amount());
        i = i + 1;
    };

    (btc_addresses, amounts)
}


/// Verify a transaction has tx_id(32 bytes) inclusive in the block has height h.
/// proof is merkle proof for tx_id. This is a sha256(32 bytes) vector.
/// tx_index is index of transaction in block.
/// We use little endian encoding for all data.
public fun verify_tx(
    lc: &LightClient,
    height: u64,
    tx_id: vector<u8>,
    proof: vector<vector<u8>>,
    tx_index: u64
): bool {
    // TODO: update this when we have APIs for finalized block.
    // TODO: handle: light block/block_header not exist.
    let block_hash = lc.get_block_hash_by_height(height);
    let header = lc.get_light_block_by_hash(block_hash).header();
    let merkle_root = header.merkle_root();
    verify_merkle_proof(merkle_root, proof, tx_id, tx_index)
}

public fun params(lc: &LightClient): &Params{
    &lc.params
}

public fun client_id(lc: &LightClient): &UID {
    &lc.id
}

public fun relative_ancestor(lc: &LightClient, lb: &LightBlock, distance: u64): &LightBlock {
    let ancestor_height = lb.height() - distance;
    let ancestor_block_hash = lc.get_block_hash_by_height(ancestor_height);
    lc.get_light_block_by_hash(ancestor_block_hash)
}

/// The function calculates the required difficulty for a block that we want to add after
/// (potentially fork) after the parent_block.
public fun calc_next_required_difficulty(lc: &LightClient, parent_block: &LightBlock, new_block_time: u32) : u32 {
    // reference from https://github.com/btcsuite/btcd/blob/master/blockchain/difficulty.go#L136
    let params = lc.params();
    let blocks_pre_retarget = params.blocks_pre_retarget();

    if (params.pow_no_retargeting() || parent_block.height() == 0) {
        return params.power_limit_bits()
    };

    // if this block does not start a new retarget cycle
    if ((parent_block.height() + 1) % blocks_pre_retarget != 0) {
        if (params.reduce_min_difficulty()) {
            let reduction_time = params.min_diff_reduction_time();
            let allow_min_time = parent_block.header().timestamp() + reduction_time;
            if (new_block_time > allow_min_time) {
                return params.power_limit_bits()
            };

            return find_prev_testnet_difficulty(lc, parent_block)
        };

        // Return previous block difficulty
        return parent_block.header().bits()
    };

    // we compute a new difficulty for the new target cycle.
    // this target applies at block  height + 1
    let first_block = lc.relative_ancestor(parent_block, blocks_pre_retarget - 1);
    let first_header = first_block.header();
    let previous_target = first_header.target();
    let first_timestamp = first_header.timestamp() as u64;
    let last_timestamp = parent_block.header().timestamp() as u64;

    let new_target = retarget_algorithm(params, previous_target, first_timestamp, last_timestamp);
    let new_bits = target_to_bits(new_target);
    new_bits
}

public(package) fun find_prev_testnet_difficulty(lc: &LightClient, start_node: &LightBlock): u32 {
    let mut iter_block = start_node;
    let blocks_pre_retarget = lc.params().blocks_pre_retarget();
    let power_limit_bits = lc.params().power_limit_bits();

    let mut height = iter_block.height();
    let mut bits = iter_block.header().bits();

    while (
        height != 0 &&
        height % blocks_pre_retarget != 0 &&
        bits == power_limit_bits
    ){
        iter_block = lc.relative_ancestor(iter_block, 1); // parent_block
        height = iter_block.height();
        bits = iter_block.header().bits();
    };

    if (height != 0) {
        return bits
    };

    power_limit_bits
}


fun calc_past_median_time(lc: &LightClient, lb: &LightBlock): u32 {
    // Follow implementation from btcsuite/btcd
    // https://github.com/btcsuite/btcd/blob/bc6396ddfd097f93e2eaf0d1346ab80735eaa169/blockchain/blockindex.go#L312
    // https://learnmeabitcoin.com/technical/block/time
    let median_time_blocks = 11;
    let mut timestamps = vector[];
    let mut i = 0;
    let mut prev_lb = lb;
    while (i < median_time_blocks) {
        timestamps.push_back(prev_lb.header().timestamp());
        if (!lc.exist(prev_lb.header().parent())) {
            break
        };
        prev_lb = lc.relative_ancestor(prev_lb, 1);
        i = i + 1;
    };

    let size = timestamps.length();
    nth_element(&mut timestamps, size / 2)
}


public fun get_light_block_by_hash(lc: &LightClient, block_hash: vector<u8>): &LightBlock {
    // TODO: Can we use option type?
    df::borrow(&lc.id, block_hash)
}

public fun exist(lc: &LightClient, block_hash: vector<u8>): bool {
    let exist = df::exists_(&lc.id, block_hash);
    exist
}

public fun get_block_hash_by_height(lc: &LightClient, height: u64): vector<u8> {
    // copy the block hash
    *df::borrow<u64, vector<u8>>(&lc.id, height)
}

public fun get_light_block_by_height(lc: &LightClient, height: u64): &LightBlock {
    let block_hash = lc.get_block_hash_by_height(height);
    lc.get_light_block_by_hash(block_hash)
}


/*
 * Helper function
 */

/// Compute new target
public fun retarget_algorithm(p: &Params, previous_target: u256, first_timestamp: u64, last_timestamp: u64): u256 {
    let mut adjusted_timespan = last_timestamp - first_timestamp;
    let target_timespan = p.target_timespan();

    // target adjustment is based on the time diff from the target_timestamp. We have max and min value:
    // https://github.com/bitcoin/bitcoin/blob/v28.1/src/pow.cpp#L55
    // https://github.com/btcsuite/btcd/blob/v0.24.2/blockchain/difficulty.go#L184
    let min_timespan = target_timespan / 4;
    let max_timespan = target_timespan * 4;
    if (adjusted_timespan > max_timespan) {
        adjusted_timespan = max_timespan;
    } else if (adjusted_timespan < min_timespan) {
        adjusted_timespan = min_timespan;
    };

    // A trick from summa-tx/bitcoin-spv :D.
    // NB: high targets e.g. ffff0020 can cause overflows here
    // so we divide it by 256**2, then multiply by 256**2 later.
    // we know the target is evenly divisible by 256**2, so this isn't an issue
    // notes: 256*2 = (1 << 16)
    let mut next_target = previous_target / (1 << 16) * (adjusted_timespan as u256);
    next_target = next_target / (target_timespan as u256) * (1 << 16);

    if (next_target > p.power_limit()) {
        next_target = p.power_limit();
    };

    next_target
}
