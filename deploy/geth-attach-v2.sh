#!/bin/bash
#set -e
#set -o pipefail

if [ -z ${PARITY_NODE+x} ]; then PARITY_NODE=http://localhost:8545; fi
echo -e "PARITY_NODE is set to '$PARITY_NODE'"

if [ -z ${ETHER_ADDR+x} ]; then ETHER_ADDR=0x48015f23eb79791050885f9464e6dea7456df60b; fi
echo -e "ETHER_ADDR is set to '$ETHER_ADDR'"

npm run compile

echo -e "" > scripts/atonomi-consts.js
echo -e "var ETHER_ADDR='$ETHER_ADDR'" >> scripts/atonomi-consts.js

echo -e "" > scripts/atonomi-abis.js
echo -e "var AtonomiOwnedUpgradabilityProxyJSON = " >> scripts/atonomi-abis.js | cat "../build/contracts/AtonomiOwnedUpgradabilityProxy.json" >> scripts/atonomi-abis.js
echo -e "\nvar AtonomiJSON = " >> scripts/atonomi-abis.js | cat "../build/contracts/Atonomi.json" >> scripts/atonomi-abis.js
echo -e "\nvar TestContractJSON = " >> scripts/atonomi-abis.js | cat "../build/contracts/TestContract.json" >> scripts/atonomi-abis.js

geth --preload "scripts/atonomi-consts.js,scripts/deploy-helpers.js,scripts/atonomi-abis.js,scripts/deploy-atonomi-v2.js" attach $PARITY_NODE
