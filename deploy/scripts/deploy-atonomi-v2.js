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
  mainnet: {
    token: '0x97aeb5066e1a590e868b511457beb6fe99d329f5',
    atonomi: '0x899f3b22908ff5674f8237c321ab309417887606',
    settings: '0x2566c658331eac75d3b3ccd0e45c78d9cf6c4c4c'
  },
  kovan: {
    token: '0xe66254d9560c2d030ca5c3439c5d6b58061dd6f7',
    atonomi: '0xbde8f51601e552d620c208049c5970f7b52cd044',
    settings: '0x729a741ce0c776130c50d35906f0dbd248184982'
  }
}

function deploy_AtonomiContract(gasPriceGwei, estimateOnly) {
  console.log('deploying Atonomi...')

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
