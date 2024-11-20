// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import {ERC20TokenManager} from "../src/core/MembershipToken.sol";

contract MembershipTokenTest is Test {

    address constant OWNER = address(1);
    ERC20TokenManager membershipToken;

    function setUp() public {
        membershipToken = new ERC20TokenManager("test", "TEST");
    }

    /**
     * @dev mint revert
     */
    function test_mint_revert() public {
        vm.expectRevert("Cannot mint to zero address");
        membershipToken.mint(address(0), type(uint256).max / 1000);
    }

    /**
     * @dev mint revert zero amount
     */
    function test_mint_zero_amount() public {
        vm.expectRevert("Mint amount must be greater than zero");
        membershipToken.mint(OWNER, uint256(0));
    }

    /**
     * @dev mint success
     */
    function test_mint() public {
        uint256 mintAmount = 1000_000_000_000_000_000_000; // 1000 token
        membershipToken.mint(OWNER, mintAmount); // mint 1000 token
        assertEq(membershipToken.balanceOf(OWNER), mintAmount);
    }

    /**
     * @dev Test burn revert
     */
    function test_burn_revert() public {
        vm.expectRevert("Cannot burn from zero address");
        membershipToken.burn(address(0), type(uint256).max / 1000);
    }

    /**
     * @dev Test burn success
     */
    function test_burn_success() public {
        uint256 mintAmount = 1000_000_000_000_000_000_000; // 1000 token
        uint256 burnAmount = 900_000_000_000_000_000_000; // 900 token
        membershipToken.mint(OWNER, mintAmount); // mint 1000 token

        membershipToken.burn(OWNER, burnAmount);

        assertEq(membershipToken.balanceOf(OWNER), mintAmount-burnAmount);
    }

}