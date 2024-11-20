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
    uint256 private constant INVALID_TIER_SIG =
        0xe14236173d4f5600d7f126a48aa8c8fbafc0bd654dcfc3c9dfb84a5145cb00b2;

    enum Tier {
        Bronze,
        Silver,
        Gold
    }

    struct Membership {
        uint256 expiry;
        Tier tier;
        uint256 tokenId;
    }

    /**
     * @notice Maps a user's address to their memberships by token ID.
     * @dev The user address is the outer key and inner key is tokenId.
     * Each token ID corresponds to a `Membership` struct, which stores the details of the membership.
     */
    mapping(address => mapping(Tier => Membership)) public memberships;

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
    ) external {
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

        memberships[user][tier] = Membership({
            expiry: expiry,
            tier: tier,
            tokenId: tokenId
        });

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
        } else if (tier == Tier.Gold) {
            return string(abi.encodePacked(baseUriGold, tokenId));
        } else {
            assembly {
                mstore(0x00, INVALID_TIER_SIG)
                revert(0x1c, 0x04)
            }
        }
    }

    /**
     * @dev Checks if the user has a valid membership of the specified tier.
     * @param _user The address of the user to check.
     * @param _tier The membership tier to check (0 = Bronze, 1 = Silver, 2 = Gold).
     * @return A boolean indicating if the user has a valid membership of the specified tier.
     */
    function checkMembership(
        address _user,
        Tier _tier
    ) public view returns (bool) {
        Membership memory membership = memberships[_user][_tier];
        return membership.expiry > block.timestamp;
    }
}
