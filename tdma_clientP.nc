#include "messages.h"

module tdma_clientP {

uses {

	interface Boot;
	interface SplitControl as AMControl_client;
	interface tdma;		
	interface Timer<T32khz> as Timer_send;


}}


implementation {


uint8_t counter =1;
uint8_t i=0;
event void Boot.booted() {
        call AMControl_client.start();
        call tdma.init_tdma();
	call Timer_send.startOneShot(SECOND/100);


}

event void AMControl_client.startDone(error_t err) {

	 call tdma.set_mode(TOS_NODE_ID);

}

event void Timer_send.fired(){

	if (TOS_NODE_ID !=1) {

	while (i<5) {
	printf ("This is the client with %d \n", counter);

	call tdma.Send(counter);
	counter ++;
	i++;

	}
i=0;
call Timer_send.startOneShot(10*SECOND);

}
}

event void AMControl_client.stopDone(error_t err) {}

event void tdma.acked (bool acknowledged)
{	if (acknowledged) 

	printf ("Sent data was acked \n");

	else printf ("Sent data not acked");
}}
