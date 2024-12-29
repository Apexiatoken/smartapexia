// SPDX-License-Identifier:MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./IERC20APX.sol";

interface IERC20_USDT {
    function transferFrom(address from, address to, uint value) external;
    function transfer( address to, uint value) external;
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract PriceBalancer is AccessControl {
    IERC20_USDT public tetherToken;
    IERC20APX public apexiaToken;
    IERC20APX public peakToken;
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant POOL_ROLE = keccak256("POOL_ROLE");

    enum Pools {
        matchingBonusPool,
        ownersPool,
        balancerPool
    }
    
    uint256 private decimals = 18;
    uint256 private tetherDesimals = 6;
    uint256 private percentageDecimal = 5; 

    bool public addingOldUsers;
    uint256 public initialPrice;
    uint256 public currentPrice; // use 18 decimal
    address[] public poolAddresses;

    struct UserData {
        uint256[] packageIds;
        uint256[] purchaseTime;
        uint256 totalPurchase; // tether 
    }
    // Struct for package details
    struct Package {
        string name;
        uint256 tetherAmount;
        uint256 ownerPurchaseWage; 
        uint256 tokenPlanWage;
        uint256 networkPlanWage;
        uint256 tokenOwnerWage; 
        uint256 tokenIncreaseRate; 
        bool status;
    }

    // Array to store all packages
    Package[] internal packages;
    address[] internal userAddresses;
    mapping(address => UserData) private userPurchaseHistory;


    // event
    event PoolAddressUpdated(Pools indexed poolNumber, address poolAddress);

    event PackageAdded(uint256 indexed packageId, string packageName, uint256 tetherAmount);
    event PackageStatusUpdated(uint256 indexed packageId, string packageName, bool Status);
    event PriceUpdated(uint256 newPrice);
    event TetherDeposited(uint256 indexed txId, address indexed user, uint256 indexed packageId, uint256 amount);
    event Withdrawal(address indexed poolAddress, address indexed user, uint256 amount);
    event poolBalanceUpdated( address indexed poolAddress, address indexed senderAddress, uint256 amount);
    event OldUsersAdded(address[] oldUser);
    event EndOfUsersDataMigration(uint256 time, bool state);
    event TokenPriceUpdatedByUser(address user, uint256 amount, uint256 price);

    constructor(address defaultAdmin, address operator, address _tetherToken, address _apexiaToken, address _peakToken, uint256 _initialPrice) {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(OPERATOR_ROLE, operator);
        tetherToken = IERC20_USDT(_tetherToken);
        apexiaToken = IERC20APX(_apexiaToken);
        peakToken = IERC20APX(_peakToken);
        initialPrice = _initialPrice;
        currentPrice = _initialPrice;
        poolAddresses = new address[](3);
        addingOldUsers = true;
    }

    function setPoolAddresses(address[] memory _poolAddresses) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_poolAddresses.length == 3, "Must provide exactly 3 addresses"); 

