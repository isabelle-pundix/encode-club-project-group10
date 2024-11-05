// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract ERC20TokenManager is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    string private _name;
    string private _symbol;

    event MinterAdded(address indexed account);

    constructor(
        string memory tokenName,
        string memory tokenSymbol
    ) ERC20(_name, _symbol) {
        _name = tokenName;
        _symbol = tokenSymbol;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        emit MinterAdded(msg.sender);
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        require(to != address(0), "Cannot mint to zero address");
        require(amount > 0, "Mint amount must be greater than zero");
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyRole(MINTER_ROLE) {
        require(from != address(0), "Cannot burn from zero address");
        _burn(from, amount);
    }
}
