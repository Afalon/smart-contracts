pragma solidity ^0.4.23; // solhint-disable-line

/**
 * @title Registry
 * @dev This contract works as a registry contracts allowed to write to storage
 */
contract Registry {

    // Mapping of versions to implementations of different functions
    mapping (string => address) internal versions;

    /**
    * @dev This event will be emitted every time a new contract is added to the registry
    * @param version representing the new version of the added contract

    */
    event VersionAdded(string version, address implementation);


    /**
    * @dev Registers a new version with its implementation address
    * @param version representing the version name of the new implementation to be registered
    * @param implementation representing the address of the new implementation to be registered
    */
    function addContract(string version, address implementation) public {
        require(versions[version] == 0x0);
        versions[version] = implementation;
        VersionAdded(version, implementation);
    }        

    /**
    * @dev Tells the address of the implementation for a given version
    * @param version to query the implementation of
    * @return address of the implementation registered for the given version
    */
    function removeContract(string version) public view returns (address) {
        return versions[version];
    }
}