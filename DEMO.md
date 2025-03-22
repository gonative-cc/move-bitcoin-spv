# Demo description

## Prepare environment

### Install Sui

Follow [Sui installation](https://docs.sui.io/guides/developer/getting-started/sui-install) instructions.

### Setup sui client

```sh
sui client new-env --alias=devnet --rpc https://fullnode.devnet.sui.io:443
```

Show active address:

```sh
sui client active-address

### claim tokens from the faucet to the active account.
sui client faucet --url https://faucet.devnet.sui.io/v1/gas
```

## Bitcoin SPV main function demo

### Deploy Bitcoin SPV packages

```sh
cd <path/to/bitcoin_spv>
sui client publish --skip-dependency-verification  --gas-budget 100000000
```

For this demo, we initialize the light client with a trusted snapshot at block height 201600.

Check the output from the command above, and save the package ID and the deployed module ID (LC_ID):

```fish
set PACKAGE_ID 0x...
set LC_ID 0x...

# check the deployed module:
sui client object $LC_ID
```

### Create light client

Create a new light client by doing the function call:

```sh
sui client call --function new_light_client --module light_client --package $PACKAGE_ID --gas-budget 100000000 --args $BTC_NETWORK 0 $INIT_HEADERS 0
```

`BTC_NETWORK` is 0 for mainnet, 1 for testnet and regtest otherwise.

### Insert a new header

Now we can insert and prove a new light block (height=20161): (<https://learnmeabitcoin.com/explorer/block/00000000000003c52ff2c90f4e318b7d987c9a6a23c809d0f945d50689411cca>)

```sh
sui client call --function insert_headers --module light_client --package $PACKAGE_ID --gas-budget 10000000 --args $LC_ID '[0x01000000d09acdf9c9959a1754da9dae916e70bef9f131ad30ef8be2a50300000000000019381ca69a6a9274670e7bc35c2bf40997b502643a780e4c076572d0844daf8281946b50087e051acaf7bf51]'
```

You can verify that the light client was updated - observe that the latest block incremented by 1.

```sh
sui client object $LC_ID
```

### Verify a transaction inclusion

```fish
set MERKLE_PROOF '[0x48d786523d393fc6e8a008c589dcbe22de0a059cd146d31ab975d310f644e273, 0xa6f51cba788b2bee19f0843bd99a6271f7ea16e65fa817b99e65c6e3523688dd, 0x56ebce9970e1ad5b283a50c0a2945cbdb001fcdee39d74529144c5cec9ef760c, 0xac68796d58d2dab839aea71fb1934755cf859efa709632a25ea6801193c8c4ae, 0xb69f80c6188b311f4cd8d8247490f4cd1de64de9a1f8f166a68cda4dbce98c80, 0x461d99173c20c66a91be8db500e612f48a9a60632e9ce2af52beb116daacb01e, 0x3cfa29d65131d09acdbfe70a484211a300af6c0fa55f0805b977c31edc580cc0]'

# we use dev-inspect to run a function without publishing the transaction:
sui client call --function verify_tx --module light_client --package $PACKAGE_ID --args 
 $LC_ID \ 
 201601 \ # Block height
 0xe02ea982fca17073318a8454d8bb62ad63ce53c443819bb56e1723ab4520b7e9 \ # transaction id
 $MERKLE_PROOF \
 99 \ # transaction index
 --dev-inspect
```
