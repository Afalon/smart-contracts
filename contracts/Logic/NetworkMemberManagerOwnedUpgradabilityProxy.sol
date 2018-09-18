pragma solidity ^0.4.23; // solhint-disable-line

import "../Proxy/OwnedUpgradabilityProxy.sol";

/**
 * @title OwnedUpgradeabilityProxy
 * @dev This contract combines an upgradeability proxy with basic authorization control functionalities
 */
contract NetworkMemberManagerOwnedUpgradabilityProxy is OwnedUpgradabilityProxy {
  
    constructor () {
        setPosition(keccak256("atonomi.io.manager.networkmember"));
    }
}