// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library Counters {
    struct Counter {
        uint256 value;
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter.value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter.value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 currentValue = counter.value;
        require(currentValue > 0, "Counter: decrement overflow");
        unchecked {
            counter.value -= 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter.value = 0;
    }
}
