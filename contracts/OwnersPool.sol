// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

interface IERC20_USDT {
    function transferFrom(address from, address to, uint value) external;
    function transfer( address to, uint value) external;
    function balanceOf(address account) external view returns (uint256);
}

contract OwnersPool is AccessControl {
    IERC20_USDT public tetherToken;
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    struct Owner {
        uint256 share;
        uint256 balance;
    }

    address[] private owners;
    mapping(address => Owner) private ownerInfo;

    bool private ownersIsSet;
    uint256 public allocatedBalance;

    event OwnerAdded(address indexed owner, uint256 share);
    event Withdrawal(address indexed poolAddress, address indexed owner, uint256 amount);

    modifier updatePool() {
        _update();
        _;
    }

    constructor(address defaultAdmin, address operator, address _tokenAddress) {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(OPERATOR_ROLE, operator);
        tetherToken = IERC20_USDT(_tokenAddress); 
        allocatedBalance = 0;
    }

    function setOwners(address[] memory _ownerAddresses, uint256[] memory _shares) external onlyRole(OPERATOR_ROLE) {
        require(!ownersIsSet, "Owners already set.");
        require(_ownerAddresses.length == _shares.length, "Must provide same length"); 
        uint256 _totalShare; 
        for (uint i = 0; i < _shares.length; i++) {
            _totalShare += _shares[i];
        }
        require(_totalShare == 10, "Invalid shares");
        ownersIsSet= true;
    

        for (uint i = 0; i < _ownerAddresses.length; i++) {
            require(_ownerAddresses[i] != address(0), "Invalid address provided");
            owners.push(_ownerAddresses[i]);
            ownerInfo[_ownerAddresses[i]] = Owner({
                    share: _shares[i],
                    balance: 0
                });
            emit OwnerAdded(_ownerAddresses[i], _shares[i]);
        }
    }

    // only owners can withdrawal tokens
    function withdrawal() external updatePool {
        Owner storage ownerData = ownerInfo[msg.sender];
        uint256 payout = ownerData.balance;
        require(payout > 0, "No funds to claim");

        ownerData.balance = 0;
        tetherToken.transfer(msg.sender, payout);
        allocatedBalance -= payout;
        
        emit Withdrawal(address(this), msg.sender, payout);
    }

    function _update() public {
        uint256 currentBalance = tetherToken.balanceOf(address(this)) - allocatedBalance;

        if (currentBalance > 0) {
            uint256 eachShareAmount = currentBalance / 10;
            for (uint256 i = 0; i < owners.length; i++) {
                address owner = owners[i];
                Owner storage ownerData = ownerInfo[owner];
                uint256 ownerAmount = (eachShareAmount * ownerData.share);
                ownerData.balance += ownerAmount;
            }
        }
        allocatedBalance += currentBalance;
    }

    // view functions
    // Function to get a owner information
    function getOwnerInfo(address _owner) external view returns (Owner memory) {
        return ownerInfo[_owner];
    }

    // Function to get all owners
    function getOwners() external view returns (address[] memory) {
        return owners;
    }
}

