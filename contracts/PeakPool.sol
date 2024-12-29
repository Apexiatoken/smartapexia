// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./IERC20APX.sol";

interface IERC20_USDT {
    function transferFrom(address from, address to, uint value) external;
    function transfer( address to, uint value) external;
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract PeakPool is AccessControl{
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    uint256 public constant TWO_YEARS = 730 days; 
    uint256 public numberOfAllowedPolicyUpdates = 3;

    struct Deposit {
        address depositor; // Address of the depositor who made the deposit
        uint256 amount;    // Amount of Tether deposited
        uint256[] timestamp; // Timestamp of the deposit
    }

    IERC20_USDT public tetherToken;
    IERC20APX public peakToken;
    address private mainPoolAddress;
    address public ownerAddress;
    uint256 public deployedAt;

    uint256 public tetherPer100Tokens; // How many Tether per 100 tokens, use 6 as its decimal
    mapping(address => Deposit) private deposits;

    // events
    event TetherDepositedByOwner(address indexed ownerAddress, uint256 amount, uint256 date);
    event TetherDeposited(address indexed ownerAddress, uint256 amount, uint256 date);
    event Exchange(address indexed poolAddress, address indexed user, uint256 peakAmount, uint256 tetherAmount);
    event TetherPolicyUpdated(address indexed ownerAddress, uint256 newPolicy, uint256 date);
    event MainPoolAddressUpdated(address newAddress);

    event poolBalanceUpdated(address indexed poolAddress, address indexed senderAddress, uint256 amount);

    constructor(address defaultAdmin, address operator, address _mainPoolAddress, address _tokenAddress, address _peakToken) {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(OPERATOR_ROLE, operator);
        ownerAddress = msg.sender;
        mainPoolAddress = _mainPoolAddress;
        tetherPer100Tokens = 5000000;
        tetherToken = IERC20_USDT(_tokenAddress);
        peakToken = IERC20APX(_peakToken);
        deployedAt = block.timestamp;
    }

    function depositTether(uint256 _amount) external {
        require(tetherToken.balanceOf(msg.sender) >= _amount, "Insufficient balance");
        require(tetherToken.allowance(msg.sender, address(this)) >= _amount, "Token allowance not enough");
        tetherToken.transferFrom(msg.sender, address(this), _amount);
        
        // Store deposit data
        deposits[msg.sender].depositor = msg.sender;
        deposits[msg.sender].amount += _amount;
        deposits[msg.sender].timestamp.push(block.timestamp);
        if (msg.sender == ownerAddress) {
            emit TetherDepositedByOwner(msg.sender, _amount, block.timestamp);
        } else {
            emit TetherDeposited(msg.sender, _amount, block.timestamp);
        }
        emit poolBalanceUpdated(address(this), msg.sender, _amount);
    }

    // Function for users to withdraw their token balance
    function exchange(uint256 _peakAmount) external {
        require(block.timestamp >= (deployedAt + TWO_YEARS), "Exchage is not available yet.");
        uint256 requiredTetherliquidity = (_peakAmount * tetherPer100Tokens) / (10 ** uint256(20));
        if (requiredTetherliquidity < tetherPer100Tokens) {
            requiredTetherliquidity = tetherPer100Tokens;
        }
        if (msg.sender == ownerAddress ) {
            requiredTetherliquidity = 0;
        }
        Deposit storage userDeposit = deposits[msg.sender];
        require(userDeposit.depositor == msg.sender, "First Deposit Tether.");
        require(userDeposit.amount >= requiredTetherliquidity, "Insufficient Deposited Tether ");
        userDeposit.amount -= requiredTetherliquidity;

        uint256 tokenPrice = ((tetherToken.balanceOf(address(this))) * (10 ** uint256(30))) / (peakToken.totalSupply());
        uint256 tetherAmount = (tokenPrice * _peakAmount) / (10 ** uint256(30));
        
        // burning peak
        peakToken.burn(msg.sender, _peakAmount);
        // transfer token to user wallet
        tetherToken.transfer(msg.sender, tetherAmount);
        emit Exchange(address(this), msg.sender, _peakAmount, tetherAmount);
    }

    // Function to update the policy: Change the number of Tether per 100 tokens, use 6 as desimal
    function updateTetherPolicy(uint256 newTetherPer100Tokens) external onlyRole(OPERATOR_ROLE) {
        require(numberOfAllowedPolicyUpdates > 0, "Policy update not available anymore");
        numberOfAllowedPolicyUpdates -= 1;
        tetherPer100Tokens = newTetherPer100Tokens;
        emit TetherPolicyUpdated(msg.sender, tetherPer100Tokens, block.timestamp);
    }
    
    // change the main pool address
    function changeMainPool(address newAddress) external onlyRole(OPERATOR_ROLE) {
        require(newAddress != address(0), "Invalid address");
        mainPoolAddress = newAddress;
        emit MainPoolAddressUpdated(newAddress);
    }

    function getMainPoolAddress() external view returns (address) {
        return mainPoolAddress;
    }

    function getDepositInfo(address _address) external view returns (Deposit memory) {
        return (deposits[_address]);
    }
}
