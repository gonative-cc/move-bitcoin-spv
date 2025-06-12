#!/bin/bash
set -e
set -x

apt-get update -y
apt-get install -y curl gnupg jq
curl -fsSL https://deb.nodesource.com/setup_23.x -o nodesource_setup.sh
bash nodesource_setup.sh
apt-get install -y nodejs
echo "Verifying tool versions"
node -v
npm -v
jq --version


SUBMITTER_DIR="./e2e/submitter"

if [ ! -d "$SUBMITTER_DIR" ]; then
    echo "Error: Submitter directory '$SUBMITTER_DIR' not found."
    exit 1
fi

cd "$SUBMITTER_DIR"
echo "Installing npm packages in $(pwd)..."
npm install
echo "Env Setup Complete"
