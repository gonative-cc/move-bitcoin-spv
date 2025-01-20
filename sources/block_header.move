module btclc::block_header;

use btclc::chainctx::Chain;
use btclc::btc_math::{bits_to_target, target_to_bits};
use sui::dynamic_object_field as dof;

public struct Header has key, store {
    id: UID,
    version: u32,
    prev_block: vector<u8>,
    merkle_root: vector<u8>,
    timestamp: u32,
    bits: u32,
    nonce: u32
}


public struct LightBlock has key, store {
    id: UID,
    height: u32,
    header: Header,
}


public fun relative_ancestor(lb: &LightBlock, distance: u32, c: &Chain): &LightBlock {
    let ancestor_height: u32 = lb.height - distance;
    
    let ancestor: &LightBlock = dof::borrow(c.id(), ancestor_height);
    return ancestor
}


public fun calc_next_block_difficulty(c: &Chain, last_block: &LightBlock, _new_block_time: u32) : u32 {

    // TODO: handle lastHeader is nil or genesis block

    let blocks_pre_retarget = c.params().blocks_pre_retarget();
    
    // if this block not start a new retarget cycle
    if ((last_block.height + 1) % blocks_pre_retarget != 0) {
	
	// TODO: support ReduceMinDifficulty params
	// if c.params().reduce_min_difficulty {
	//     ...
	//     new_block_time is using in this logic
	// }

	// Return previous block difficulty
	return last_block.header.bits
    };

    // we compute a new difficulty
    let first_block = last_block.relative_ancestor(blocks_pre_retarget - 1, c);

    let acctual_timespan = last_block.header.timestamp - first_block.header.timestamp;
    let mut adjusted_timespan: u64 = acctual_timespan as u64;
    
    if ((acctual_timespan as u64) < c.min_retarget_timespan()) {
	adjusted_timespan = c.min_retarget_timespan();
    } else if ((acctual_timespan as u64)> c.max_retarget_timespan()){
	adjusted_timespan = c.max_retarget_timespan();
    };

    let old_target = bits_to_target(first_block.header.bits);
    // TODO: ensure this one can't overflow
    let mut new_target = old_target * (adjusted_timespan as u256);
    // TODO: make this more sense.
    let second = 1000000000;
    let target_timespan = c.params().target_timespan() / second;
    new_target = new_target / (target_timespan as u256);
    
    if (new_target > c.params().power_limit()) {
	new_target = c.params().power_limit();
    };
    return target_to_bits(new_target)
}
