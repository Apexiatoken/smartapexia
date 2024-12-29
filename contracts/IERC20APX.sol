// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ERC20 interface for Test token
 * @dev This interface defines functions for interacting with the Test Token contract.
 */

interface IERC20APX {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}