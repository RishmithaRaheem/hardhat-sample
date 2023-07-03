// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract Web3RSVP {
    struct CreateEvent {  // state varaible and hence preallocated in storage 
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
   
   function createNewEvent(uint256 eventTimestamp,  
    uint256 deposit, 
    uint256 maxCapacity, 
    string calldata eventDataCID) external {
        bytes32 eventId = keccak256(
            abi.encodePacked(
                msg.sender,
                address(this),
                eventTimestamp,
                deposit,
                maxCapacity
            )
        );
        require(idToEvent[eventId].eventTimestamp == 0, "ALREADY REGISTERED");

        address[] memory confirmedRSVPs; // array of addresses(Etherium accounts) stored in memory of call stack of function rather than storage of smart contract. Lives only inside the funtion and goes away function returns something, meaning it leaves the function stack
        address[] memory claimedRSVPs; //local in memory variable and doesnt change the state of contract in blockchain 

        // this creates a new CreateEvent struct and adds it to the idToEvent mapping
        idToEvent[eventId] = CreateEvent(
            eventId,
            eventDataCID,
            msg.sender,
            eventTimestamp,
            deposit,
            maxCapacity,
            confirmedRSVPs,
            claimedRSVPs,
            false
        );

    } 
}