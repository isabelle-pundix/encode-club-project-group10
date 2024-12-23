// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import {MembershipNFT} from "./MembershipNFT.sol";
import {ERC20TokenManager} from "./MembershipToken.sol";

contract MembershipManager is Ownable {
    MembershipNFT public membershipNFT;
    ERC20TokenManager public membershipToken;
    address public multiSigWallet;

    string public baseUriBronze;
    string public baseUriSilver;
    string public baseUriGold;

    /// @dev keccak256(bytes("InvalidBlockTimestamp()"))
    uint256 private constant INVALID_BLOCK_TIMESTAMP_SIG =
        0x4d0b0a4110e47e6169f53a1d2245341e3c0cc953a0850be747e8bd710ff9daa3;

    /// @dev keccak256(bytes("InvalidTier()"))
    uint256 private constant INVALID_TIER_SIG =
        0xe14236173d4f5600d7f126a48aa8c8fbafc0bd654dcfc3c9dfb84a5145cb00b2;

    /// @dev keccak256(bytes("ZeroBalance()"))
    uint256 private constant ZERO_BALANCE_SIG =
        0x669567ea45849e2be6dd4df6e83e9e07b5ea429935d0a5a24f25812fa72480b4;

    /// @dev keccak256(bytes("MembershipStillActive()"))
    uint256 private constant MEMBERSHIP_STILL_ACTIVE_SIG =
        0xf42c5e24db9eab31ca356bd1ad75ec255cdc236e0a816e678ccf8a7f1be71528;

    /// @dev keccak256(bytes("InvalidOwner()"))
    uint256 private constant INVALID_OWNER_SIG =
        0x49e27cffb37b1ca4a9bf5318243b2014d13f940af232b8552c208bdea15739da;

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
    event WithdrawnFunds(uint256 tokenAmount);
    event RenewedMembership(
        address user,
        uint256 tokenId,
        uint256 expiry,
        Tier tier
    );

    constructor(
        address _membershipNFT,
        address _membershipToken,
        string memory _baseUriBronze,
        string memory _baseUriSilver,
        string memory _baseUriGold,
        address _multiSigWallet
    ) Ownable(msg.sender) {
        membershipNFT = MembershipNFT(_membershipNFT);
        membershipToken = ERC20TokenManager(_membershipToken);

        baseUriBronze = _baseUriBronze;
        baseUriSilver = _baseUriSilver;
        baseUriGold = _baseUriGold;

        multiSigWallet = _multiSigWallet;
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
     * @param expiry The expiry time of the membership.
     * @param tier The tier of the membership (0 = Bronze, 1 = Silver, 2 = Gold).
     * @param numTokens The number of ERC20 tokens required.
     */
    function subscribe(uint256 expiry, Tier tier, uint256 numTokens) external {
        if (expiry <= block.timestamp) {
            assembly {
                mstore(0x00, INVALID_BLOCK_TIMESTAMP_SIG)
                revert(0x1c, 0x04)
            }
        }

        membershipToken.transferFrom(msg.sender, address(this), numTokens);

        uint256 tokenId = tokenIdCounter++;

        string memory tokenUri = _generateTokenUri(tier, tokenId, expiry);

        membershipNFT.safeMint(msg.sender, tokenId, tokenUri);

        memberships[msg.sender][tier] = Membership({
            expiry: expiry,
            tier: tier,
            tokenId: tokenId
        });

        emit Subscribed(msg.sender, tokenId, expiry, tier);
    }

    /**
     * @dev Generates a unique token URI based on the tier and tokenId.
     * @param tier The membership tier.
     * @param tokenId The ID of the token being minted.
     */
    function _generateTokenUri(
        Tier tier,
        uint256 tokenId,
        uint256 expiry
    ) public view returns (string memory) {
        string memory baseUri;

        if (tier == Tier.Bronze) {
            baseUri = baseUriBronze;
        } else if (tier == Tier.Silver) {
            baseUri = baseUriSilver;
        } else if (tier == Tier.Gold) {
            baseUri = baseUriGold;
        } else {
            assembly {
                mstore(0x00, INVALID_TIER_SIG)
                revert(0x1c, 0x04)
            }
        }

        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name":"Membership #',
                                tokenId,
                                '", "description":"Membership with ',
                                _tierToString(tier),
                                ' benefits.", "expiry": "',
                                expiry,
                                '", "image":"',
                                baseUri,
                                '", "tier": "',
                                _tierToString(tier),
                                '"}'
                            )
                        )
                    )
                )
            );
    }

    /**
     * @dev Converts a `Tier` enum value to its corresponding string representation.
     * @param tier The `Tier` enum value to convert (Bronze, Silver, or Gold).
     */
    function _tierToString(Tier tier) internal pure returns (string memory) {
        if (tier == Tier.Bronze) {
            return "Bronze";
        } else if (tier == Tier.Silver) {
            return "Silver";
        } else if (tier == Tier.Gold) {
            return "Gold";
        }
        return "";
    }

    /**
     * @notice Withdraws all ERC20 tokens from the contract to the multisig wallet.
     * @dev Can only be called by the contract owner.
     */
    function withdraw() external onlyOwner {
        uint256 balance = membershipToken.balanceOf(address(this));

        if (balance == 0) {
            assembly {
                mstore(0x00, ZERO_BALANCE_SIG)
                revert(0x1c, 0x04)
            }
        }

        membershipToken.transfer(multiSigWallet, balance);
        emit WithdrawnFunds(balance);
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

    /**
     * @notice Renews an expired membership by extending its expiry and updating metadata.
     * @param tier The tier of the membership being renewed (0 = Bronze, 1 = Silver, 2 = Gold).
     * @param newExpiry The new expiry time for the membership.
     * @param numTokens The number of tokens required for the renewal.
     */
    function renewMembership(
        Tier tier,
        uint256 tokenId,
        uint256 newExpiry,
        uint256 numTokens
    ) external {
        if (membershipNFT.ownerOf(tokenId) != msg.sender) {
            assembly {
                mstore(0x00, INVALID_OWNER_SIG)
                revert(0x1c, 0x04)
            }
        }

        Membership memory membership = memberships[msg.sender][tier];

        if (membership.expiry >= block.timestamp) {
            assembly {
                mstore(0x00, MEMBERSHIP_STILL_ACTIVE_SIG)
                revert(0x1c, 0x04)
            }
        }

        if (newExpiry <= block.timestamp) {
            assembly {
                mstore(0x00, INVALID_BLOCK_TIMESTAMP_SIG)
                revert(0x1c, 0x04)
            }
        }

        membershipToken.transferFrom(msg.sender, address(this), numTokens);

        membership.expiry = newExpiry;

        string memory newTokenUri = _generateTokenUri(tier, tokenId, newExpiry);

        membershipNFT.update(tokenId, newTokenUri);

        memberships[msg.sender][tier] = Membership({
            expiry: newExpiry,
            tier: tier,
            tokenId: tokenId
        });

        emit RenewedMembership(msg.sender, tokenId, newExpiry, tier);
    }
}
