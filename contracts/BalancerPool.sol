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

contract BalancerPool is AccessControl {
    IERC20_USDT public tetherToken;
    address private mainPoolAddress;
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    mapping(address => uint256) private userBalancerBalances; 

    event NewUserAdded(address indexed user, uint256 amount);
    event Withdrawal(address poolAddress, address indexed user, uint256 amount);
    event poolBalanceUpdated( address indexed poolAddress, address indexed senderAddress, uint256 amount);
    event MainPoolUpdated(address newAddress);

    constructor(address defaultAdmin, address operator, address _mainPoolAddress, address _tokenAddress) {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(OPERATOR_ROLE, operator);
        tetherToken = IERC20_USDT(_tokenAddress);
        mainPoolAddress = _mainPoolAddress;
    }

    // Function to add token balance for a user
    function addUser(address _user, uint256 _amount) external onlyRole(OPERATOR_ROLE){
        require(_user != address(0), "Invalid address");
        require(_amount > 0, "Amount must be greater than zero");
        IMAIN_POOL.UserData memory userHistory = IMAIN_POOL(mainPoolAddress).getUserHistory(_user);
        require(userHistory.totalPurchase != 0, "You are not user");

        userBalancerBalances[_user] += _amount;
        emit NewUserAdded(_user, _amount);
    }

    // Function for users to withdraw their token balance
    function withdrawal(uint256 _amount) external {
        require(_amount > 2000000, "No balance to withdraw");
        uint256 balance = userBalancerBalances[msg.sender];
        require(_amount <= balance, "Insufficient balance");

        userBalancerBalances[msg.sender] -= _amount;
        address ownerPool = IMAIN_POOL(mainPoolAddress).getOwnerPoolAddress();
        tetherToken.transfer(mainPoolAddress, _amount - 1000000);
        tetherToken.transfer(ownerPool, 1000000);

        require(IMAIN_POOL(mainPoolAddress).poolWithdrawal(msg.sender, _amount - 1000000));
        emit poolBalanceUpdated(ownerPool, address(this), 1000000);
        emit poolBalanceUpdated(mainPoolAddress, address(this), _amount - 1000000);
        emit Withdrawal(address(this), msg.sender, _amount);
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
        return userBalancerBalances[_user];
    }
}
