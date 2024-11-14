// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Counters} from "../src/Counter.sol";

contract CounterTest is Test {
    using Counters for Counters.Counter;
    Counters.Counter public counter;

    function setUp() public {}

    function test_CurrentValueIsZero() public {
        assertEq(counter.current(), 0);
    }

    function test_increment() public {
        counter.increment();
        assertEq(counter.current(), 1);

        counter.increment();
        assertEq(counter.current(), 2);
    }

    function test_decrement() public {
        counter.increment();
        counter.increment();
        counter.decrement();
        assertEq(counter.current(), 1);
    }

    function test_decrementReverts() public {
        vm.expectRevert("Counter: decrement overflow");
        counter.decrement();
    }

    function test_counterRest() public {
        counter.increment();
        counter.increment();
        counter.decrement();
        counter.reset();
        assertEq(counter.current(), 0);
    }

    function testFuzz_incrementMany(uint8 count) public {
        uint256 initValue = counter.current();
        for (uint8 i = 0; i < count; i++) {
            counter.increment();
        }

        assertEq(counter.current(), initValue + count);
    }

    function test_decrementMany(uint8 count) public {
        for (uint8 i = 0; i < 5; i++) {
            counter.increment();
        }
        assertEq(counter.current(), 5);
        for (uint8 i = 0; i < 3; i++) {
            counter.decrement();
        }
        assertEq(counter.current(), 2);
    }
}
