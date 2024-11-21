// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import {EventManager} from "src/core/EventManager.sol";
import {MembershipManager} from "src/core/MembershipManager.sol";
import {MembershipNFT} from "src/core/MembershipNFT.sol";
import {console} from "forge-std/console.sol";
import {ERC20TokenManager} from "../src/core/MembershipToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract EventManagerTest is Test {
    EventManager public instance;
    MembershipNFT public membershipNFT;
    MembershipManager public membershipManager;
    ERC20TokenManager membershipToken;

    address constant MULTISIG = address(3);

    string public baseUriBronze = "ipfs://bronze/";
    string public baseUriSilver = "ipfs://silver/";
    string public baseUriGold = "ipfs://gold/";
    
    address initialOwner = vm.addr(1);

    function setUp() public {
        membershipNFT = new MembershipNFT(initialOwner);
        membershipToken = new ERC20TokenManager("testToken", "TT");
        membershipManager = new MembershipManager(
            address(membershipNFT),
            address(membershipToken),
            baseUriBronze,
            baseUriSilver,
            baseUriGold,
            MULTISIG
        );
        instance = new EventManager(address(initialOwner), membershipManager);
    }

    /**
     * 
     */
    function test_create_event() public {
        vm.prank(initialOwner);
        instance.createEvent("test", 1000, address(membershipToken), MembershipManager.Tier.Bronze);
    }

    /**
     * @dev test register event revert
     */
    function test_register_event_not_exist() public {
        vm.expectRevert("The event does not exists");
        instance.register(uint256(2));
    }

    /**
     * @dev test buy ticket free
     */
    function test_buy_ticket_free() public {
        uint256 balance;
        membershipToken.mint(initialOwner, 1000000);
        balance = ERC20(membershipToken).balanceOf(initialOwner);
        assertEq(balance, 1000000);

        vm.prank(initialOwner);
        instance.createEvent("first", 0, address(membershipToken), MembershipManager.Tier.Bronze);
        ERC20(membershipToken).approve(address(instance), 1000000);
        instance.buyTicket(1);
    }

}

