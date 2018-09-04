var tokenName = 'Atonomi Token'
var tokenSymbol = 'ATMI'
var tokenDecimals = 18
var multiplier = Math.pow(10, tokenDecimals)
var regFee = 1 * multiplier
var actFee = 1 * multiplier
var repReward = 0.125 * multiplier
var reputationShare = 80
var blockThreshold = 5760 // assuming 15s blocks, 1 write per day
var initalSupply = 1000000000 * multiplier

var chains = {
  mainnet: {},
  kovan: {
    token: '0xe66254d9560c2d030ca5c3439c5d6b58061dd6f7',
    atonomi: '0xbde8f51601e552d620c208049c5970f7b52cd044',
    atonomiProxy: '0x2aAddC5f96dF90C6c228db01110e5bc41ba437C1',
    settings: '0x729a741ce0c776130c50d35906f0dbd248184982'
  }
}

function deploy_AtonomiProxy(gasPriceGwei, estimateOnly) {
  console.log('deploying Atonomi Proxy...')

  var gasPriceWei = web3.toWei(gasPriceGwei, 'gwei')
  console.log('gas price', gasPriceWei)

  var constructorByteCode = web3.eth.contract(AtonomiOwnedUpgradabilityProxyJSON.abi).new.getData({ data: AtonomiOwnedUpgradabilityProxyJSON.bytecode })
  var gas = web3.eth.estimateGas({ from: ETHER_ADDR, data: constructorByteCode })
  console.log('gas estimate', gas)

  if(estimateOnly) return undefined

  var hash = web3.eth.sendTransaction({ from: ETHER_ADDR, data: constructorByteCode, gas: gas, gasPrice: gasPriceWei })
  console.log('txn hash', hash)

  return hash
}

function upgrade_AtonomiProxy(proxyAddress, implementationAddress, gasPriceGwei, estimateOnly) {
  console.log('setting Atonomi Implementation...')

  var gasPriceWei = web3.toWei(gasPriceGwei, 'gwei')
  console.log('gas price', gasPriceWei)

  var proxyContract = web3.eth.contract(AtonomiOwnedUpgradabilityProxyJSON.abi).at(proxyAddress)
  var gas = proxyContract.upgradeTo.estimateGas(implementationAddress, { from: ETHER_ADDR })
  console.log('gas estimate', gas)

  if(estimateOnly) return undefined

  var hash = proxyContract.upgradeTo(implementationAddress, { from: ETHER_ADDR, gas: gas, gasPrice: gasPriceWei })
  return hash
}
