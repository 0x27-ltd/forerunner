# Forge Deployment Notes

### Deploy to Anvil localhost
* create deploy script like FundModule.s.sol (not no private key needed for the vm.broadcast/vm.startBroadcast bit)
* run command: anvil in a seperate terminal to get the local rpc listening on http://127.0.0.1:8545 
    * If you include a --fork-url flag you can fork a different network @ specific block: anvil --fork-url $GOERLI_RPC_URL --fork-block-number 8905280
* forge script script/FundModule.s.sol:FundModuleScript --rpc-url http://127.0.0.1:8545 (or $LOCAL_HOST if you have that in .env file)
* note that the script may contain more than one contract, hence the :FundModuleScript above

### Deploy live setup
* .env file save chain rpcs like this RINKEBY_RPC_URL=insert_rpc_url
* To give our shell access to our environment variables run: source .env
* save rpc's as env variable (can also save PRIVATE_KEY & ETHERSCAN_KEY)
* Replace the localhost with this format to deploy to that chain --rpc-url $RINKEBY_RPC_URL
* Tip: if you want to simulate and form a deployment tx to see gas (it saves in broadcast folder) without sending, don't add --broadcast flag

### Example of full deployment and verification with verbose output
forge script script/MyToken.s.sol:MyScript --rpc-url $RINKEBY_RPC_URL  --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv
