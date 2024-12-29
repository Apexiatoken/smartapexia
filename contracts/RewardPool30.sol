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
    function updateTokenPriceOnlyPools(uint256 _amount) external returns (bool);
}
interface IBONUS_POOL {
    function getPeakPoolAddress() external view returns(address);
}

contract RewardPool30 is AccessControl{
    IERC20_USDT public tetherToken;
    address private mainPoolAddress;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    uint256 public totalAllocated;

    mapping(address => uint256) private userRewardBalances;

    // events
    event userBalanceIncreased(address indexed user, uint256 amount);
    event Withdrawal(address indexed poolAddress, address indexed user, uint256 amount);
    event MainPoolAddressUpdated(address newAddress);

    event SurplusTransferred(address rewardPool, uint256 amount);
    event poolBalanceUpdated(address indexed poolAddress, address indexed senderAddress, uint256 amount);

    constructor(address defaultAdmin, address operator, address _mainPoolAddress, address _tokenAddress) {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(OPERATOR_ROLE, operator);
        mainPoolAddress = _mainPoolAddress;
        tetherToken = IERC20_USDT(_tokenAddress);
    }

    // Function to increase token balance for a user
    function addUser(address _user, uint256 _amount) external onlyRole(OPERATOR_ROLE){
        require(_user != address(0), "Invalid address");
        require(_amount > 0, "Amount must be greater than zero");
        IMAIN_POOL.UserData memory userHistory = IMAIN_POOL(mainPoolAddress).getUserHistory(_user);
        require(userHistory.totalPurchase != 0, "You are not user");

        userRewardBalances[_user] += _amount;
        totalAllocated += _amount;
        emit userBalanceIncreased(_user, _amount);
    }
    
    // Function for users to withdraw their token balance
    function withdrawal(uint256 _amount) external {
        uint256 balance = userRewardBalances[msg.sender];
        require(balance >= _amount, "No balance to withdraw");
        userRewardBalances[msg.sender] -= _amount;
        totalAllocated -= _amount;
        uint256 fee = (_amount * 10) / 100;
        uint256 ownerShare =  (fee * 25)/100;
        uint256 tokenIncreaseShare = (fee * 25)/100;
        uint256 peakPoolShare = (fee * 50)/100;
        uint256 userShare = _amount - fee;

        // transfer token to owner pool
        address ownerPool = IMAIN_POOL(mainPoolAddress).getOwnerPoolAddress();
        tetherToken.transfer(ownerPool, ownerShare );
        
        // transfer token to peak pool
        address matchingBonusPool = IMAIN_POOL(mainPoolAddress).getMatchingBonusPoolAddress();
        address peakPool = IBONUS_POOL(matchingBonusPool).getPeakPoolAddress();
        tetherToken.transfer(peakPool, peakPoolShare);
        
        // transfer token to main pool
        tetherToken.transfer(mainPoolAddress, tokenIncreaseShare);
        require(IMAIN_POOL(mainPoolAddress).updateTokenPriceOnlyPools(tokenIncreaseShare));
        
        // transfer token to user wallet
        tetherToken.transfer(msg.sender, userShare);

        emit poolBalanceUpdated(ownerPool, address(this), ownerShare);
        emit poolBalanceUpdated(peakPool, address(this), peakPoolShare);
        emit poolBalanceUpdated(mainPoolAddress, address(this), tokenIncreaseShare);
        emit Withdrawal(address(this), msg.sender, _amount);
    }
    
    function transferSurplus() external onlyRole(OPERATOR_ROLE) {
        uint256 remainBalance = tetherToken.balanceOf(address(this)) - totalAllocated;
        require(remainBalance > 0, "Nothing to distribute.");
        
        address matchingBonusPool = IMAIN_POOL(mainPoolAddress).getMatchingBonusPoolAddress();
        IERC20_USDT(address(tetherToken)).transfer(matchingBonusPool, remainBalance);
        emit SurplusTransferred(matchingBonusPool, remainBalance);
    }
    
    // change the main pool address
    function changeMainPool(address newAddress) external onlyRole(OPERATOR_ROLE) {
        require(newAddress != address(0), "Invalid address");
        mainPoolAddress = newAddress;
        emit MainPoolAddressUpdated(newAddress);
    }

    // 
    function getMainPoolAddress() external view returns (address) {
        return mainPoolAddress;
    }

    function getMatchingBonusPoolAddress() external view returns (address) {
        return IMAIN_POOL(mainPoolAddress).getMatchingBonusPoolAddress();
    }

    // Function to check the token balance of a user
    function checkBalance(address _user) external view returns (uint256) {
        return userRewardBalances[_user];
    }
}
