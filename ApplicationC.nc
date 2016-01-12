#include <Timer.h>
#include "messages.h"

generic configuration ApplicationC () {

provides interface tdma;
}

implementation {
	
        components ApplicationP as AppP;
       	components SerialPrintfC, SerialStartC;
	components new Timer32C() as TimerBeaconTx;
        components new Timer32C() as Timer;
	components new Timer32C() as Timer_send_data;
	components new Timer32C() as Timer_chk_beacon;
	components new Timer32C() as Timer_set_flag;
	components new Timer32C() as Timer_init_send;
	components new Timer32C() as Radio_start;
	
	components PacketLinkC;
	components ActiveMessageC;
        components CC2420TimeSyncMessageC as TSAM;
        components CC2420ActiveMessageC;
	components new AMSenderC(AM_MYMESSAGE) as Sender;
	components new AMReceiverC(AM_MYMESSAGE) as ReceiverC;
	components new AMSenderC(AM_MYMESSAGE) as Send_data;

		
	tdma = AppP.tdma;
        AppP.TSPacket -> TSAM.TimeSyncPacket32khz;
        AppP.SendBeacon -> TSAM.TimeSyncAMSend32khz[AM_BEACONMSG]; 
        AppP.ReceiveBeacon -> TSAM.Receive[AM_BEACONMSG];


	
	AppP.AMControl -> ActiveMessageC;
        AppP.TimerBeaconTx -> TimerBeaconTx;
	AppP.Timer_slot_req -> Timer;
	AppP.Timer_send_data-> Timer_send_data;
	AppP.Timer_init_send -> Timer_init_send;
	AppP.Timer_chk_beacon -> Timer_chk_beacon;
	AppP.Timer_set_flag -> Timer_set_flag;
	AppP.Radio_on -> Radio_start;
	AppP.Send -> Sender;
	AppP.Send_data -> Send_data;
	AppP.AMPacket -> ActiveMessageC;
	AppP.receive_pckt -> ReceiverC;
	AppP.PacketLink-> PacketLinkC;
}
      
