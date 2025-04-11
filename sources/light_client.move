// SPDX-License-Identifier: MPL-2.0

module bitcoin_spv::light_client;

use bitcoin_spv::block_header::{BlockHeader, new_block_header};
use bitcoin_spv::light_block::{LightBlock, new_light_block};
use bitcoin_spv::merkle_tree::verify_merkle_proof;
use bitcoin_spv::btc_math::target_to_bits;
use bitcoin_spv::utils::nth_element;
use bitcoin_spv::transaction::{make_transaction, Transaction};
use bitcoin_spv::params::{Params, Self, is_correct_init_height};


use sui::dynamic_field as df;
use sui::event;

/// === Errors ===
#[error]
const EWrongParentBlock: vector<u8> = b"New parent of the new header parent doesn't match the expected parent block hash";
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
const ETxNotInBlock: vector<u8> = b"The transaction is not included in a finalized block according to the Merkle proof";
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

/// LightClient constructor. Use `init_light_client` to create and transfer object,
/// emitting an event.
/// *params: Btc network params. Check the params module
/// *start_height: height of the first trusted header 
/// *trusted_headers: List of trusted headers in hex format.
/// *parent_chain_work: chain_work at parent block of start_height block.
/// *finality: the finality threshold

/// Header serialization reference:
/// https://developer.bitcoin.org/reference/block_chain.html#block-headers
public fun new_light_client(params: Params, start_height: u64, trusted_headers: vector<vector<u8>>, parent_chain_work: u256, finality: u64, ctx: &mut TxContext): LightClient {
    let mut lc = LightClient {
        id: object::new(ctx),
        params: params,
        head_height: 0,
        head_hash: vector[],
        finality,
    };

    let mut parent_chain_work = parent_chain_work;
    if (!trusted_headers.is_empty()) {
        let mut height = start_height;
        let mut head_hash = vector[];
        trusted_headers.do!(|raw_header| {
            let header = new_block_header(raw_header);
            head_hash = header.block_hash();
            let current_chain_work = parent_chain_work + header.calc_work();
            let light_block = new_light_block(height, header, current_chain_work);
            lc.set_block_hash_by_height(height, head_hash);
            lc.insert_light_block(light_block);
            height = height + 1;
            parent_chain_work = current_chain_work;
        });

        lc.head_height = height - 1;
        lc.head_hash = head_hash;
    };

    lc
}


