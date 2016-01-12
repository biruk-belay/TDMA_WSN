#include <Timer.h>
#include "messages.h"
#include <printf.h>


module ApplicationP {

provides {

	interface tdma; 	// This module provides implenetation of the tdam interface
}
uses {

 	interface Timer<T32khz> as TimerBeaconTx; 	// Timer to start beacon transmission at the start of each EPOCH
	interface Timer<T32khz> as Timer_slot_req;	// Timer to start slot requesting task slot at slot one of each EPOCH 
	interface Timer <T32khz>as Timer_chk_beacon;	// Timer to start check beacon task at the start of each EPOCH
	interface Timer <T32khz>as Timer_set_flag;	// Timer to set flag to detect abscence of beacon
       	interface Timer<T32khz> as Timer_send_data;	// Timer to start data sending task
	interface Timer<T32khz> as Radio_on;		// Timer to start Radio
	interface Timer<T32khz> as Timer_init_send;	// Timer to initializing data sending
	interface TimeSyncAMSend<T32khz, uint32_t> as SendBeacon; //For sending beacon (used by the master) 
        interface TimeSyncPacket<T32khz, uint32_t> as TSPacket;	  // 
        interface Receive as ReceiveBeacon;		//For receiving beacons (used by the slaves)
     	interface Receive as receive_pckt;		//For receiving data packets
	interface AMSend as Send;			//For sending beacons
	interface AMSend as Send_data;			//For sending data
	interface AMPacket;				//Packet
	interface SplitControl as AMControl;		//Radio
	interface PacketLink;				//For acknowledgements

}}

