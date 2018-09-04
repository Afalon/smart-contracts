pragma solidity ^0.4.23; // solhint-disable-line

import "zeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "zeppelin-solidity/contracts/lifecycle/TokenDestructible.sol";
import "../Storage/AtonomiEternalStorage.sol";

/// @title ERC-20 Token Standard
/// @author Fabian Vogelsteller <fabian@ethereum.org>, Vitalik Buterin <vitalik.buterin@ethereum.org>
/// @dev https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md
interface ERC20Interface {
    function decimals() public constant returns (uint8);
    function totalSupply() public constant returns (uint);
    function balanceOf(address tokenOwner) public constant returns (uint balance);
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
    function transfer(address to, uint tokens) public returns (bool success);
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);   // solhint-disable-line
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}


/// @title Safe Math library
/// @dev Math operations with safety checks that throw on error
/// @dev https://github.com/OpenZeppelin/zeppelin-solidity/blob/master/contracts/math/SafeMath.sol
library SafeMath {
    /// @dev Multiplies two numbers, throws on overflow.
    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        if (a == 0) {
            return 0;
        }
        c = a * b;
        assert(c / a == b);
        return c;
    }

    /// @dev Integer division of two numbers, truncating the quotient.
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        // uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return a / b;
    }

    /// @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    /// @dev Adds two numbers, throws on overflow.
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        assert(c >= a);
        return c;
    }
}


/// @dev Interface for the Network Settings contract
interface SettingsInterface {
    function registrationFee() external view returns (uint256);
    function activationFee() external view returns (uint256);
    function defaultReputationReward() external view returns (uint256);
    function reputationIRNNodeShare() external view returns (uint256);
    function blockThreshold() external view returns (uint256);
}


