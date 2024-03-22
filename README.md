# Deployment Examples

## 1 transform a docx license into license JSON descriptor using AI 
```shell
npx hardhat docjson --path ./licenses/ibsync.docx      
```
## 2 Deploy a specific license template form a descriptor:
```shell
npx hardhat license --pdfpath ./licenses/ibsync_v2.pdf --descpath ./licenses/ibsync_v2.json  --reg 0x509591c0F81Fae1bf17C6c9D7B168398d2b53aDe  --chainid 80001 --network mumbai --name "IB Sync License"
```
## transform a json descriptor into a nice html table:
```shell
npx hardhat docjson --path ./licenses/ibsync.docx      
```
## Deploy all contracts to production or testnet
```shell
npx hardhat legato --chainid 80001 --network mumbai         
```
## Add currency
```shell
npx hardhat add-currency --currency 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174 --feedist 0x4d0134c8109b46f32871B06CfAFB8513Cdd71159 --chainid 137 --network polygon  
```

## Check stuff with cask on fee dist
```shell
# Check address of a contract on address manager
cast call 0xfCc30098578498100C66dD43f6cB77350619857b "getContractAddress(string)(address)" contracts.licenseRegistry --rpc-url [RPC_URL]

cast call 0x4d0134c8109b46f32871B06CfAFB8513Cdd71159 "getAllowedCurrencies()" --rpc-url [RPC_URL]
cast call 0x4d0134c8109b46f32871B06CfAFB8513Cdd71159 "getVersion()" --rpc-url [RPC_URL]

# remove currency
cast send 0x4d0134c8109b46f32871B06CfAFB8513Cdd71159 "removeCurrency(address)" 0x8eE64da344007f2778e24b216c4d92D3E03E2750 --rpc-url [RPC] --private-key [PK]

# run script
forge script CheckAddresses 0xfCc30098578498100C66dD43f6cB77350619857b --sig "run(address)"  --rpc-url [RPC]


# Deploy new version
$ forge create --rpc-url [RPC_URL] --private-key <your_private_key> contracts/dataBound/FeeDistributorV3.sol
 
 ```