implementation {


uint32_t epoch_reference_time;				//local copy of received reference time (keeps being updated incase beacons are lost)
uint32_t received_epoch_reference_time;			//variable to copy received epoch reference time from the packet


uint16_t slot =0;					//variable to hold the slot number
uint8_t i;
uint8_t flag;                                           // flag for checking if a beacon is received at the start of Epoch duration
uint8_t index =0;

message_t beacon;					// Beacon packet
message_t pckt;						// Data packet

bool sending_bcast;					//variable not to overwrite the send buffer
uint8_t first_beacon =1;				//variable to check first beacon (reset after the reception of the first beacon)


slot_DB array [NUM_SLOTS];					// A structure array to holding already assigned slots with the respective node id's owning them
uint8_t buffer [512];					// A buffer to accept data from an upper layer application
uint8_t nodes [NUM_SLOTS];                                      //array track already assigned slots


uint16_t buffer_ptr_application =0;			// a pointer used by the application to track the data 
uint16_t buffer_ptr_tdma = 0;				// a pointer used by the tdma layer to track the data buffer



void assign_slot ( am_addr_t from);
uint8_t already_assigned (uint8_t from);



/*******************************************************************************************************************************************************************
Command: tdma.set_mode()

Parameter: uint8_t

Description: This is an implementation of the the tdma.set_mode interface. If node is a master it starts a periodic timer to broadcast Beacons at the begining of 
every EPOCH_DURATION
********************************************************************************************************************************************************************/

command void tdma.set_mode (uint8_t id) {
	if (id == MASTER) {
	call TimerBeaconTx.startPeriodic (EPOCH_DURATION);
	printf(" master booted \n");		
}}



/*******************************************************************************************************************************************************************
Command: tdma.Send()

Parameter: uint8_t

Description: This is an implementation of the the tdma.send interface. The command inserts data into the buffer for the tdma application to read. The buffer_ptr_application
pointer keeps track of the buffer.
********************************************************************************************************************************************************************/
  
command void tdma.Send (uint8_t data) {

	if (buffer_ptr_application == 512) { // if buffer pointer is above buffer size reset it and fill in data  
		
		buffer_ptr_application =0;
		buffer[buffer_ptr_application] = data;
		buffer_ptr_application++;	
	
	}
	else {
		
		  buffer[buffer_ptr_application] = data;
	     	  buffer_ptr_application++;
	}			    
}


/*********************************************************************************************************************
Event: TimerBeaconTx.fired 
 
Parameter: None

Returns: None

Descritpion: Transmits beacons every Epoch_Duration 
*******************************************************************************************************************/

event void TimerBeaconTx.fired() {
	
	epoch_reference_time = call TimerBeaconTx.getNow();
	printf ("beacond transmitted \n");
	call SendBeacon.send(AM_BROADCAST_ADDR, &beacon, sizeof(BeaconMsg), epoch_reference_time);
}




/***********************************************************************************************************************************************
Event: SendBeacon.sendDone()

Parameter: msg, error_t error

Description: 

*************************************************************************************************************************************************/
  


event void SendBeacon.sendDone(message_t* msg, error_t err) {}


/***********************************************************************************************************************************************
Event: ReceiveBeacon.receive

Parameter: message * (pointer to a packet), pointer to a payload, length of packet

Description: An interface to receive beacons.

-- At each reception of a beacon, the slave extracts the epoch reference time and uses it for synchronization, also a flag is reset which otherwise is incremented at each EPOCH__DURATION during the absence of a beacon.

-- At the first beacon a timer is started to check the arrival of new beacons every EPOCH_DUration. 

-- If the slave hadn't already received a slot, a timer which is supposed to fire at slot 1 to request for a slot is started. 

*************************************************************************************************************************************************/

event message_t* ReceiveBeacon.receive (message_t* msg, void* payload, uint8_t len) {
	
	printf ("Slot in beacon receive %d \n", slot);
	if (call TSPacket.isValid(msg) && len== sizeof(BeaconMsg)){
		
		received_epoch_reference_time = call TSPacket.eventTime(msg);
	
// Start timer to check arrival of beacons at the start of each EPOC_DURATION & reset the first_beacon flag (no more first_beacon)

		if(first_beacon == 1) {

			printf("first beacon \n");
			epoch_reference_time = received_epoch_reference_time;
			call Timer_chk_beacon.startOneShotAt (epoch_reference_time, EPOCH_DURATION+SMALL_OFFSET);
			first_beacon = 0; //reset first_beacon flag

}	

		//call Radio_timer.startOneShotAt(epoch_reference_time, (EPOCH_DURATION-10000));

		flag=0; 		// reset Flag for arrival of Beacons
		call Timer_set_flag.startOneShotAt(received_epoch_reference_time, (EPOCH_DURATION/2)); // Timer to increment flag EPOCH_DURATION/2
		printf("Received beacon \n");
		
		//If no slot is assigned ask the master for a slot on the first slot
		
		if (slot == 0){   	//if slave has no slot start timer which fires at slot 1 i.e official slot for requesting slots
		call Timer_slot_req.startOneShot( (SLOT_DURATION));
		printf ("Sent slot request \n");
}}
	return msg;
}

/************************************************************************************************************************************************************
Event: receive_pckt.receive

Parameter: message * (pointer to a packet), pointer to a payload, length of packet

Description: An interface to receive other packets besides Beacons... i.e packets such as slot request, replies for slot requests and data packets (if master) etc.....

As soon as a slave receives a slot, it starts a one off timer which fires at the start of its assigned slot in the same epoch. When this timer fires it starts another 
periodic timer which will fire after an EPOCH_DURATION i.e exactly at the start of its dedicated slot in the next epoch. 
******************************************************************************************************************************************************************/

event message_t* receive_pckt.receive (message_t* msg, void* payload, uint8_t len) {

 	am_addr_t from;			// source of packet
        Slot_req* request;		//structure to hold slot value
	Data* data;			//structure to hold data value

	from = call AMPacket.source(msg);
	
	
	
	// if this is a packet to request for a Slot 

        if (len== sizeof(Slot_req)) {

                if (IS_MASTER){

                printf ("slot request from %d \n", from);
                assign_slot(from); 	// call function to process request 
		}



		// If this is a reply for a slot request from the master, the local slot variable is updated

                else if (from == MASTER){

                request = (Slot_req*)payload;
                slot = request->slot;
                printf("Received slot %d \n", slot);
		call Timer_init_send.startOneShotAt(epoch_reference_time, slot*SLOT_DURATION);// one off timer which fires at the start of assigned slot
		
		//At this point radio has to be turned off until start of its slot (actually a little before the start of the slot just to give enough time for radio to start)
	
		if (slot!=0) {

		call Radio_on.startOneShotAt(epoch_reference_time, ((slot*SLOT_DURATION)-3));
		call AMControl.stop();
		printf("Recieved slot and now Stopped radio \n");
	}
}
                else {} // else do nothing
		return msg;
}



	// If this is a data packet just extract the data

		else if(len == sizeof(Data)) {
	
		if(IS_MASTER){
			data = (Data*)payload;
			printf ("Received Data %d",data->seqn);
			printf(" from %d \n", from);
			return msg;
}	
	
}

	else printf("Un identified packet type \n");	
	//	AMControl.stop();
	 //	call Radio_timer.startOneShotAt(epoch_reference_time, (EPOCH_DURATION-10000));
		return msg;

}



/***********************************************************************************************************************************************
Event: Timer_slot_req.fired

Parameter: None

Description: This function is executed when the slave receives beacons and isn't assigned a slot yet. Slave just sends a request
*************************************************************************************************************************************************/

event void Timer_slot_req.fired() {

	 error_t status;

 	 printf ("I don't have a slot so sending slot req \n");
	 
	 if (!sending_bcast) {
		 Slot_req* request = call Send.getPayload(&pckt, sizeof(Slot_req));
		 call PacketLink.setRetries(&pckt, NUM_RETRIES);
		 status= call Send.send(MASTER, &pckt, sizeof (Slot_req));
	 }
}


/***********************************************************************************************************************************************
Event: Timer_init_send.fired

Parameter: None

Description: This function is executed after the slave received a slot from the master. It fires at the start of the assigned slot at the same 
epch the slave requested a slot. It then starts a periodic timer which fires at the begninning of the assigned slot after every EPOCH_DURATION

*************************************************************************************************************************************************/

event void Timer_init_send.fired() {
	error_t status;
	
	printf ("Initializing the timer to start sending \n");
	call Timer_send_data.startPeriodic(EPOCH_DURATION);

//	call AMControl.stop();
}



/***********************************************************************************************************************************************
Event: Timer_send_data.fired

Parameter: None

Description: Periodically i.e after each EPOCH_DURATION sends data packets to the Master.  
*************************************************************************************************************************************************/



event void Timer_send_data.fired() {
	
	error_t status;

	if (buffer_ptr_tdma <= buffer_ptr_application){
	
		if (!sending_bcast) {

			
		Data* data = call Send_data.getPayload(&pckt, sizeof(Data));
		  
		printf("I am now gonna send my packet \n");

                call PacketLink.setRetries(&pckt, NUM_RETRIES);		//set retires to NUM_RETRIES
		data->seqn =buffer[buffer_ptr_tdma];			// Send data from data buffer
		buffer_ptr_tdma++;					

		status= call Send_data.send(MASTER, &pckt, sizeof (Data));
	}
}}


/***********************************************************************************************************************************************
Event: Timer_set_flag.fired

Parameter: None

Description: The timer fires and increments the flag variable. This variable is used to track reception of beacons at the start of each EPOCH_DURATION. The flag variable is reset to 0 at the reception of each beacon and if beacons don't arrive at the start of each EPOCH_DURATION the flag variable is incremented until it reaches 5 where afterwards sending of packets is paused until reception of a beacon. 
*************************************************************************************************************************************************/
event void Timer_set_flag.fired() {
//	++flag;
	
	printf(" flag inside set flag %d \n", flag);
	 ++flag;

}


/***********************************************************************************************************************************************
Event: Timer_chk_beacon.fired

Parameter: None

Description: This function is executed at the start of each EPOCH_DURATION with a small forward offset (in this case 1/32 of a second). It monitors the flag and takes decisions

For 5 consecutively lost beacons the reference time is updated locally. If more beacons are lost the slave holds on to forwarding data until reception of beacon. Once beacon shows up it continues sending data without requesting a new slot.
*************************************************************************************************************************************************/


event void Timer_chk_beacon.fired() {
	if (slot !=0) {

	if ( flag ==0) { 	// If flag is 0 Beacon was just received. Continue sending data or start a previously stopped one  

		printf ("flag was reset %d \n",flag);
		epoch_reference_time= received_epoch_reference_time; // Update the old reference time with the newley received one 
	
		if(!(call Timer_send_data.isRunning())){		    // If sending was halted  

			printf("Sending was halted, starting it now \n");
			call Timer_init_send.startOneShotAt(epoch_reference_time, slot*SLOT_DURATION); // start periodic sending timer

	}}


	else if ((flag !=0) && (flag <5)){ 	// Keep updating epoch_ref_time locally before the num of consecutively lost beacons adds upto 5 
	
		epoch_reference_time += EPOCH_DURATION;  // update epoch_ref_time locally
		
		printf ("Beacon wasn't received and the value of the flag is %d\n ", flag);
		++flag;					//Increment flag to keep track of consecutively lost beacons

	}
	

	else {						// The number of lost beacons exceeds 5 so stop sending until reception of beacon

		printf("Halting sending \n");

		if (call Timer_send_data.isRunning()){	// The way to do it is to stop the timer that triggers data sending
			call Timer_send_data.stop();	
				
		}
		
		epoch_reference_time += EPOCH_DURATION; // Keep updating the epoch_reference_time for other functions 

	}
	

	 call Timer_chk_beacon.startOneShotAt (epoch_reference_time, (EPOCH_DURATION+SMALL_OFFSET)); //Start timer to check the presence of beacons at the start of the next EPOCH_DURATON
	


	 
	/*
	 This part is used to check whether there is new data to be sent or all the data from the upper application layer has already been sent. If the later the node wouldn't turn on 
	 it's radio in its next slot

	 Now before exiting from this event check if there is new data from the upper layer application. Buffer_ptr_tdma is a pointer of the data buffer for the tdma component
	 buffer_ptr_application is a pointer to the data buffer for the application. Whenever the application inserts new data it increments the buffer_ptr_application and when 
	 ever the tdma layer reads from the buffer it increments the buffer_ptr_tdma variable.

	 buffer_ptr_tdma <= buffer_ptr_application implies there is still unread data in the buffer and the node can keep sending

	 buffer_ptr_tdma > buffer_ptr_application implies all the data in the buffer has been read and the node doesn't turn on its radio  at the begining of the next slot unless new data
	 arrives	 
	 	 */ 
	 
	 if (buffer_ptr_tdma <= buffer_ptr_application)

		 call Radio_on.startOneShotAt(epoch_reference_time, ((slot*SLOT_DURATION)-RADIO_START_OFFSET)); // If there is data to be sent start radio before the begining of the next slot

	 else {
	 
		 call Radio_on.startOneShotAt(epoch_reference_time, (EPOCH_DURATION-RADIO_START_OFFSET));	// If not start radio before the begining of next epoch duration to check beacons
	 }

	call AMControl.stop();

	printf ("check beacon done stopped radio \n");
}
	
else 		{						// If slot not yet receieved keep checking in the next Epoch duration

		epoch_reference_time += EPOCH_DURATION;
		 call Timer_chk_beacon.startOneShotAt (epoch_reference_time, (EPOCH_DURATION+SMALL_OFFSET)); //check the presence of beacons at the next EPOCH_DURATON
}}
	





/***********************************************************************************************************************************************
Event: Radio_on.fired

Parameter: None

Description: Start Radio
 
************************************************************************************************************************************************/

event void Radio_on.fired() {

	call AMControl.start();

	printf ("Inside Radio_timer starting radio \n");
	
}


/***********************************************************************************************************************************************
Event: Send.sendDone()

Parameter: message_t* msg, error_t error

Description: This is a send done event for slot request. It toggles the flag

*************************************************************************************************************************************************/

event void Send.sendDone(message_t* msg, error_t error){
		          
        sending_bcast = FALSE; // now we can touch the output buffer again
			                  if (error != SUCCESS) {
		printf ("request not forwarded \n"); }}	   // something went wrong, but we don't care
		






/***********************************************************************************************************************************************
Event: Send_data.sendDone()

Parameter: message_t* msg, error_t error

Description: This is a send done event for sending data. It stops the radio immidiately after sending and sets the timer to turn on radio before 
the begining of the next epoch to check the arrival of beacons
*************************************************************************************************************************************************/
		  
  event void Send_data.sendDone(message_t* msg, error_t error){

	
        sending_bcast = FALSE; 			// now we can touch the output buffer again

	    call  AMControl.stop(); 		//Stop radio        
            printf("Stopping radio after data transmission \n");	
	    call Radio_on.startOneShotAt(epoch_reference_time, (EPOCH_DURATION-RADIO_START_OFFSET)); // Start timer to start radio at begnining of next epoch 
             signal tdma.acked (call PacketLink.wasDelivered(msg));
	       if (error != SUCCESS) {
                printf ("request not forwarded \n"); }}    // something went wrong, but we don't care




		
/***********************************************************************************************************************************************
Event: AMControl.startDone()

Parameter:  error_t error

Description: 

*************************************************************************************************************************************************/
		  
event void AMControl.startDone(error_t err) {

	printf ("Okay radio started again \n");
}


/************************************************************************************************************************************************
Function: init_slots

Parameter: None

Returns: None

Description: Initializes all slots to 0 i.e all slots are available. This function is called as soon as the master boots the radio                *************************************************************************************************************************************************/
command void tdma.init_tdma(){
	for (i= 0; i<NUM_SLOTS;i++);
	nodes[i]=0;
}



/************************************************************************************************************************************
Function: assign_slot

Parameter: am_addr_t 

Returns: none

Description: The function assigns slots to requesting nodes. It also keeps track of already assigned slots in an array of structures.
As soon this function is called it checks whether the requesting node had already been assinged a slot or not. If so returns the 
previously assigned slot for the node otherwise provides the node with a new slot if available.

The process of registering assigned slot is simply done by filling in an array of slot_DB strucures. The structure contains node id and 
respective slot. 

nodes[] is used for keeping track of assigned slots
example nodes [] = {3,2,0,0,0,0,0,0} means the 2nd and 3rd slots are occupied by nodes 3 & 2 respectively and the rest of the slots are free

**************************************************************************************************************************************/
void assign_slot ( am_addr_t from) {
	error_t status;					//  variable for correct transmission
	uint8_t temp;					//  holds slot number
	uint8_t index_val;				//  index for array of nodes already assinged a slot 
	Slot_req* request; 				//  a structure to send slot number to requesting node   


	// If requesting node is already assigned a slot in a previous session, just simply tell it the old slot number
 
	if (already_assigned(from)){
		index_val = already_assigned (from);	
		index_val--;
		temp =array[index_val].Slot_num; 	// read the already assigned slot number from the data base (array structure) 
	}


	// else assign a new slot if available

	else {
		i=0; 					// set i=0 in order to check available slots i.e nodes[i]=0 => the ith slot is empty

		while (i<NUM_SLOTS && nodes[i] !=0) {		//Go through nodes array until you find 0	
		
			i++;
		}

	//error_t status;
		
		if (i> (NUM_SLOTS-1)){	 	//if i is above available slots exit	

		 	printf("No available slots \n");
			return;

		}

		//If a free slot is available,  fill in the respective structure to keep track and send slot to the requesting node

		nodes[i]= (uint8_t) from; 		//the respective element of nodes[] is now filled with the node who owns the slot
		array[i].Node_Id = (uint8_t)from;	//The assigned slot is also registered with the respective node id on the slot_db 
		array[i].Slot_num = i+2;
		temp =i+2;
	}	

	//Send slot value to the requesting node via the radio interface

	printf ("assigned slot %d for %d \n", temp, from);
       
	if (!sending_bcast) {
        
		printf ("Sending slot to %d \n", from);
	 	request = call Send.getPayload(&pckt, sizeof(Slot_req));
		request->slot = temp;   
		status= call Send.send(from, &pckt, sizeof (Slot_req));
	}      

	else printf(" Radio busy \n");
	
	}






 event void AMControl.stopDone(error_t err) {

	printf("inside stop radio \n");
} 



/***********************************************************************************************************************************************************************************
Function: already_assigned

Parameter: Unsigned short

Returns: Unsigned short

Description: This function checks if a slot is already assigned to a node. If not assigned returns 0. This is to make sure a node only gets a single slot. Implementing this features averts
the problems arising from real time conditions when a slave gets to be assigned more than one slot because a previous packet to inform assignment of a slot
from the master to the slave is lost and hence the slave's slot variable isn't updated which leads to the slave asking for a slot again.
*******************************************************************************************************************************************************************************************/

uint8_t already_assigned (uint8_t from) {

// goes through the nodes array until it finds a match ... returns 0 if no match
	for (i=0; i< NUM_SLOTS; i++) {
		if (nodes[i]== from)
			return i+1; 	// Why doesn't it return simply i :)
	}
	
	return 0;
}}
