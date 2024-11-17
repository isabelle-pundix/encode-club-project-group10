// SPDX-License-Identifier: MIT
pragma solidity 0.8.22

import "@openzeppelin/contracts/access/Ownable.sol";
import { MembershipNFT } from "./MembershipNFT.sol";

contract MembershipManager is Ownable {
    MembershipNFT public membershipNFT;

    /// @dev keccak256(bytes("InvalidUserAddress()"))
    uint256 private constant INVALID_USER_ADDRESS_SIG = 0x702b3d90f44158a18c5c3e31f1a4b131a521a8262feaaa50809661550c6b0e87;

    /// @dev keccak256(bytes("InvalidBlockTimestamp()"))
    uint256 private constant INVALID_BLOCK_TIMESTAMP_SIG = 0x4d0b0a4110e47e6169f53a1d2245341e3c0cc953a0850be747e8bd710ff9daa3;

    enum Tier {
        Bronze,
        Silver,
        Gold
    }

    struct Membership {
        uint256 expiry;
        Tier tier;
    }

    /**
    * @notice Maps a tokenId to its corresponding membership details.
    * @dev Stores metadata for each ERC721 token, including expiry date and membership tier.
    * @param tokenId The unique identifier of the ERC721 token.
    */
    mapping(uint256 => Membership) public memberships;

    uint256 private tokenIdCounter;

    event Subscribed(address user, uint256 tokenId, uint256 expiry, Tier tier);

    constructor(address _membershipNFT) {
        membershipNFT = _membershipNFT;
    }

    /**
     * @dev Subscribe a user to a membership.
     * Mints an ERC721 token and assigns membership metadata.
     * @param user The address of the user subscribing.
     * @param expiry The expiry time of the membership.
     * @param tier The tier of the membership (0 = Bronze, 1 = Silver, 2 = Gold).
     */
    function subscribe(address user, uint256 expiry, Tier tier) external onlyOwner {
        if (user == address(0)) {
            assembly {
                mstore(0x00, INVALID_USER_ADDRESS_SIG)
                revert(0x1c, 0x04)
            }
        }

        if (expiry <= block.timestamp) {
            assembly {
                mstore(0x00, INVALID_BLOCK_TIMESTAMP_SIG)
                revert(0x1c, 0x04)
            }
        }

        uint256 tokenId = tokenIdCounter++;

        membershipNFT.safeMint(user, tokenId);

        memberships[tokenId] = Membership({
            expiry: expiry,
            tier: tier
        })

        emit Subscribed(user, tokenId, expiry, tier);
    }
}