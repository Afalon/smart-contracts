pragma solidity ^0.4.23; // solhint-disable-line

import "../Storage/AtonomiEternalStorage.sol";
import "./AdminOwnedUpgradabilityProxy.sol";


/**
 * @title EternalStorageProxy
 * @dev This proxy holds the storage of the token contract and delegates every call to the current implementation set.
 * Besides, it allows to upgrade the token's behaviour towards further implementations, and provides basic
 * authorization control functionalities
 */
contract AdminStorageProxy is AtonomiEternalStorage, AdminOwnedUpgradabilityProxy {}