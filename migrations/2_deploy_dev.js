const AtonomiToken = artifacts.require('AMLToken')
const SafeMathLib = artifacts.require('SafeMathLib')
const AtonomiEternalStorage = artifacts.require('AtonomiEternalStorage')
const Atonomi = artifacts.require('Atonomi')
const Settings = artifacts.require('Settings')
const init = require('../test/helpers/init')

module.exports = function (deployer, network, accounts) {
  if (network !== 'development') return

  const actors = init.getTestActorsContext(accounts)
  const owner = actors.owner

  const tokenDecimals = 18
  const multiplier = 10 ** tokenDecimals
  const regFee = 1 * multiplier
  const actFee = 1 * multiplier
  const repReward = 1 * multiplier
  const reputationShare = 20
  const blockThreshold = 5760 // assuming 15s blocks, 1 write per day

  deployer.deploy(SafeMathLib, {from: owner})
    //
    // ERC20 Token Contract Deployment
    //
    .then(() => deployer.link(SafeMathLib, AtonomiToken, {from: owner}))
    .then(() => deployer.deploy(AtonomiToken, 'Atonomi Token', 'ATMI', 1000000000000000000000000000, tokenDecimals, false, {from: owner}))

    //
    // Storage Contract
    //
    .then(() => deployer.deploy(AtonomiEternalStorage, {from: owner}))

    //
    // Network Settings Contract
    //
    .then(() => deployer.deploy(Settings,
      AtonomiEternalStorage.address,
      regFee, actFee, repReward, reputationShare, blockThreshold,
      {from: owner}))

    //
    // Atonomi Contract
    //
    .then(() => deployer.deploy(Atonomi,
      AtonomiEternalStorage.address,
      AtonomiToken.address,
      Settings.address,
      {from: owner}))
}
