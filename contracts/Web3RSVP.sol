// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract Web3RSVP {
    struct CreateEvent {
        bytes32 eventId;
        string eventDataCID;
        address eventOwner;
        uint256 eventTimestamp;
        uint256 deposit;
        uint256 maxCapacity;
        address[] confirmedRSVPs;
        address[] claimedRSVPs;
        bool paidOut;
   }

   mapping(bytes32 => CreateEvent) public idToEvent; //mapping is like hastable. bytes32 is datatype of key and CreateEvent is datatype of value, view is publis, idToEvent is the name of dictionary
   
}