/// @title Atonomi Smart Contract
/// @author Atonomi
/// @notice Governs the activation, registration, and reputation of devices on the Atonomi network
/// @dev Ownable: Owner governs the access of Atonomi Admins, Fees, and Rewards on the network
/// @dev Pausable: Gives ability for Owner to pull emergency stop to prevent actions on the network
/// @dev TokenDestructible: Gives owner ability to kill the contract and extract funds to a new contract
contract Atonomi is Pausable, TokenDestructible {
    
    using SafeMath for uint256;

    /// @title ATMI Token
    /// @notice Standard ERC20 Token
    /// @dev AMLToken source: https://github.com/TokenMarketNet/ico/blob/master/contracts/AMLToken.sol
    ERC20Interface public token;

    /// @title Network Settings
    /// @notice Atonomi Owner controlled settings are governed in this contract
    SettingsInterface public settings;

    /// @title Atonomi Storage
    AtonomiEternalStorage private atonomiStorage;

    ///
    /// MODIFIERS
    ///
    /// @notice only manufacturers can call, otherwise throw
    modifier onlyManufacturer() {
        require(atonomiStorage.getBool(keccak256("network", "msg.sender", "isManufacturer")), "must be a manufacturer");
        _;
    }

    /// @notice only IRNAdmins or Owner can call, otherwise throw
    modifier onlyIRNorOwner() {
        require(msg.sender == owner || atonomiStorage.getBool(keccak256("network", "msg.sender", "isIRNAdmin")), "must be owner or an irn admin");
        _;
    }

    /// @notice only IRN Nodes can call, otherwise throw
    modifier onlyIRNNode() {
        require(atonomiStorage.getBool(keccak256("network", "msg.sender", "isIRNNode")), "must be an irn node");
        _;
    }

    /// @notice Constructor sets the ERC Token contract and initial values for network fees
    /// @param _token is the Atonomi Token contract address (must be ERC20)
    /// @param _settings is the Atonomi Network Settings contract address
    constructor (
        address _storage,
        address _token,
        address _settings) public {
        require(_token != address(0), "token address cannot be 0x0");
        require(_settings != address(0), "settings address cannot be 0x0");
        token = ERC20Interface(_token);
        settings = SettingsInterface(_settings);
        atonomiStorage = AtonomiEternalStorage(_storage);
    }

///
    /// EVENTS 
    ///
    /// @notice emitted on successful device registration
    /// @param _sender manufacturer paying for registration
    /// @param _fee registration fee paid by manufacturer
    /// @param _deviceHashKey keccak256 hash of device id used as the key in devices mapping
    /// @param _manufacturerId of the manufacturer the device belongs to
    /// @param _deviceType is the type of device categorized by the manufacturer
    event DeviceRegistered(
        address indexed _sender,
        uint256 _fee,
        bytes32 indexed _deviceHashKey,
        bytes32 indexed _manufacturerId,
        bytes32 _deviceType
    );

    /// @notice emitted on successful device activation
    /// @param _sender manufacturer or device owner paying for activation
    /// @param _fee registration fee paid by manufacturer
    /// @param _deviceId the real device id (only revealed after activation)
    /// @param _manufacturerId of the manufacturer the device belongs to
    /// @param _deviceType is the type of device categorized by the manufacturer
    event DeviceActivated(
        address indexed _sender,
        uint256 _fee,
        bytes32 indexed _deviceId,
        bytes32 indexed _manufacturerId,
        bytes32 _deviceType
    );

    /// @notice emitted on reputation change for a device
    /// @param _deviceId device id of the target device
    /// @param _deviceType is the type of device categorized by the manufacturer
    /// @param _newScore updated reputation score
    /// @param _irnNode IRN node submitting the new reputation
    /// @param _irnReward tokens awarded to irn node
    /// @param _manufacturerWallet manufacturer associated with the device is rewared a share of tokens
    /// @param _manufacturerReward tokens awarded to contributor
    event ReputationScoreUpdated(
        bytes32 indexed _deviceId,
        bytes32 _deviceType,
        bytes32 _newScore,
        address indexed _irnNode,
        uint256 _irnReward,
        address indexed _manufacturerWallet,
        uint256 _manufacturerReward
    );

    /// @notice emitted on successful addition of network member address
    /// @param _sender ethereum account of participant that made the change
    /// @param _member address of added member
    /// @param _memberId manufacturer id for manufacturer, otherwise 0x0
    event NetworkMemberAdded(
        address indexed _sender,
        address indexed _member,
        bytes32 indexed _memberId
    );

    /// @notice emitted on successful removal of network member address
    /// @param _sender ethereum account of participant that made the change
    /// @param _member address of removed member
    /// @param _memberId manufacturer id for manufacturer, otherwise 0x0
    event NetworkMemberRemoved(
        address indexed _sender,
        address indexed _member,
        bytes32 indexed _memberId
    );

    /// @notice emitted everytime a manufacturer changes their wallet for rewards
    /// @param _old ethereum account
    /// @param _new ethereum account
    /// @param _manufacturerId that the member belongs to
    event ManufacturerRewardWalletChanged(
        address indexed _old,
        address indexed _new,
        bytes32 indexed _manufacturerId
    );

    /// @notice emitted everytime a token pool reward amount changes
    /// @param _sender ethereum account of the token pool owner
    /// @param _newReward new reward value in ATMI tokens
    event TokenPoolRewardUpdated(
        address indexed _sender,
        uint256 _newReward
    );

    /// @notice emitted everytime someone donates tokens to a manufacturer
    /// @param _sender ethereum account of the donater
    /// @param _manufacturerId of the manufacturer
    /// @param _manufacturer ethereum account
    /// @param _amount of tokens deposited
    event TokensDeposited(
        address indexed _sender,
        bytes32 indexed _manufacturerId,
        address indexed _manufacturer,
        uint256 _amount
    );
    
    /// @notice emitted everytime a participant withdraws from token pool
    /// @param _sender ethereum account of participant that made the change
    /// @param _amount tokens withdrawn
    event TokensWithdrawn(
        address indexed _sender,
        uint256 _amount
    );

    /// @notice emitted everytime the default reputation for a manufacturer changes
    /// @param _sender ethereum account of participant that made the change
    /// @param _manufacturerId of the manufacturer
    /// @param _newDefaultScore to use for newly registered devices
    event DefaultReputationScoreChanged(
        address indexed _sender,
        bytes32 indexed _manufacturerId,
        bytes32 _newDefaultScore
    );
    ///
    /// DEVICE ONBOARDING
    ///
    /// @notice registers device on the Atonomi network
    /// @param _deviceIdHash keccak256 hash of the device's id (needs to be hashed by caller)
    /// @param _deviceType is the type of device categorized by the manufacturer
    /// @dev devicePublicKey is public key used by IRN Nodes for validation
    /// @return true if successful, otherwise false
    /// @dev msg.sender is expected to be the manufacturer
    /// @dev tokens will be deducted from the manufacturer and added to the token pool
    /// @dev owner has ability to pause this operation
    function registerDevice(
        bytes32 _deviceIdHash,
        bytes32 _deviceType,
        bytes32 _devicePublicKey)
        public onlyManufacturer whenNotPaused returns (bool)
    {
        uint256 registrationFee = settings.registrationFee();
        
        _registerDevice(msg.sender, _deviceIdHash, _deviceType, _devicePublicKey);

        emit DeviceRegistered(
            msg.sender,
            registrationFee,
            atonomiStorage.getBytes32(keccak256("devices", _deviceIdHash)),
            atonomiStorage.getBytes32(keccak256("devices", "manufacturerId")),
            atonomiStorage.getBytes32(keccak256("devices", _deviceType)));
        _depositTokens(msg.sender, registrationFee);
        require(token.transferFrom(msg.sender, address(this), registrationFee), "transferFrom failed");
        return true;
    }

    /// @notice Activates the device
    /// @param _deviceId id of the real device id to be activated (not the hash of the device id)
    /// @return true if successful, otherwise false
    /// @dev if the hash doesnt match, the device is considered not registered and will throw
    /// @dev anyone with the device id (in hand) is considered the device owner
    /// @dev tokens will be deducted from the device owner and added to the token pool
    /// @dev owner has ability to pause this operation
    function activateDevice(bytes32 _deviceId) public whenNotPaused returns (bool) {
        uint256 activationFee = settings.activationFee();
        
        _activateDevice(_deviceId);

        bytes32 manufacturerId = atonomiStorage.getBytes32(keccak256("devices", _deviceId, "manufacturerId"));
        bytes32 deviceType = atonomiStorage.getBytes32(keccak256("devices", _deviceId, "deviceType"));

        emit DeviceActivated(
            msg.sender, 
            activationFee, 
            _deviceId, 
            manufacturerId, 
            deviceType);

        address manufacturer = atonomiStorage.getAddress(keccak256("manufacturerRewards", manufacturerId));
        require(manufacturer != address(this), "manufacturer is unknown");
        _depositTokens(manufacturer, activationFee);
        require(token.transferFrom(msg.sender, address(this), activationFee), "transferFrom failed");
        return true;
    }

    /// @notice Registers and immediately activates device, used by manufacturers to prepay activation
    /// @param _deviceId id of the real device id to be activated (not the has of the device id)
    /// @param _deviceType is the type of device categorized by the manufacturer
    /// @return true if successful, otherwise false
    /// @dev since the manufacturer is trusted, no need for the caller to hash the device id
    /// @dev msg.sender is expected to be the manufacturer
    /// @dev tokens will be deducted from the manufacturer and added to the token pool
    /// @dev owner has ability to pause this operation
    function registerAndActivateDevice(
        bytes32 _deviceId,
        bytes32 _deviceType,
        bytes32 _devicePublicKey) 
        public onlyManufacturer whenNotPaused returns (bool)
    {
        uint256 registrationFee = settings.registrationFee();
        uint256 activationFee = settings.activationFee();

        bytes32 deviceIdHash = keccak256(_deviceId);

        _registerDevice(msg.sender, deviceIdHash, _deviceType, _devicePublicKey);

        bytes32 manufacturerId = atonomiStorage.getBytes32(keccak256("devices", deviceIdHash, "manufacturerId"));
        emit DeviceRegistered(msg.sender, registrationFee, deviceIdHash, manufacturerId, _deviceType);

        _activateDevice(_deviceId);

        emit DeviceActivated(msg.sender, activationFee, _deviceId, manufacturerId, _deviceType);

        uint256 fee = registrationFee.add(activationFee);
        _depositTokens(msg.sender, fee);
        require(token.transferFrom(msg.sender, address(this), fee), "transferFrom failed");
        return true;
    }

    ///
    /// REPUTATION MANAGEMENT
    ///
    /// @notice updates reputation for a device
    /// @param _deviceId target device Id
    /// @param _reputationScore updated reputation score computed by the author
    /// @return true if successful, otherwise false
    /// @dev msg.sender is expected to be the reputation author (either irn node or the reputation auditor)
    /// @dev tokens will be deducted from the contract pool
    /// @dev author and manufacturer will be rewarded a split of the tokens
    /// @dev owner has ability to pause this operation
    function updateReputationScore(
        bytes32 _deviceId,
        bytes32 _reputationScore)
        public onlyIRNNode whenNotPaused returns (bool)
    {
        _updateReputationScore(_deviceId, _reputationScore);

        bytes32 manufacturerId = atonomiStorage.getBytes32(keccak256("devices", _deviceId, "manufacturerId"));
        bytes32 deviceType = atonomiStorage.getBytes32(keccak256("devices", _deviceId, "deviceType"));

        address _manufacturerWallet = atonomiStorage.getAddress(keccak256("manufacturerRewards", manufacturerId));
        require(_manufacturerWallet != address(0), "_manufacturerWallet cannot be 0x0");
        require(_manufacturerWallet != msg.sender, "manufacturers cannot collect the full reward");

        uint256 irnReward;
        uint256 manufacturerReward;
        (irnReward, manufacturerReward) = getReputationRewards(msg.sender, _manufacturerWallet, _deviceId);
        _distributeRewards(_manufacturerWallet, msg.sender, irnReward);
        _distributeRewards(_manufacturerWallet, _manufacturerWallet, manufacturerReward);
        emit ReputationScoreUpdated(
            _deviceId,
            deviceType,
            _reputationScore,
            msg.sender,
            irnReward,
            _manufacturerWallet,
            manufacturerReward);
        atonomiStorage.setUint(keccak256("authorWrites",msg.sender,_deviceId), block.number);
        return true;
    }

    /// @notice computes the portion of the reputation reward allotted to the manufacturer and author
    /// @param author is the reputation node submitting the score
    /// @param manufacturer is the token pool owner
    /// @param deviceId of the device being updated
    /// @return irnReward and manufacturerReward
    function getReputationRewards(
        address author,
        address manufacturer,
        bytes32 deviceId)
        public view returns (uint256 irnReward, uint256 manufacturerReward)
    {
        uint256 lastWrite = atonomiStorage.getUint(keccak256("authorWrites",author,deviceId));
        uint256 blocks = 0;
        if (lastWrite > 0) {
            blocks = block.number.sub(lastWrite);
        }
        uint256 totalRewards = calculateReward(atonomiStorage.getUint(keccak256("pools",manufacturer,"rewardAmount")), blocks);
        irnReward = totalRewards.mul(settings.reputationIRNNodeShare()).div(100);
        manufacturerReward = totalRewards.sub(irnReward);
    }

    /// @notice computes total reward based on the authors last submission
    /// @param rewardAmount total amount available for reward
    /// @param blocksSinceLastWrite number of blocks since last write
    /// @return actual reward available
    function calculateReward(uint256 rewardAmount, uint256 blocksSinceLastWrite) public view returns (uint256) {
        uint256 totalReward = rewardAmount;
        uint256 blockThreshold = settings.blockThreshold();
        if (blocksSinceLastWrite > 0 && blocksSinceLastWrite < blockThreshold) {
            uint256 multiplier = 10 ** uint256(token.decimals());
            totalReward = rewardAmount.mul(blocksSinceLastWrite.mul(multiplier)).div(blockThreshold.mul(multiplier));
        }
        return totalReward;
    }

    ///
    /// BULK OPERATIONS
    ///
    /// @notice registers multiple devices on the Atonomi network
    /// @param _deviceIdHashes array of keccak256 hashed ID's of each device
    /// @param _deviceTypes array of types of device categorized by the manufacturer
    /// @param _devicePublicKeys array of public keys associated with the devices
    /// @return true if successful, otherwise false
    /// @dev msg.sender is expected to be the manufacturer
    /// @dev tokens will be deducted from the manufacturer and added to the token pool
    /// @dev owner has ability to pause this operation
    function registerDevices(
        bytes32[] _deviceIdHashes,
        bytes32[] _deviceTypes,
        bytes32[] _devicePublicKeys)
        public onlyManufacturer whenNotPaused returns (bool)
    {
        require(_deviceIdHashes.length > 0, "at least one device is required");
        require(
            _deviceIdHashes.length == _deviceTypes.length,
            "device type array needs to be same size as devices"
        );
        require(
            _deviceIdHashes.length == _devicePublicKeys.length,
            "device public key array needs to be same size as devices"
        );

        uint256 runningBalance = 0;
        uint256 registrationFee = settings.registrationFee();
        for (uint256 i = 0; i < _deviceIdHashes.length; i++) {
            bytes32 deviceIdHash = _deviceIdHashes[i];
            bytes32 deviceType = _deviceTypes[i];
            bytes32 devicePublicKey = _devicePublicKeys[i];
            
            _registerDevice(msg.sender, deviceIdHash, deviceType, devicePublicKey);

            bytes32 manufacturerId = atonomiStorage.getBytes32(keccak256("devices", deviceIdHash, "manufacturerId"));
            emit DeviceRegistered(msg.sender, registrationFee, deviceIdHash, manufacturerId, deviceType);

            runningBalance = runningBalance.add(registrationFee);
        }

        _depositTokens(msg.sender, runningBalance);
        require(token.transferFrom(msg.sender, address(this), runningBalance), "transferFrom failed");
        return true;
    }

    ///
    /// WHITELIST PARTICIPANT MANAGEMENT
    ///
    /// @notice add a member to the network
    /// @param _member ethereum address of member to be added
    /// @param _isIRNAdmin true if an irn admin, otherwise false
    /// @param _isManufacturer true if an manufactuter, otherwise false
    /// @param _memberId manufacturer id for manufacturers, otherwise 0x0
    /// @return true if successful, otherwise false
    /// @dev _memberId is only relevant for manufacturer, but is flexible to allow use for other purposes
    /// @dev msg.sender is expected to be either owner or irn admin
    function addNetworkMember(
        address _member,
        bool _isIRNAdmin,
        bool _isManufacturer,
        bool _isIRNNode,
        bytes32 _memberId)
        public onlyIRNorOwner returns(bool)
    {
        require(!atonomiStorage.getBool(keccak256("network", _member, "isIRNAdmin")), "already an irn admin");
        require(!atonomiStorage.getBool(keccak256("network", _member, "isManufacturer")), "already a manufacturer");
        require(!atonomiStorage.getBool(keccak256("network", _member, "isIRNNode")), "already an irn node");
        require(atonomiStorage.getUint(keccak256("network", _member, "memberId")) != 0, "already assigned a member id");

        atonomiStorage.setBool(keccak256("network", _member, "isIRNAdmin"), _isIRNAdmin);
        atonomiStorage.setBool(keccak256("network", _member, "isManufacturer"), _isManufacturer);
        atonomiStorage.setBool(keccak256("network", _member, "isIRNNode"), _isIRNNode);
        atonomiStorage.setBytes32(keccak256("network", _member, "memberId"), _memberId);

        if (_isManufacturer) {
            require(_memberId != 0, "manufacturer id is required");

            // keep lookup for rewards in sync
            require(atonomiStorage.getAddress(keccak256("manufacturerRewards",_memberId)) == address(0), "manufacturer is already assigned");
            atonomiStorage.setAddress(keccak256("manufacturerRewards",_memberId), _member);

            // set reputation reward if token pool doesnt exist
            if (atonomiStorage.getAddress(keccak256("pools", _member, "rewardAmount")) == 0) { //TODO This check may need revision
                atonomiStorage.setUint(keccak256("pools", _member, "rewardAmount"), settings.defaultReputationReward());
            }
        }

        emit NetworkMemberAdded(msg.sender, _member, _memberId);

        return true;
    }

    /// @notice remove a member from the network
    /// @param _member ethereum address of member to be removed
    /// @return true if successful, otherwise false
    /// @dev msg.sender is expected to be either owner or irn admin
    function removeNetworkMember(address _member) public onlyIRNorOwner returns(bool) {
        bytes32 memberId = atonomiStorage.getBytes32(keccak256("network", _member, "memberId"));
        bool isManufacturer = atonomiStorage.getBool(keccak256("network", _member, "isManufacturer"));
        if (isManufacturer) {
            // remove token pool if there is a zero balance
            if (atonomiStorage.getAddress(keccak256("pools", _member, "balance")) == 0) {
                atonomiStorage.deleteUint(keccak256("pools", _member, "balance"));
                atonomiStorage.deleteUint(keccak256("pools", _member, "rewardAmount"));
            }

            // keep lookup with rewards in sync
            atonomiStorage.deleteUint(keccak256("manufacturerRewards", memberId));
        }

        atonomiStorage.deleteBool(keccak256("network", _member, "isIRNAdmin"));
        atonomiStorage.deleteBool(keccak256("network", _member, "isManufacturer"));
        atonomiStorage.deleteBool(keccak256("network", _member, "isIRNNode"));
        atonomiStorage.deleteBytes32(keccak256("network", _member, "memberId"));

        emit NetworkMemberRemoved(msg.sender, _member, memberId);
        return true;
    }

    //
    // TOKEN POOL MANAGEMENT
    //
    /// @notice changes the ethereum wallet for a manufacturer used in reputation rewards
    /// @param _new new ethereum account
    /// @return true if successful, otherwise false
    /// @dev msg.sender is expected to be original manufacturer account
    function changeManufacturerWallet(address _new) public onlyManufacturer returns (bool) {
        require(_new != address(0), "new address cannot be 0x0");

        require(atonomiStorage.getBool(keccak256("network", msg.sender, "isManufacturer")), "must be a manufacturer");
        require(atonomiStorage.getBytes32(keccak256("network", msg.sender, "memberId")) != 0, "must be a manufacturer");

        // copy permissions

        bool oldIdIrnAdmin = atonomiStorage.getBool(keccak256("network", msg.sender, "isIRNAdmin"));
        bool oldIsManufacturer = atonomiStorage.getBool(keccak256("network", msg.sender, "isManufacturer"));
        bool oldIsIRNNode = atonomiStorage.getBool(keccak256("network", msg.sender, "isIRNNode"));
        bytes32 oldMemberId = atonomiStorage.getBytes32(keccak256("network", msg.sender, "memberId"));

        require(!oldIdIrnAdmin, "already an irn admin");
        require(!oldIsManufacturer, "already a manufacturer");
        require(!oldIsIRNNode, "already an irn node");
        require(oldMemberId == 0, "already assigned a member id");


        atonomiStorage.setBool(keccak256("network", _new, "isIRNAdmin"), oldIdIrnAdmin);
        atonomiStorage.setBool(keccak256("network", _new, "isManufacturer"), oldIsManufacturer);
        atonomiStorage.setBool(keccak256("network", _new, "isIRNNode"), oldIsIRNNode);
        atonomiStorage.setBytes32(keccak256("network", _new, "memberId"), oldMemberId);

        
        // transfer balance from old pool to the new pool
        require(atonomiStorage.getUint(keccak256("pools", _new, "balance")) == 0, "new token pool already exists");
        require(atonomiStorage.getUint(keccak256("pools", _new, "rewardAmount")) == 0, "new token pool already exists");

        atonomiStorage.setUint(keccak256("pools", _new, "balance"), atonomiStorage.getUint(keccak256("pools", msg.sender, "balance")));
        atonomiStorage.setUint(keccak256("pools", _new, "rewardAmount"), atonomiStorage.getUint(keccak256("pools", msg.sender, "rewardAmount")));

        atonomiStorage.deleteUint(keccak256("pools", msg.sender, "balance"));
        atonomiStorage.deleteUint(keccak256("pools", msg.sender, "rewardAmount"));

        // update reward mapping
        atonomiStorage.setAddress(keccak256("manufacturerRewards", msg.sender, "address"), _new);

        // delete old member
        atonomiStorage.deleteBool(keccak256("network", msg.sender, "isIRNAdmin"));
        atonomiStorage.deleteBool(keccak256("network", msg.sender, "isManufacturer"));
        atonomiStorage.deleteBool(keccak256("network", msg.sender, "isIRNNode"));
        atonomiStorage.deleteBytes32(keccak256("network", msg.sender, "memberId"));

        emit ManufacturerRewardWalletChanged(msg.sender, _new, oldMemberId);
        return true;
    }

    /// @notice allows a token pool owner to set a new reward amount
    /// @param newReward new reputation reward amount
    /// @return true if successful, otherwise false
    /// @dev msg.sender expected to be manufacturer
    function setTokenPoolReward(uint256 newReward) public onlyManufacturer returns (bool) {
        require(newReward != 0, "newReward is required");

        require(atonomiStorage.getUint(keccak256("pools", msg.sender, "rewardAmount")) != newReward, "newReward should be different");

        atonomiStorage.setUint(keccak256("pools", msg.sender, "rewardAmount"), newReward);
        emit TokenPoolRewardUpdated(msg.sender, newReward);
        return true;
    }

    /// @notice anyone can donate tokens to a manufacturer's pool
    /// @param manufacturerId of the manufacturer to receive the tokens
    /// @param amount of tokens to deposit
    function depositTokens(bytes32 manufacturerId, uint256 amount) public returns (bool) {
        require(manufacturerId != 0, "manufacturerId is required");
        require(amount > 0, "amount is required");

        address manufacturer = atonomiStorage.getAddress(keccak256("manufacturerRewards","manufacturerId"));
        require(manufacturer != address(0), "manufacturer must have a valid address");

        _depositTokens(manufacturer, amount);
        emit TokensDeposited(msg.sender, manufacturerId, manufacturer, amount);

        require(token.transferFrom(msg.sender, address(this), amount));
        return true;
    }

    /// @notice allows participants in the Atonomi network to claim their rewards
    /// @return true if successful, otherwise false
    /// @dev owner has ability to pause this operation
    function withdrawTokens() public whenNotPaused returns (bool) {
        uint256 amount = atonomiStorage.getUint(keccak256("rewards", msg.sender));
        require(amount > 0, "amount is zero");

        atonomiStorage.setUint(keccak256("rewards", msg.sender), 0);
        emit TokensWithdrawn(msg.sender, amount);

        require(token.transfer(msg.sender, amount), "token transfer failed");
        return true;
    }

    /// @notice allows the owner to change the default reputation for manufacturers
    /// @param _manufacturerId of the manufacturer
    /// @param _newDefaultScore to use for newly registered devices
    /// @return true if successful, otherwise false
    /// @dev owner is the only one with this feature
    function setDefaultReputationForManufacturer(
        bytes32 _manufacturerId,
        bytes32 _newDefaultScore) public onlyOwner returns (bool) {
        require(_manufacturerId != 0, "_manufacturerId is required");
        require(
            _newDefaultScore != atonomiStorage.getBytes32(keccak256("defaultManufacturerReputations", _manufacturerId)),
            "_newDefaultScore should be different"
        );

        atonomiStorage.setBytes32(keccak256("defaultManufacturerReputations", _manufacturerId), _newDefaultScore);

        emit DefaultReputationScoreChanged(msg.sender, _manufacturerId, _newDefaultScore);
        return true;
    }

    ///
    /// INTERNAL FUNCTIONS
    ///
    /// @dev track balances of any deposits going into a token pool
    function _depositTokens(address _owner, uint256 _amount) internal {
        uint256 balance = atonomiStorage.getUint(keccak256("pools", _owner, "balance"));
        atonomiStorage.setUint(keccak256("pools", _owner, "balance"), balance.add(_amount));
    }

    /// @dev track balances of any rewards going out of the token pool
    function _distributeRewards(address _manufacturer, address _owner, uint256 _amount) internal {
        require(_amount > 0, "_amount is required");

        uint256 balance = atonomiStorage.getUint(keccak256("pools", _manufacturer, "balance"));
        atonomiStorage.setUint(keccak256("pools", _manufacturer, "balance"), balance.sub(_amount));

        uint256 reward = atonomiStorage.getUint(keccak256("rewards", _owner));
        atonomiStorage.setUint(keccak256("rewards", _owner), reward.add(_amount));
    }

    /// @dev ensure a device is validated for registration
    /// @dev updates device registry
    function _registerDevice(
        address _manufacturer,
        bytes32 _deviceIdHash,
        bytes32 _deviceType,
        bytes32 _devicePublicKey) internal {
        require(_manufacturer != address(0), "manufacturer is required");
        require(_deviceIdHash != 0, "device id hash is required");
        require(_deviceType != 0, "device type is required");
        require(_devicePublicKey != 0, "device public key is required");

        require(!atonomiStorage.getBool(keccak256("devices", _deviceIdHash, "registered")), "device is already registered");
        require(!atonomiStorage.getBool(keccak256("devices", _deviceIdHash, "activated")), "device is already activated");

        bytes32 manufacturerId = atonomiStorage.getBytes32(keccak256("network", _manufacturer, "memberId"));
        require(manufacturerId != 0, "manufacturer id is unknown");

        atonomiStorage.setBytes32(keccak256("devices", _deviceIdHash, "manufacturerId"), manufacturerId);
        atonomiStorage.setBytes32(keccak256("devices", _deviceIdHash, "deviceType"), _deviceType);
        atonomiStorage.setBool(keccak256("devices", _deviceIdHash, "registered"), true);
        atonomiStorage.setBool(keccak256("devices", _deviceIdHash, "activated"), false);

        bytes32 newScore = atonomiStorage.getBytes32(keccak256("defaultManufacturerReputations", "manufacturerId"));
        atonomiStorage.setBytes32(keccak256("devices", _deviceIdHash, "reputationScore"), newScore);
        atonomiStorage.setBytes32(keccak256("devices", _deviceIdHash, "devicePublicKey"), _devicePublicKey);
    }

    /// @dev ensure a device is validated for activation
    /// @dev updates device registry
    function _activateDevice(bytes32 _deviceId) internal {
        bytes32 deviceIdHash = keccak256(_deviceId);
        
        require(atonomiStorage.getBool(keccak256("devices", deviceIdHash, "registered")), "not registered");
        require(!atonomiStorage.getBool(keccak256("devices", deviceIdHash, "activated")), "already activated");
        require(atonomiStorage.getUint(keccak256("devices", deviceIdHash, "manufacturerId")) != 0, "no manufacturer id was found");

        atonomiStorage.setBool(keccak256("devices", _deviceId, "activated"), true);
    }

    /// @dev ensure a device is validated for a new reputation score
    /// @dev updates device registry
    function _updateReputationScore(bytes32 _deviceId, bytes32 _reputationScore) internal{
        require(_deviceId != 0, "device id is empty");

        require(atonomiStorage.getBool(keccak256("devices", _deviceId, "registered")), "not registered");
        require(atonomiStorage.getBool(keccak256("devices", _deviceId, "activated")), "not activated");
        require(atonomiStorage.getBytes32(keccak256("devices", _deviceId, "reputationScore")) != _reputationScore, "new score needs to be different");

        atonomiStorage.setBytes32(keccak256("devices", _deviceId, "reputationScore"), _reputationScore);
    }
}