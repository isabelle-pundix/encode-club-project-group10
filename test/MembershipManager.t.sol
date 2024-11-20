// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import {MembershipManager} from "../src/core/MembershipManager.sol";
import {MembershipNFT} from "../src/core/MembershipNFT.sol";
import {ERC20TokenManager} from "../src/core/MembershipToken.sol";

contract MembershipManagerTest is Test {
    MembershipManager membershipManager;
    MembershipNFT membershipNFT;
    ERC20TokenManager membershipToken;

    uint256 private constant INVALID_USER_ADDRESS_SIG =
        0x702b3d90f44158a18c5c3e31f1a4b131a521a8262feaaa50809661550c6b0e87;

    uint256 private constant INVALID_BLOCK_TIMESTAMP_SIG =
        0x4d0b0a4110e47e6169f53a1d2245341e3c0cc953a0850be747e8bd710ff9daa3;

    uint256 private constant INVALID_TIER_SIG =
        0xe14236173d4f5600d7f126a48aa8c8fbafc0bd654dcfc3c9dfb84a5145cb00b2;

    address constant OWNER = address(1);
    address constant USER = address(2);

    string public baseUriBronze = "ipfs://bronze/";
    string public baseUriSilver = "ipfs://silver/";
    string public baseUriGold = "ipfs://gold/";

    uint256 initialTokenBalance = 1000000 * 10 ** 18;

    enum Tier {
        Bronze,
        Silver,
        Gold
    }

    function setUp() public {
        membershipNFT = new MembershipNFT(address(this));
        membershipToken = new ERC20TokenManager("MembershipToken", "MT");
        membershipManager = new MembershipManager(
            address(membershipNFT),
            address(membershipToken),
            baseUriBronze,
            baseUriSilver,
            baseUriGold
        );

        membershipNFT.transferOwnership(address(membershipManager));

        membershipToken.mint(USER, initialTokenBalance);
    }

    /**
     * @dev Test successful subscription of a user to a membership.
     *
     */
    function testFuzz_Subscribe(
        uint256 expiry,
        uint8 tierIndex,
        uint256 numTokens
    ) public {
        expiry = bound(
            expiry,
            block.timestamp + 1 days,
            block.timestamp + 365 days
        );

        tierIndex = uint8(bound(tierIndex, 0, 2));
        MembershipManager.Tier tier = MembershipManager.Tier(tierIndex);

        numTokens = bound(numTokens, 1, initialTokenBalance);

        vm.prank(USER);
        membershipToken.approve(address(membershipManager), numTokens);
        membershipManager.subscribe(USER, expiry, tier, numTokens);

        (
            uint256 expiryStored,
            MembershipManager.Tier tierStored,
            uint256 tokenIdStored
        ) = membershipManager.memberships(USER, tier);

        assertEq(expiryStored, expiry, "Expiry does not match");
        assertEq(uint256(tierStored), uint256(tier), "Tier does not match");

        string memory expectedUri = membershipManager._generateTokenUri(
            tierStored,
            tokenIdStored,
            expiry
        );

        assertEq(
            membershipNFT.tokenURI(tokenIdStored),
            expectedUri,
            "Token URI does not match"
        );
    }

    /**
     * @dev Test unsuccessful subscription of a user to a membership
     * if address is invalid
     */
    function testFuzz_Subscribe_InvalidAddress(
        uint256 expiry,
        uint8 tierIndex,
        uint256 numTokens
    ) public {
        expiry = bound(
            expiry,
            block.timestamp + 1 days,
            block.timestamp + 365 days
        );

        tierIndex = uint8(bound(tierIndex, 0, 2));
        MembershipManager.Tier tier = MembershipManager.Tier(tierIndex);
        numTokens = bound(numTokens, 1, initialTokenBalance);

        address user = address(0);

        vm.prank(USER);
        membershipToken.approve(address(membershipManager), numTokens);

        vm.expectRevert(
            abi.encodeWithSelector(bytes4(uint32(INVALID_USER_ADDRESS_SIG)))
        );
        membershipManager.subscribe(user, expiry, tier, numTokens);
    }

    /**
     * @dev Test unsuccessful subscription of a user to a membership
     * if expiry is invalid
     */
    function testFuzz_Subscribe_InvalidExpiry(
        uint256 expiry,
        uint8 tierIndex,
        uint256 numTokens
    ) public {
        expiry = bound(expiry, 0, block.timestamp);

        tierIndex = uint8(bound(tierIndex, 0, 2));
        MembershipManager.Tier tier = MembershipManager.Tier(tierIndex);

        numTokens = bound(numTokens, 1, initialTokenBalance);

        vm.prank(USER);
        membershipToken.approve(address(membershipManager), numTokens);

        vm.expectRevert(
            abi.encodeWithSelector(bytes4(uint32(INVALID_BLOCK_TIMESTAMP_SIG)))
        );
        membershipManager.subscribe(USER, expiry, tier, numTokens);
    }
}
