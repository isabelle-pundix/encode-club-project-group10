// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { MembershipManager } from "./MembershipManager.sol";

contract EventManager is Ownable {
    uint256 private eventId;
    MembershipManager public memberShipManager;
    using SafeERC20 for ERC20;

    /**
     * @notice Maps eventId to list of registered users
     */
    mapping(uint256=>address[]) public registeredUsers;

    mapping(uint256=>Event) public events;

    enum Tier {
        Bronze,
        Silver,
        Gold
    }

    /**
     * struct to define an event
     * @param eventId event id number
     * @param name event name
     * @param ticketPrice price of the ticket
     * @param currency token to buy ticket
     * @param minimumTierRequired Gold membership can join Siler or Bronze tier required, not vice versa
     */
    struct Event {
        uint256 id;
        string name;
        uint256 ticketPrice;
        address currency;
        tier minimumTierRequired;
    }

    event EventCreated(uint256 eventId, string name);

    event RegisterSuccess(uint256 eventId, address user);

    constructor(address owner, address _memberShipManager) Ownable(owner) {
        memberShipManager = _memberShipManager;
    }

    /**
     * @notice create new event, only the owner of EventManager contract can create new event 
     * @param name event name
     */
    function createEvent(string calldata name, uint256 ticketPrice, adderss currency, Tier minimumTierRequired) public onlyOwner{
        // TODO: check currency is a ERC20 token
        eventId++;
        ev = Event(eventId, name, ticketPrice, currency, minimumTierRequired);
        emit EventCreated(eventId, name);
    }

    /**
     * register to join an event 
     * if user have a membershipNFT, they can register
     * otherwise they have to buy a single ticket
     * @param eventId event id to register
     */
    function register(uint256 _eventId) public {
        require(_eventId < eventId, "The event does not exists");
        ev = events[eventId];

        require(memberShipManager.checkMembership(msg.sender, ev.minimumTierRequired), "user without membership cannot register");

        users = registeredUsers[eventId];
        users.push(msg.sender);

        emit RegisterSuccess(eventId, msg.sender);
    }

    /**
     * buy a ticket if you don't have a membership 
     * @param eventId event id to buy ticket
     */
    function buyTicket(uint256 eventId) public {
        ev = events[eventId];
        // if event is free to join, just add them to the list
        if (ev.ticketPrice > 0) {
            ERC20(ev.currency).safeTransferFrom(msg.sender, address(this), ev.ticketPrice);
        }
        users = registeredUsers[eventId];
        users.push(msg.sender);
        emit RegisterSuccess(eventId, msg.sender);
    }
}