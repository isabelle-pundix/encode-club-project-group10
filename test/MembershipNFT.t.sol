// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {MembershipNFT} from "src/core/MembershipNFT.sol";
import {console} from "forge-std/console.sol";


contract MembershipNFTTest is Test {
    MembershipNFT public instance;

    function setUp() public {
        address initialOwner = vm.addr(1);
        instance = new MembershipNFT(initialOwner);
    }

    function test_Name() public view {
        assertEq(instance.name(), "MemberShipNFT");
    }


}

