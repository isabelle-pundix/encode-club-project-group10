// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import {superAdminVault} from "../src/core/SuperAdminVault.sol";
import {ERC20TokenManager} from "../src/core/MembershipToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SuperAdminVaultTest is Test {
    superAdminVault admin;
    ERC20TokenManager membershipToken;

    address OWNER = address(1); // super admin
    address MINT_ACCOUNT = address(2);
    address NEW_SUPER_ADMIN = address(3);

    uint256 mintAmount = 100000000;

    function setUp() public {
        membershipToken = new ERC20TokenManager("test", "TNT");
        admin = new superAdminVault(address(membershipToken), MINT_ACCOUNT);
        membershipToken.mint(MINT_ACCOUNT, mintAmount);
    }

    /**
     * @dev test get mint account balance
     */
    function test_get_mint_account_balance() public view {
        uint256 balance;
        balance = admin.getMintAccountBalance();
        assertEq(balance, mintAmount);
    }

    /**
     * @dev test approve vault
     */
    function test_approve_vault() public {
        bool approved;
        vm.prank(MINT_ACCOUNT);
        approved = admin.approveVault(10000);
        assertEq(approved, true);
    }

    /**
     * @dev test check allowance
     */
    function test_check_allowance() public {
        uint256 allowance; 
        bool approved;
        vm.prank(MINT_ACCOUNT);

        approved = admin.approveVault(10000);
        assertEq(approved, true);

        allowance = admin.checkAllowance();
        assertEq(allowance, 0); // wrong check need FIX
    }

    /**
     * @dev test initialized vault failed
     */
    function test_initialize_vault_failed() public {
        vm.prank(MINT_ACCOUNT);
        vm.expectRevert();
        admin.initializeVault(100);
    }
    /**
     * @dev test initialize vault
     */
    function test_initialize_vault() public {
        vm.prank(MINT_ACCOUNT);
        vm.expectRevert("Amount must be greater than zero");
        admin.initializeVault(0);
    }

    /**
     * @dev test 
     */
    function test_transfer_to_user_failed() public {
        vm.expectRevert(); // not enough balance
        admin.transferToUser(OWNER, MINT_ACCOUNT, 100);
    }

    /**
     * @dev test transfer to admin failed
     */
    function test_transfer_to_admin_failed() public {
        uint256 transferAmount = 100;
        vm.expectRevert(); // not enough balance in vault
        admin.transferToAdmin(MINT_ACCOUNT, transferAmount);
    }

    /**
     * @dev test transfer admin failed
     */
    function test_transfer_admin_failed() public {
        vm.expectRevert("Cannot transfer to zero address");
        admin.transferSuperAdmin(address(0));
    }
    
    /**
     * @dev test transfer admin
     */
    function test_transfer_admin() public {
        address superAdmin;
        admin.transferSuperAdmin(NEW_SUPER_ADMIN);
        superAdmin = admin.superAdmin();
        assertEq(superAdmin, NEW_SUPER_ADMIN);
    }
}