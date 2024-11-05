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
    address public mintAccount;

    bytes32 public constant MEMBERSHIP_CONTRACT_ROLE =
        keccak256("MEMBERSHIP_CONTRACT_ROLE");

    bytes32 public constant MINT_HOLDER_ROLE = keccak256("MINT_HOLDER_ROLE");

    uint256 public constant MAX_INITIALIZATION_AMOUNT = 1000000;

    event VaultInitialized(uint256 amount);
    event TokensTransferredToAdmin(address indexed admin, uint256 amount);
    event TokensTransferredToUser(
        address indexed from,
        address indexed to,
        uint256 amount
    );

    event superAdminTransferred(
        address indexed oldAdmin,
        address indexed newAdmin
    );

    constructor(address _token, address _mintAccount) {
        require(_token != address(0), "Zero address not allowed for token");
        require(
            _mintAccount != address(0),
            "Zero address not allowed for mint account"
        );
        validateAndAssignErc20TOken(_token);
        superAdmin = msg.sender;
        mintAccount = _mintAccount;
        _grantRole(DEFAULT_ADMIN_ROLE, superAdmin);
        _grantRole(MINT_HOLDER_ROLE, mintAccount);
    }

    function validateAndAssignErc20TOken(
        address _token
    ) internal returns (IERC20) {
        try IERC20(_token).totalSupply() returns (uint256) {
            token = IERC20(_token);
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

    function approveVault(
        uint256 amount
    )
        external
        onlyRole(MINT_HOLDER_ROLE)
        nonReentrant
        whenNotPaused
        returns (bool)
    {
        require(msg.sender == mintAccount);
        uint256 mintAccountBalance = getMintAccountBalance();
        require(amount <= mintAccountBalance, "Insufficient fund");
        bool success = token.approve(address(this), amount);
        return success;
    }

    // TODO Help needed, the token is getting approved
    // but the checkAllowance still stands at zero.
    // Therefore the vault could not be initialized

    function getMintAccountBalance() public view returns (uint256 balance) {
        return token.balanceOf(mintAccount);
    }

    function checkAllowance() public view returns (uint256) {
        return token.allowance(mintAccount, address(this));
    }

    function initializeVault(
        uint256 amount
    ) external onlyRole(MINT_HOLDER_ROLE) nonReentrant whenNotPaused {
        require(vaultBalance == 0, "Vault already initialized");
        require(amount > 0, "Amount must be greater than zero");
        require(
            amount <= MAX_INITIALIZATION_AMOUNT,
            "Amount exceeds the maximum amount allowed"
        );

        uint256 balanceBefore = token.balanceOf(address(this));

        require(
            token.transferFrom(mintAccount, address(this), amount),
            "Transfer failed"
        );
        uint256 balanceAfter = token.balanceOf(address(this));

        require(
            balanceAfter - balanceBefore == amount,
            "Transfer amount mismatch"
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

    function pause() external onlySuperAdmin {
        _pause();
    }

    function unpause() external onlySuperAdmin {
        _unpause();
    }

    function recoverErc20Token(
        address tokenAddress,
        uint256 amount
    ) external onlySuperAdmin nonReentrant {
        require(amount > 0, "Amount must be greater than zero");
        IERC20 tokenToRecover = IERC20(tokenAddress);
        require((tokenToRecover.transfer(superAdmin, amount)));
    }

    function transferSuperAdmin(address newSuperAdmin) external onlySuperAdmin {
        require(newSuperAdmin != address(0), "Cannot transfer ro zero address");
        superAdmin = newSuperAdmin;
        emit superAdminTransferred(superAdmin, newSuperAdmin);
    }
}
