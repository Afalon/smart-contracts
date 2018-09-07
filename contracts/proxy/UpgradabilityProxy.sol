pragma solidity ^0.4.23;

import "../proxy/Proxy.sol";

/**
 * @title UpgradeabilityProxy
 * @dev This contract represents a proxy where the implementation address to which it will delegate can be upgraded
 */
contract UpgradabilityProxy is Proxy {
    /**
     * @dev This event will be emitted every time the implementation gets upgraded
     * @param implementation representing the address of the upgraded implementation
     */
    event Upgraded(address indexed implementation);
    
    // Storage position of the address of the current implementation
    bytes32 private implementationPosition;
    
    /**
     * @dev Constructor function
     */
    constructor() public {}
    
    /**
    @dev set storage position
    */
    function setPosition (bytes32 _positionKey) internal {
        if(implementationPosition == ""){
            //only set implementation position if it is not already set
            implementationPosition = _positionKey;
        }
    }

    /**
     * @dev Tells the address of the current implementation
     * @return address of the current implementation
     */
    function implementation() public view returns (address impl) {
        bytes32 position = implementationPosition;
        assembly {
          impl := sload(position)
        }
    }

    /**     
     * @dev Sets the address of the current implementation
     * @param newImplementation address representing the new implementation to be set
     */
    function setImplementation(address newImplementation) internal {
        bytes32 position = implementationPosition;
        assembly {
          sstore(position, newImplementation)
        }
    }
      

  /**
   * @dev Upgrades the implementation address
   * @param newImplementation representing the address of the new implementation to be set
   */
    function _upgradeTo(address newImplementation) internal {
        address currentImplementation = implementation();
        require(currentImplementation != newImplementation);
        setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }
}
