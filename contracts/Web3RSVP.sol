// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract Web3RSVP {
        //defining events - from here 
        event NewEventCreated( 
            bytes32 eventID,
            address creatorAddress,
            uint256 eventTimestamp,
            uint256 maxCapacity,
            uint256 deposit,
            string eventDataCID
        );

    event NewRSVP(bytes32 eventID, address attendeeAddress);

    event ConfirmedAttendee(bytes32 eventID, address attendeeAddress);

    event DepositsPaidOut(bytes32 eventID);
    //defining events till here 

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
        emit NewEventCreated( 
            eventId,
            msg.sender,
            eventTimestamp,
            maxCapacity,
            deposit,
            eventDataCID
        ); //once all steps in this function are over, we emit this event to store it in logs and for subgraph to listen

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

            myEvent.confirmedRSVPs.push(payable(msg.sender)); // payable(msg.sender) takes the ethers sent in the transation by the sender and adds it to our smart contract

        // The payable() function ensures that the ethers that were sent with the transaction are transferred to the smart contract when the sender's address is added to the list of confirmed RSVPs for the event.
            emit NewRSVP(eventId, msg.sender); //once all steps in this function are over, we emit this event to store it in logs and for subgraph to listen
        } 
        // msg is special variables available to all functions-contains info about the transaction that is calling the function. msg.value gives the Ethers sent. 
        //block is special variable that is available to all functions which contains info of the blocj where the transaction is executed in.block.timestamp gives the timestamp of the block that the transaction is executed in 
        
        
        function confirmAttendee(bytes32 eventId, address attendee) public payable { //pays the attendee if they have RSVP'd already and now checked in, and then add them to the claimedRSVPs list 
            // look up event from our struct using the eventId
            CreateEvent storage myEvent = idToEvent[eventId];

            // require that msg.sender is the owner of the event - only the host should be able to check people in
            require(msg.sender == myEvent.eventOwner, "NOT AUTHORIZED");

            // require that attendee trying to check in actually RSVP'd
            address rsvpConfirm;

            for (uint8 i = 0; i < myEvent.confirmedRSVPs.length; i++) {
                if(myEvent.confirmedRSVPs[i] == attendee){
                    rsvpConfirm = myEvent.confirmedRSVPs[i];
                }
            }

            require(rsvpConfirm == attendee, "NO RSVP TO CONFIRM");


            // require that attendee is NOT already in the claimedRSVPs list AKA make sure they haven't already checked in
            for (uint8 i = 0; i < myEvent.claimedRSVPs.length; i++) {
                require(myEvent.claimedRSVPs[i] != attendee, "ALREADY CLAIMED");
            }

            // require that deposits are not already claimed by the event owner
            require(myEvent.paidOut == false, "ALREADY PAID OUT");

            // add the attendee to the claimedRSVPs list
            myEvent.claimedRSVPs.push(attendee);

            // sending eth back to the staker `https://solidity-by-example.org/sending-ether`
            (bool sent,) = attendee.call{value: myEvent.deposit}("");

            // if this fails, remove the user from the array of claimed RSVPs
            if (!sent) {
                myEvent.claimedRSVPs.pop();
            }

            require(sent, "Failed to send Ether");

            emit ConfirmedAttendee(eventId, attendee);
        }

        function confirmAllAttendees(bytes32 eventId) external {
            // look up event from our struct with the eventId
            CreateEvent memory myEvent = idToEvent[eventId];

            // make sure you require that msg.sender is the owner of the event
            require(msg.sender == myEvent.eventOwner, "NOT AUTHORIZED");

            // confirm each attendee in the rsvp array
            for (uint8 i = 0; i < myEvent.confirmedRSVPs.length; i++) {
                confirmAttendee(eventId, myEvent.confirmedRSVPs[i]); //confirmedRSVPs contains the list of addresses of accounts that have RSVPd to attend the event 
            }
        }

        //withdraw unclaimed deposits post 7 days after the event was over and return back to th event organizer 

        function withdrawUnclaimedDeposits(bytes32 eventId) external payable {
                // look up event
                CreateEvent memory myEvent = idToEvent[eventId];

                // check that the paidOut boolean still equals false AKA the money hasn't already been paid out
                require(!myEvent.paidOut, "ALREADY PAID");

                // check if it's been 7 days past myEvent.eventTimestamp
                require(
                    block.timestamp >= (myEvent.eventTimestamp + 7 days),
                    "TOO EARLY"
                );

                // only the event owner can withdraw
                require(msg.sender == myEvent.eventOwner, "MUST BE EVENT OWNER");

                // calculate how many people didn't claim by comparing
                uint256 unclaimed = myEvent.confirmedRSVPs.length - myEvent.claimedRSVPs.length;

                uint256 payout = unclaimed * myEvent.deposit;

                // mark as paid before sending to avoid reentrancy attack
                myEvent.paidOut = true;

                // send the payout to the owner
                (bool sent, ) = msg.sender.call{value: payout}("");

                // if this fails
                if (!sent) {
                    myEvent.paidOut = false;
                }

                require(sent, "Failed to send Ether");

                emit DepositsPaidOut(eventId);

        }


}