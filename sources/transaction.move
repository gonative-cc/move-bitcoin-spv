module bitcoin_spv::transaction;
use bitcoin_spv::btc_math::{btc_hash, compact_size};

public struct Input has copy, drop {
    input_bytes: vector<u8>,
}

public struct Output has copy, drop {
    output_bytes: vector<u8>
}

public struct Transaction has copy, drop {
    version: vector<u8>,
    marker: Option<u8>,
    flag: Option<u8>,
    inputs: vector<Input>,
    outputs: vector<Output>,
    tx_id: vector<u8>,
    witness: vector<u8>,
    look_time: vector<u8>
}


// TODO: better name for this.
// we don't create any new transaction
public fun new_transaction(
    version: vector<u8>,
    marker: Option<u8>,
    flag: Option<u8>,
    number_input: vector<u8>,
    inputs: vector<u8>,
    number_output: vector<u8>,
    outputs: vector<u8>,
    witness: Option<vector<u8>>,
    lock_time: vector<u8>,
) {

    let input_count = compact_size(number_input);
    let output_count = compact_size(number_output);

    // compute TxID
    let mut tx_data = x"";
    tx_data.append(version);
    tx_data.append(number_input);
    tx_data.append(inputs);
    tx_data.append(number_output);
    tx_data.append(outputs);
    tx_data.append(lock_time);
    let tx_id = btc_hash(tx_data);
}
