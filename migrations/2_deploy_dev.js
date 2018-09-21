const AtonomiToken = artifacts.require('AMLToken')
const SafeMathLib = artifacts.require('SafeMathLib')
const AtonomiEternalStorage = artifacts.require('AtonomiEternalStorage')
const DeviceManager = artifacts.require('DeviceManager')
const NetworkMemberManager = artifacts.require('NetworkMemberManager')
const SettingsManager = artifacts.require('SettingsManager')
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
    // SettingsManager Contract
    //
    .then(() => deployer.deploy(SettingsManager,
      AtonomiEternalStorage.address,
      regFee, actFee, repReward, reputationShare, blockThreshold,
      {from: owner}))

    //
    // NetworkMemberManager Contract
    //
    .then(() => deployer.deploy(NetworkMemberManager,
      AtonomiEternalStorage.address,
      {from: owner}))

    //
    // DeviceManager Contract
    //
    .then(() => deployer.deploy(DeviceManager,
      AtonomiEternalStorage.address,
      AtonomiToken.address,
      SettingsManager.address,
      {from: owner}))
}
