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

    uint256 private constant INVALID_BLOCK_TIMESTAMP_SIG =
        0x4d0b0a4110e47e6169f53a1d2245341e3c0cc953a0850be747e8bd710ff9daa3;

    uint256 private constant INVALID_TIER_SIG =
        0xe14236173d4f5600d7f126a48aa8c8fbafc0bd654dcfc3c9dfb84a5145cb00b2;

    uint256 private constant ZERO_BALANCE_SIG =
        0x669567ea45849e2be6dd4df6e83e9e07b5ea429935d0a5a24f25812fa72480b4;

    uint256 private constant MEMBERSHIP_STILL_ACTIVE_SIG =
        0xf42c5e24db9eab31ca356bd1ad75ec255cdc236e0a816e678ccf8a7f1be71528;

    uint256 private constant INVALID_OWNER_SIG =
        0x49e27cffb37b1ca4a9bf5318243b2014d13f940af232b8552c208bdea15739da;

    address constant OWNER = address(1);
    address constant USER = address(2);
    address constant MULTISIG = address(3);
    address constant INVALID_USER = address(4);

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
            baseUriGold,
            MULTISIG
        );

        membershipNFT.transferOwnership(address(membershipManager));
        membershipManager.transferOwnership(OWNER);

        membershipToken.mint(USER, initialTokenBalance);
        membershipToken.mint(INVALID_USER, initialTokenBalance);
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

        vm.prank(USER);
        membershipManager.subscribe(expiry, tier, numTokens);

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
        membershipManager.subscribe(expiry, tier, numTokens);
    }

    /**
     * @dev Test successful withdrawal by contract owner
     */
    function testFuzz_Withdraw(uint256 initialSupply) public {
        initialSupply = bound(initialSupply, 1, type(uint256).max / 2);
        membershipToken.mint(address(membershipManager), initialTokenBalance);

        vm.prank(OWNER);
        membershipManager.withdraw();

        assertEq(
            membershipToken.balanceOf(address(membershipManager)),
            0,
            "Contract balance mismatch after withdrawal"
        );
        assertEq(
            membershipToken.balanceOf(MULTISIG),
            initialTokenBalance,
            "Contract balance mismatch after transfer"
        );
    }

    /**
     * @dev Test unsuccessful withdrawal by contract owner
     * if contract ERC20 token balance = 0
     */
    function testFuzz_Withdraw_ZeroBalance() public {
        vm.prank(OWNER);

        vm.expectRevert(
            abi.encodeWithSelector(bytes4(uint32(ZERO_BALANCE_SIG)))
        );
        membershipManager.withdraw();
    }

    /**
     * @dev Test successful renewal of a user to a membership.
     */
    function testFuzz_RenewMembership(
        uint256 renewalExpiry,
        uint8 tierIndex,
        uint256 numTokens
    ) public {
        uint256 initialExpiry = block.timestamp + 1 days;

        renewalExpiry = bound(
            initialExpiry,
            initialExpiry + 1 days,
            initialExpiry + 365 days
        );

        tierIndex = uint8(bound(tierIndex, 0, 2));

        MembershipManager.Tier tier = MembershipManager.Tier(tierIndex);

        numTokens = bound(numTokens, 1, initialTokenBalance);

        membershipToken.mint(USER, numTokens);

        vm.prank(USER);
        membershipToken.approve(address(membershipManager), type(uint256).max);

        vm.prank(USER);
        membershipManager.subscribe(initialExpiry, tier, numTokens);

        skip(initialExpiry);

        (, , uint256 tokenIdStored) = membershipManager.memberships(USER, tier);

        vm.prank(USER);
        membershipManager.renewMembership(
            tier,
            tokenIdStored,
            renewalExpiry,
            numTokens
        );

        (
            uint256 expiryStored,
            MembershipManager.Tier tierStored,

        ) = membershipManager.memberships(USER, tier);

        assertEq(expiryStored, renewalExpiry, "Expiry does not match");
        assertEq(uint256(tierStored), uint256(tier), "Tier does not match");

        string memory expectedUri = membershipManager._generateTokenUri(
            tierStored,
            tokenIdStored,
            expiryStored
        );

        assertEq(
            membershipNFT.tokenURI(tokenIdStored),
            expectedUri,
            "Token URI does not match"
        );
    }

    /**
     * @dev Test unsuccessful renewal of a user to a membership
     * if user still has an active membership
     */
    function testFuzz_RenewMembership_ActiveMembership(
        uint256 renewalExpiry,
        uint8 tierIndex,
        uint256 numTokens
    ) public {
        uint256 initialExpiry = block.timestamp + 1 days;

        renewalExpiry = bound(
            initialExpiry,
            initialExpiry + 1 days,
            initialExpiry + 365 days
        );

        tierIndex = uint8(bound(tierIndex, 0, 2));
        MembershipManager.Tier tier = MembershipManager.Tier(tierIndex);

        numTokens = bound(numTokens, 1, initialTokenBalance);

        membershipToken.mint(USER, numTokens);

        vm.prank(USER);
        membershipToken.approve(address(membershipManager), type(uint256).max);

        vm.prank(USER);
        membershipManager.subscribe(initialExpiry, tier, numTokens);

        (, , uint256 tokenIdStored) = membershipManager.memberships(USER, tier);

        vm.prank(USER);
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(uint32(MEMBERSHIP_STILL_ACTIVE_SIG)))
        );
        membershipManager.renewMembership(
            tier,
            tokenIdStored,
            renewalExpiry,
            numTokens
        );
    }

    /**
     * @dev Test unsuccessful renewal of a user to a membership
     * if expiry is invalid
     */
    function testFuzz_RenewMembership_InvalidExpiry(
        uint8 tierIndex,
        uint256 numTokens
    ) public {
        uint256 initialExpiry = block.timestamp + 1 days;

        tierIndex = uint8(bound(tierIndex, 0, 2));

        MembershipManager.Tier tier = MembershipManager.Tier(tierIndex);

        numTokens = bound(numTokens, 1, initialTokenBalance);

        membershipToken.mint(USER, numTokens);

        vm.prank(USER);
        membershipToken.approve(address(membershipManager), type(uint256).max);

        vm.prank(USER);
        membershipManager.subscribe(initialExpiry, tier, numTokens);

        skip(initialExpiry);

        (, , uint256 tokenIdStored) = membershipManager.memberships(USER, tier);

        vm.prank(USER);
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(uint32(INVALID_BLOCK_TIMESTAMP_SIG)))
        );
        membershipManager.renewMembership(
            tier,
            tokenIdStored,
            initialExpiry,
            numTokens
        );
    }

    /**
     * @dev Test unsuccessful renewal of a user to a membership
     * if user is not NFT owner
     */
    function testFuzz_RenewMembership_InvalidOwner(
        uint256 renewalExpiry,
        uint8 tierIndex,
        uint256 numTokens
    ) public {
        uint256 initialExpiry = block.timestamp + 1 days;

        renewalExpiry = bound(
            initialExpiry,
            initialExpiry + 1 days,
            initialExpiry + 365 days
        );

        tierIndex = uint8(bound(tierIndex, 0, 2));

        MembershipManager.Tier tier = MembershipManager.Tier(tierIndex);

        numTokens = bound(numTokens, 1, initialTokenBalance);

        membershipToken.mint(USER, numTokens);

        vm.prank(USER);
        membershipToken.approve(address(membershipManager), type(uint256).max);

        vm.prank(USER);
        membershipManager.subscribe(initialExpiry, tier, numTokens);

        skip(initialExpiry);

        (, , uint256 tokenIdStored) = membershipManager.memberships(USER, tier);

        vm.prank(INVALID_USER);
        membershipToken.approve(address(membershipManager), type(uint256).max);

        vm.prank(INVALID_USER);
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(uint32(INVALID_OWNER_SIG)))
        );
        membershipManager.renewMembership(
            tier,
            tokenIdStored,
            renewalExpiry,
            numTokens
        );
    }
}
