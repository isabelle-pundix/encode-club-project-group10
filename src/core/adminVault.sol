// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract superAdminVault is AccessControl, ReentrancyGuard, Pausable {
    IERC20 public token;
    address public superAdmin;
    uint256 private vaultBalance;

    bytes32 public constant MEMBERSHIP_CONTRACT_ROLE =
        keccak256("MEMBERSHIP_CONTRACT_ROLE");

    event VaultInitialized(uint256 amount);
    event TokensTransferredToAdmin(address indexed admin, uint256 amount);
    event TokensTransferredToUser(
        address indexed from,
        address indexed to,
        uint256 amount
    );

    constructor(address _token) {
        require(_token != address(0), "Zero address not allowed");
        validateAndAssignErc20TOken(_token);
        superAdmin = msg.sender;
        _grantRole(DEFAULT_ADMIN_ROLE, superAdmin);
    }

    function validateAndAssignErc20TOken(
        address _token
    ) internal returns (IERC20) {
        try IERC20(_token).totalSupply() returns (uint256) {
            token = IERC20(token);
            return token;
        } catch {
            revert("Not an ERC20 token");
        }
    }

    modifier onlySuperAdmin() {
        require(
            msg.sender == superAdmin,
            "Only super admin can call this function"
        );
        _;
    }

    function initializeVault(
        uint256 amount
    ) external onlySuperAdmin nonReentrant whenNotPaused {
        require(vaultBalance == 0, "Vault already initialized");
        require(amount > 0, "Amount must be greater than zero");

        require(token.allowance(superAdmin, address(this)) >= amount);

        require(
            token.transferFrom(superAdmin, address(this), amount),
            "Transfer failed"
        );

        vaultBalance = amount;
        emit VaultInitialized(amount);
    }

    function transferToAdmin(
        address admin,
        uint256 amount
    ) external onlySuperAdmin nonReentrant whenNotPaused {
        require(admin != address(0), "Cannot transfer to zero address");
        require(amount > 0, "Amount must be grrater than zero");
        require(vaultBalance >= amount, "Insufficient vault balance");

        vaultBalance -= amount;

        require(token.transfer(admin, amount), "Transfer to admin failed");

        emit TokensTransferredToAdmin(admin, amount);
    }

    function transferToUser(
        address admin,
        address user,
        uint256 amount
    ) external onlyRole(MEMBERSHIP_CONTRACT_ROLE) nonReentrant whenNotPaused {
        require(admin != address(0), "Cannot transfer from zero address");
        require(user != address(0), "Cannot transfer to zero address");
        require(amount > 0, "Amount must be greater than 0");

        require(
            token.allowance(admin, address(this)) >= amount,
            "Insufficient fund"
        );

        require(token.transferFrom(admin, user, amount));

        emit TokensTransferredToUser(admin, user, amount);
    }

    function getVaultBalance() external view returns (uint256) {
        return vaultBalance;
    }

    function recoverErc20Token(
        address tokenAddress,
        uint256 amount
    ) external onlySuperAdmin nonReentrant {
        require(amount > 0, "Amount must be greater than zero");
        IERC20 tokenToRecover = IERC20(tokenAddress);
        require((tokenToRecover.transfer(superAdmin, amount)));
    }
}
