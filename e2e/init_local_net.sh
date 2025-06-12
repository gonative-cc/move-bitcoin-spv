#!/bin/bash
set -e

ACTIVE_ADDRESS=$(sui client active-address)
echo "Active Sui Address: $ACTIVE_ADDRESS"

ACTIVE_ENV=$(sui client active-env)
echo "Active Sui Env: $ACTIVE_ENV"
echo "Requesting SUI from faucet..."
sui client faucet
sleep 5  # Wait for faucet
sui client gas

echo "Sui network initialized, faucet request complete"