        for (uint i = 0; i < _poolAddresses.length; i++) {
            require(_poolAddresses[i] != address(0), "Invalid address provided");
            poolAddresses[i] = _poolAddresses[i];
            grantRole(POOL_ROLE, _poolAddresses[i]);
            emit PoolAddressUpdated(Pools(i), _poolAddresses[i]);
        }
    }

    function updatePoolAddress(Pools _poolNumber, address _poolAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_poolAddress != address(0), "Invalid address");
        revokeRole(POOL_ROLE,poolAddresses[uint(_poolNumber)]);
        poolAddresses[uint(_poolNumber)] = _poolAddress;
        grantRole(POOL_ROLE, _poolAddress);
        emit PoolAddressUpdated(_poolNumber, _poolAddress);
    }

    // Function for the owner to add a new package (immutable once added)
    function addPackage(string memory _name, uint256 _tetherAmount, uint256 _ownerPurchaseWage,uint256 _tokenPlanWage, uint256 _networkPlanWage, uint256 _tokenOwnerWage, uint256 _tokenIncreaseRate) external onlyRole(OPERATOR_ROLE) {
        require((_tokenPlanWage + _networkPlanWage) == 100000, "Total must be 1");
        packages.push(Package({
            name: _name,
            tetherAmount: _tetherAmount,
            ownerPurchaseWage: _ownerPurchaseWage,
            tokenPlanWage: _tokenPlanWage,
            networkPlanWage: _networkPlanWage,
            tokenOwnerWage: _tokenOwnerWage,
            tokenIncreaseRate: _tokenIncreaseRate,
            status: true
        }));
        emit PackageAdded(packages.length - 1, _name, _tetherAmount);
    }

    // Deactive or active a package
    function changePackageStatus(uint256 _packageId, bool _status) external onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        Package storage _package = packages[_packageId];
        if (_status) {
            _package.status = _status;
        } else {
            _package.status = _status;
        }
        emit PackageStatusUpdated(_packageId, _package.name, _package.status);
        return true;
    }

    // Function to deposit USDT and receive an equivalent amount of custom tokens
    function buy(uint256 _packageId, uint256 _txId) public {
        require(_packageId < packages.length, "Invalid package");
        Package storage _package = packages[_packageId];
        require(_package.status, "Package is not active.");
        
        uint256 mintAmount = 0;
        uint256 _tetherAmount = _package.tetherAmount;
        uint256 ownerAmount = (_tetherAmount * _package.ownerPurchaseWage) / 100000;
        uint256 recivedAmount = _tetherAmount + ownerAmount;

        require(tetherToken.allowance(msg.sender, address(this)) >= recivedAmount, "Token allowance not enough");
        require(tetherToken.balanceOf(msg.sender) >= recivedAmount, "Insufficient token balance");
        tetherToken.transferFrom(msg.sender, address(this), recivedAmount);

        if (_package.networkPlanWage != 0) {
            // calculating network amount
            uint256 networkPlaneAmount = (_tetherAmount * _package.networkPlanWage) / 100000;
            uint256 matchingBonusAmount = (networkPlaneAmount * 40000) / 100000;
            uint256 balancerAmount =(networkPlaneAmount * 50000) / 100000;
            ownerAmount += (networkPlaneAmount * 10000) / 100000;

            // transfer tether to the matchingBonusPool and balancerPool
            tetherToken.transfer(poolAddresses[uint256(Pools.matchingBonusPool)], matchingBonusAmount);
            emit poolBalanceUpdated(poolAddresses[uint256(Pools.matchingBonusPool)], address(this), matchingBonusAmount);
            tetherToken.transfer(poolAddresses[uint256(Pools.balancerPool)], balancerAmount);
            emit poolBalanceUpdated(poolAddresses[uint256(Pools.balancerPool)], address(this), balancerAmount);
            // transfer peak token to the buyer
            uint256 peakTokenAmount = networkPlaneAmount * 10 ** 12;
            peakToken.mint(msg.sender, peakTokenAmount);

        }
        if (_package.tokenPlanWage != 0) {
            // calculating mint amount
            uint256 tokenPlaneAmount = (_tetherAmount * _package.tokenPlanWage) / 100000;
            uint256 tokenOwnerAmount = (tokenPlaneAmount * _package.tokenOwnerWage) / 100000; 
            uint256 tokenIncreasevalue = (tokenPlaneAmount * _package.tokenIncreaseRate) / 100000;
            uint256 userTokenPlaneAmount = tokenPlaneAmount - tokenOwnerAmount - tokenIncreasevalue;
            ownerAmount += tokenOwnerAmount;
            
            _mintToken(msg.sender, userTokenPlaneAmount);
            _updatePrice(tokenIncreasevalue);
        }
        
        tetherToken.transfer(poolAddresses[uint256(Pools.ownersPool)], ownerAmount);
        emit poolBalanceUpdated(poolAddresses[uint256(Pools.ownersPool)], address(this), ownerAmount);
        if (userPurchaseHistory[msg.sender].totalPurchase == 0 ){
            userAddresses.push(msg.sender);
        }
        userPurchaseHistory[msg.sender].packageIds.push(_packageId);
        userPurchaseHistory[msg.sender].purchaseTime.push(block.timestamp);
        userPurchaseHistory[msg.sender].totalPurchase += _tetherAmount;
        emit TetherDeposited(_txId, msg.sender, _packageId, mintAmount);  
    }

    function poolWithdrawal(address receiver, uint256 _amount) public onlyRole(POOL_ROLE) returns (bool) {
        uint256 _tokenIncreasevalue = (_amount * 2)/100;
        _mintToken(receiver, (_amount- _tokenIncreasevalue));
        _updatePrice(_tokenIncreasevalue);
        return (true);
    }
    
    function updateTokenPriceOnlyPools(uint256 _amount) external onlyRole(POOL_ROLE) returns (bool) {
        _updatePrice(_amount);
        return (true);
    }

    function updateTokenPrice(uint256 _amount) public returns (bool) {
        require(tetherToken.allowance(msg.sender, address(this)) >= _amount, "Token allowance not enough");
        require(tetherToken.balanceOf(msg.sender) >= _amount, "Insufficient token balance");
        tetherToken.transferFrom(msg.sender, address(this), _amount);

        _updatePrice(_amount);
        emit TokenPriceUpdatedByUser(msg.sender, _amount, currentPrice);
        return (true);
    }

    function addOldUsers(UserData[] memory _userData, address[] memory _userAddress) public onlyRole(OPERATOR_ROLE) {
        require(_userData.length ==  _userAddress.length, "Wrong length");
        require(addingOldUsers, "Adding old users is disabled");
        
        for (uint i = 0; i < _userData.length; i++) {
            UserData memory userData = _userData[i];
            if (userPurchaseHistory[_userAddress[i]].totalPurchase == 0 ){
                userAddresses.push(_userAddress[i]);
            }
            userPurchaseHistory[_userAddress[i]].packageIds = userData.packageIds;
            userPurchaseHistory[_userAddress[i]].purchaseTime = userData.purchaseTime;
            userPurchaseHistory[_userAddress[i]].totalPurchase = userData.totalPurchase;
        }
        emit OldUsersAdded(_userAddress);
    }

    function endOfUsersDataMigration() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(addingOldUsers, "Already disabled");
        addingOldUsers = false;
        emit EndOfUsersDataMigration(block.timestamp, addingOldUsers);
    }

    //mint
    function _mintToken(address to, uint256 _tetherAmount) internal {
        uint256 mintAmount = (_tetherAmount * (10 ** uint256(30))) / currentPrice ;
        apexiaToken.mint(to, mintAmount);
    }

    // update price
    function _updatePrice(uint256 _tokenIncreasevalue) internal {
        if(apexiaToken.totalSupply() == 0) {
            currentPrice = initialPrice;
        } else {
            currentPrice +=  ((_tokenIncreasevalue * (10 ** uint256(30)))/ apexiaToken.totalSupply());
        }
        emit PriceUpdated(currentPrice);
    }

    //sell
    function sell(uint256 _amount) public {
        require(apexiaToken.balanceOf(msg.sender) >= _amount, "Insufficient token balance");
        UserData memory userHistory = userPurchaseHistory[msg.sender];
        require(userHistory.totalPurchase != 0, "You are not user");
        apexiaToken.burn(msg.sender, _amount);

        uint256 tetherAmount = (currentPrice * _amount) / (10 ** uint256(30));
        uint256 sellWage = (tetherAmount * 2) / 100;

        _updatePrice(sellWage/2);
        
        tetherToken.transfer(poolAddresses[uint256(Pools.ownersPool)], (sellWage/2));
        emit poolBalanceUpdated(poolAddresses[uint256(Pools.ownersPool)], address(this), (sellWage/2));
        tetherToken.transfer(msg.sender, (tetherAmount - sellWage));
        emit Withdrawal(address(this), msg.sender, _amount);
    }

    // view functions
    // Function to get the total number of packages available
    function getPackagesCount() public view returns (uint256) {
        return packages.length;
    }

    // Function to get details of a specific package
    function getPackageDetails(uint256 packageId) public view returns (Package memory) {
        require(packageId < packages.length, "Invalid package");
        return packages[packageId];
    }

    // get OwnerPoolAddress
    function getOwnerPoolAddress() public view returns(address ownerPool) {
        return poolAddresses[uint256(Pools.ownersPool)];
    }

    function getMatchingBonusPoolAddress() public view returns(address matchingBonusPool) {
        return poolAddresses[uint256(Pools.matchingBonusPool)];
    }

    function getBalancerPoolAddress() public view returns(address balancerPool) {
        return poolAddresses[uint256(Pools.balancerPool)];
    }

    function getAllUsers() public view returns (address[] memory) {
        return (userAddresses);
    }
        
    function getUserHistory(address _user) public view returns (UserData memory) {
        return userPurchaseHistory[_user];
    }
}