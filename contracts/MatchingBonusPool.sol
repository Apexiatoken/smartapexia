// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

interface IERC20_USDT {
    function transferFrom(address from, address to, uint value) external;
    function transfer( address to, uint value) external;
    function balanceOf(address account) external view returns (uint256);
}

interface IMAIN_POOL {
    struct UserData {
        uint256[] packageIds;
        uint256[] purchaseTime;
        uint256 totalPurchase; // tether 
    }
    function getOwnerPoolAddress() external view returns(address);
    function getMatchingBonusPoolAddress() external view returns(address);
    function getBalancerPoolAddress() external view returns(address);
    function getUserHistory(address _user) external view returns(UserData memory);
    function poolWithdrawal(address receiver, uint256 _amount) external returns (bool);
}

contract MatchingBonusPool is AccessControl{
    IERC20_USDT public tetherToken;
    address private mainPoolAddress;
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    enum RewardPools {
        rewardPool10,
        rewardPool20,
        rewardPool30,
        rewardPool40,
        peakPool
    }
    
    uint256 public totalAllocated;
    address[] private rewardPools;

    mapping(address => uint256) private userMatchingBonusBalances;

    // events
    event userBalanceIncreased(address indexed user, uint256 amount);
    event Withdrawal(address indexed poolAddress, address indexed user, uint256 amount);
    event RewardPoolAddressUpdated(RewardPools indexed poolNumber, address poolAddress);
    event RewardPoolBalanceUpdated(address rewardPool, uint256 amount);
    event poolBalanceUpdated(address indexed poolAddress, address indexed senderAddress, uint256 amount);
    event MainPoolUpdated(address newAddress);

    constructor(address defaultAdmin, address operator, address _mainPoolAddress, address _tokenAddress) {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(OPERATOR_ROLE, operator);
        mainPoolAddress = _mainPoolAddress;
        tetherToken = IERC20_USDT(_tokenAddress);
        rewardPools = new address[](5);
    }

    // Function to increase token balance for a user
    function addUser(address _user, uint256 _amount) external onlyRole(OPERATOR_ROLE){
        require(_user != address(0), "Invalid address");
        require(_amount > 0, "Amount must be greater than zero");
        IMAIN_POOL.UserData memory userHistory = IMAIN_POOL(mainPoolAddress).getUserHistory(_user);
        require(userHistory.totalPurchase != 0, "You are not user");
        userMatchingBonusBalances[_user] += _amount;
        totalAllocated += _amount;
        emit userBalanceIncreased(_user, _amount);
    }
    
    // Function for users to withdraw their token balance
    function withdrawal(uint256 _amount) external {
        require(_amount > 2000000, "No balance to withdraw");
        uint256 balance = userMatchingBonusBalances[msg.sender];
        require(_amount <= balance, "Insufficient balance");

        userMatchingBonusBalances[msg.sender] -= _amount;
        totalAllocated -= _amount;

        address ownerPool = IMAIN_POOL(mainPoolAddress).getOwnerPoolAddress();
        tetherToken.transfer(mainPoolAddress, _amount - 1000000);
        tetherToken.transfer(ownerPool, 1000000);

        require(IMAIN_POOL(mainPoolAddress).poolWithdrawal(msg.sender, _amount - 1000000));
        emit poolBalanceUpdated(ownerPool, address(this), 1000000);
        emit poolBalanceUpdated(mainPoolAddress, address(this), _amount - 1000000);
        emit Withdrawal(address(this), msg.sender, _amount);
    }

    function setRewardPoolAddresses(address[] calldata _poolAddresses) external onlyRole(OPERATOR_ROLE){
        require(_poolAddresses.length == 5, "Must provide exactly 5 addresses"); 

        for (uint i = 0; i < _poolAddresses.length; i++) {
            require(_poolAddresses[i] != address(0), "Invalid address provided");
            rewardPools[i] = _poolAddresses[i];
            emit RewardPoolAddressUpdated(RewardPools(i), _poolAddresses[i]);
        }
    }

    function updateRewardPoolAddress(RewardPools _poolNumber, address _poolAddress) external onlyRole(OPERATOR_ROLE){
        require(_poolAddress != address(0), "Invalid address");
        rewardPools[uint(_poolNumber)] = _poolAddress;
        emit RewardPoolAddressUpdated(_poolNumber, _poolAddress);
    }
    
    function update() external onlyRole(OPERATOR_ROLE) {
        uint256 remainBalance = tetherToken.balanceOf(address(this)) - totalAllocated;
        require(remainBalance > 0, "Nothing to distribute.");
        uint256 rewardAmount = remainBalance / 5;
        
        for (uint i = 0; i < rewardPools.length; i++) {
            require(rewardPools[i] != address(0), "Invalid address provided");
            IERC20_USDT(address(tetherToken)).transfer(rewardPools[i], rewardAmount);
            emit RewardPoolBalanceUpdated(rewardPools[i], rewardAmount);
        }
    }
    
    // change the main pool address
    function changeMainPool(address newAddress) external onlyRole(OPERATOR_ROLE) {
        mainPoolAddress = newAddress;
        emit MainPoolUpdated(newAddress);
    }

    // 
    function getMainPoolAddress() external view returns (address) {
        return mainPoolAddress;
    }

    // Function to check the token balance of a user
    function checkBalance(address _user) external view returns (uint256) {
        return userMatchingBonusBalances[_user];
    }
    
    function getRewardPoolAddress(RewardPools _poolNumber) external view returns (address) {
        return rewardPools[uint(_poolNumber)];
    }

    function getPeakPoolAddress() external view returns (address) {
        return rewardPools[uint256(RewardPools.peakPool)];
    }
}
