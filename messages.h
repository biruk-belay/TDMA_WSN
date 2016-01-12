#ifndef MESSAGES_H
#define MESSAGES_H


#define SECOND 32768L
#define EPOCH_DURATION (SECOND)
#define NUM_SLOTS 8
#define SLOT_DURATION  (EPOCH_DURATION/(NUM_SLOTS+2))
#define IS_MASTER (TOS_NODE_ID==1)
#define MASTER 1
#define NUM_RETRIES 3
#define RADIO_START_OFFSET 500
#define SMALL_OFFSET 500
enum {

        AM_BEACONMSG = 130,
  	AM_MYMESSAGE = 240,

};


typedef nx_struct BeaconMsg {
        nx_uint16_t seqn;

}BeaconMsg;

typedef nx_struct Slot_req {
	nx_uint8_t slot;
}Slot_req;

typedef struct  {

	uint8_t Node_Id;
	uint8_t Slot_num;
}slot_DB;

typedef struct {

	nx_uint32_t seqn; 
	nx_uint8_t dummy;
}Data;
#endif
                                                                        