/// Initializes Bitcoin light client by providing a trusted snapshot height and header
/// params: Mainnet, Testnet or Regtest.
/// start_height: the height of first trust block
/// trusted_header: The list of trusted header in hex encode.
/// previous_chain_work: the chain_work at parent block of start_height block
///
/// Header serialization reference:
/// https://developer.bitcoin.org/reference/block_chain.html#block-headers
public fun init_light_client(params: Params, start_height: u64, trusted_headers: vector<vector<u8>>, parent_chain_work: u256, ctx: &mut TxContext) {
    assert!(params.is_correct_init_height(start_height), EInvalidStartHeight);
    let lc = new_light_client(
        params,
        start_height,
        trusted_headers,
        parent_chain_work,
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
public fun init_light_client_network(
    network: u8, start_height: u64, start_headers: vector<vector<u8>>, parent_chain_work: u256, ctx: &mut TxContext
)  {
    let params = match (network) {
        0 => params::mainnet(),
        1 => params::testnet(),
        _ => params::regtest()
    };
    init_light_client(params, start_height, start_headers, parent_chain_work, ctx);
}



/*
 * Entry methods
 */

/// Insert new headers to extend the LC chain. Fails if the included headers don't
/// create a heavier chain or fork.
/// Header serialization reference:
/// https://developer.bitcoin.org/reference/block_chain.html#block-headers
public entry fun insert_headers(lc: &mut LightClient, raw_headers: vector<vector<u8>>) {
    // TODO: check if we can use BlockHeader instead of raw_header or vector<u8>(bytes)
    assert!(!raw_headers.is_empty(), EHeaderListIsEmpty);

    let first_header = new_block_header(raw_headers[0]);
    let head = *lc.head();

    let mut is_forked = false;
    if (first_header.parent() == head.header().block_hash()) {
        // extend current chain
        lc.extend_chain(head, raw_headers);
    } else {
        // handle a new fork
        let parent_id = first_header.parent();
        assert!(lc.exist(parent_id), EBlockNotFound);
        let parent = lc.get_light_block_by_hash(parent_id);
        // NOTE: we can check here if the diff between current head and the parent of
        // the proposed blockcheck is not bigger than the required finality.
        // We decide to not to do it to protect from deadlock:
        // * pro: we protect against double mint for nBTC etc...
        // * cons: we can have a deadlock
        if (parent.height() >= lc.finalized_height()) {
            event::emit(ForkBeyondFinality{
                parent_hash: parent_id,
                parent_height: parent.height(),
            });
        };

        let current_chain_work = head.chain_work();
        let current_block_hash = head.header().block_hash();

        let fork_head = lc.extend_chain(*parent, raw_headers);
        let fork_chain_work = fork_head.chain_work();

        assert!(current_chain_work < fork_chain_work, EForkChainWorkTooSmall);
        // If transaction not abort. This is the current chain is less power than
        // the fork. We will update the fork to main chain and remove the old fork
        // notes: current_block_hash is hash of the old fork/chain in this case.
        // TODO(vu): Make it more simple.
        lc.cleanup(parent_id, current_block_hash);
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
/// the cleanup.
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
public(package) fun insert_header(lc: &mut LightClient, parent: &LightBlock, header: BlockHeader): LightBlock {
    let parent_header = parent.header();

    // verify new header
    // NOTE: we must provide `parent` to the function, to assure we have a chain - subsequent
    // headers must be connected.
    assert!(parent_header.block_hash() == header.parent(), EWrongParentBlock);
    // NOTE: see comment in the skip_difficulty_check function
    if (!lc.params().skip_difficulty_check()) {
        let next_block_difficulty = lc.calc_next_required_difficulty(parent);
        assert!(next_block_difficulty == header.bits(), EDifficultyNotMatch);
    };

    // we only check the case "A timestamp greater than the median time of the last 11 blocks".
    // because  network adjusted time requires a miners local time.
    // https://learnmeabitcoin.com/technical/block/time
    let median_time = lc.calc_past_median_time(parent);
    assert!(header.timestamp() > median_time, ETimeTooOld);
    header.pow_check();

    // update new header
    let next_height = parent.height() + 1;
    let next_chain_work = parent.chain_work() + header.calc_work();
    let next_light_block = new_light_block(next_height, header, next_chain_work);

    lc.append_block(next_light_block);
    next_light_block
}


// TODO: check if we can use reference for parent
/// Extends chain from the given `parent` by inserting new block headers.
/// Returns ID of the last inserted block header.
/// NOTE: we need to pass `parent` block to assure we are creating a chain. Consider the
/// following scenario, where headers that we insert don't form a chain:
///
///    A = {parent: Z}
///    Chain = X-Y-Z  // existing chain
///    headers = [A, A, A]
///
/// the insert would try to insert A multiple times:
///
///    X-Y-Z-A
///        |-A
///        |-A
///
fun extend_chain(lc: &mut LightClient, parent: LightBlock, raw_headers: vector<vector<u8>>): LightBlock {
    raw_headers.fold!(parent, |p, raw_header| {
        let header = new_block_header(raw_header);
        lc.insert_header(&p, header)
    } )
}

/// Delete all blocks between head_hash to checkpoint_hash
public(package) fun cleanup(lc: &mut LightClient, checkpoint_hash: vector<u8>, head_hash: vector<u8>) {
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
/// * `input_count`: number of input objects
/// * `inputs`: all tx inputs encoded as a single list of bytes.
/// * `output_count`: number of output objects
/// * `outputs`: all tx outputs encoded as a single list of bytes.
/// * `lock_time`: 4 bytes, lock time field in transaction
/// @return address and amount for each output
public fun verify_output(
    lc: &LightClient,
    height: u64,
    proof: vector<vector<u8>>,
    tx_index: u64,
    version: vector<u8>,
    input_count: u32,
    inputs: vector<u8>,
    output_count: u32,
    outputs: vector<u8>,
    lock_time: vector<u8>
): (vector<vector<u8>>, vector<u64>) {
    let tx = make_transaction(version, input_count, inputs, output_count, outputs, lock_time);
    assert!(lc.verify_tx(height, tx.tx_id(), proof, tx_index), ETxNotInBlock);

    let outputs = tx.outputs();
    let mut btc_addresses = vector[];
    let mut amounts = vector[];
    let mut i = 0;
    while (i < outputs.length()) {
        btc_addresses.push_back(outputs[i].extract_public_key_hash());
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
    // TODO: handle: light block/block_header not exist.
    if (height > lc.finalized_height()) {
        return false
    };
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
/// the `parent_block` (potentially fork).
public fun calc_next_required_difficulty(lc: &LightClient, parent_block: &LightBlock) : u32 {
    // reference from https://github.com/btcsuite/btcd/blob/master/blockchain/difficulty.go#L136
    let params = lc.params();
    let blocks_pre_retarget = params.blocks_pre_retarget();

    if (params.pow_no_retargeting() || parent_block.height() == 0) {
        return params.power_limit_bits()
    };

    // if this block does not start a new retarget cycle
    if ((parent_block.height() + 1) % blocks_pre_retarget != 0) {
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


/// Verifies the transaction and parses outputs to calculates the payment to the receiver.
/// To if you only want to verify if the tx is included in the block, you can use
/// `verify_tx` function.
/// Returns the the total amount of satoshi send to `receiver_address` from transaction outputs,
/// the content of the `OP_RETURN` opcode output, and tx_id (hash).
/// If OP_RETURN is not included in the transaction, return an empty vector.
/// NOTE: output with OP_RETURN is invalid, and only one such output can be included in a TX.
/// * `height`: block height the transaction belongs to.
/// * `proof`: merkle tree proof, this is the vector of 32bytes.
/// * `tx_index`: index of transaction in block.
/// * `transaction`: bitcoin transaction. Check transaction.move.
/// * `receiver_pk_hash`: receiver public key hash in p2pkh or p2wpkh. Must not empty
public fun verify_payment(
    lc: &LightClient,
    height: u64,
    proof: vector<vector<u8>>,
    tx_index: u64,
    transaction: &Transaction,
    receiver_pk_hash: vector<u8>
) : (u64, vector<u8>, vector<u8>) {
    let mut amount = 0;
    let mut op_return_msg = vector[];
    let tx_id = transaction.tx_id();
    assert!(lc.verify_tx(height, tx_id, proof, tx_index), ETxNotInBlock);
    let outputs = transaction.outputs();

    let mut i = 0;
    while (i < outputs.length()) {
        let o = outputs[i];
        if (o.extract_public_key_hash() == receiver_pk_hash) {
            amount = amount + o.amount();
        };

        if (o.is_op_return()) {
            op_return_msg = o.op_return();
        };

        i = i + 1;
    };

    (amount, op_return_msg, tx_id)
}
