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
   //idToEvent is also a state variable and gets pre allocated in storage, not in memory
   
   // createNewEvent function below gets called from front end when users click button for creating new event 
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

    function createNewRSVP(bytes32 eventId) external payable { //payable means this function handles Ethers and most likely to change the state of the smart contract
            // look up event from our mapping
            CreateEvent storage myEvent = idToEvent[eventId];

            // transfer deposit to our contract / require that they send in enough ETH to cover the deposit requirement of this specific event
            require(msg.value == myEvent.deposit, "NOT ENOUGH");

            // require that the event hasn't already happened (<eventTimestamp)
            require(block.timestamp <= myEvent.eventTimestamp, "ALREADY HAPPENED");

            // make sure event is under max capacity
            require(
                myEvent.confirmedRSVPs.length < myEvent.maxCapacity,
                "This event has reached capacity"
            );

            // require that msg.sender isn't already in myEvent.confirmedRSVPs AKA hasn't already RSVP'd
            for (uint8 i = 0; i < myEvent.confirmedRSVPs.length; i++) {
                require(myEvent.confirmedRSVPs[i] != msg.sender, "ALREADY CONFIRMED");
            }

            myEvent.confirmedRSVPs.push(payable(msg.sender));

        } 
        // msg is special variables available to all functions-contains info about the transaction that is calling the function. msg.value gives the Ethers sent. 
        //block is special variable that is available to all functions which contains info of the blocj where the transaction is executed in.block.timestamp gives the timestamp of the block that the transaction is executed in 

}