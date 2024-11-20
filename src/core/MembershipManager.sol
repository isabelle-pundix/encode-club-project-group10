// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/access/Ownable.sol";
import {MembershipNFT} from "./MembershipNFT.sol";
import {ERC20TokenManager} from "./MembershipToken.sol";

contract MembershipManager is Ownable {
    MembershipNFT public membershipNFT;
    ERC20TokenManager public membershipToken;

    string public baseUriBronze;
    string public baseUriSilver;
    string public baseUriGold;

    /// @dev keccak256(bytes("InvalidUserAddress()"))
    uint256 private constant INVALID_USER_ADDRESS_SIG =
        0x702b3d90f44158a18c5c3e31f1a4b131a521a8262feaaa50809661550c6b0e87;

    /// @dev keccak256(bytes("InvalidBlockTimestamp()"))
    uint256 private constant INVALID_BLOCK_TIMESTAMP_SIG =
        0x4d0b0a4110e47e6169f53a1d2245341e3c0cc953a0850be747e8bd710ff9daa3;

    /// @dev keccak256(bytes("InvalidTier()"))
    uint256 private constant INVALID_TIER_SIG = 0xabc;

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
     */
    mapping(uint256 => Membership) public memberships;

    uint256 private tokenIdCounter;

    event Subscribed(address user, uint256 tokenId, uint256 expiry, Tier tier);

    constructor(
        address _membershipNFT,
        address _membershipToken,
        string memory _baseUriBronze,
        string memory _baseUriSilver,
        string memory _baseUriGold
    ) Ownable(msg.sender) {
        membershipNFT = MembershipNFT(_membershipNFT);
        membershipToken = ERC20TokenManager(_membershipToken);

        baseUriBronze = _baseUriBronze;
        baseUriSilver = _baseUriSilver;
        baseUriGold = _baseUriGold;
    }

    /**
     * @notice Sets the base URIs for each membership tier.
     */
    function setBaseUris(
        string memory _baseUriBronze,
        string memory _baseUriSilver,
        string memory _baseUriGold
    ) external onlyOwner {
        baseUriBronze = _baseUriBronze;
        baseUriSilver = _baseUriSilver;
        baseUriGold = _baseUriGold;
    }

    /**
     * @dev Subscribe a user to a membership.
     * Mints an ERC721 token and assigns membership metadata.
     * @param user The address of the user subscribing.
     * @param expiry The expiry time of the membership.
     * @param tier The tier of the membership (0 = Bronze, 1 = Silver, 2 = Gold).
     */
    function subscribe(
        address user,
        uint256 expiry,
        Tier tier,
        uint256 numTokens
    ) external onlyOwner {
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

        membershipToken.transferFrom(user, address(this), numTokens);

        uint256 tokenId = tokenIdCounter++;

        string memory tokenUri = _generateTokenUri(tier, tokenId);

        membershipNFT.safeMint(user, tokenId, tokenUri);

        memberships[tokenId] = Membership({expiry: expiry, tier: tier});

        emit Subscribed(user, tokenId, expiry, tier);
    }

    /**
     * @dev Generates a unique token URI based on the tier and tokenId.
     * @param tier The membership tier.
     * @param tokenId The ID of the token being minted.
     */
    function _generateTokenUri(
        Tier tier,
        uint256 tokenId
    ) internal view returns (string memory) {
        if (tier == Tier.Bronze) {
            return string(abi.encodePacked(baseUriBronze, tokenId));
        } else if (tier == Tier.Silver) {
            return string(abi.encodePacked(baseUriSilver, tokenId));
        } else if (tier == Tier.Bronze) {
            return string(abi.encodePacked(baseUriBronze, tokenId));
        } else {
            assembly {
                mstore(0x00, INVALID_TIER_SIG)
                revert(0x1c, 0x04)
            }
        }
    }

    /**
     *
     * @param _user to check membership
     * @param _tier tier to check
     */
    function checkMembership(
        address _user,
        Tier _tier
    ) public pure returns (bool) {
        return true;
    }
}
