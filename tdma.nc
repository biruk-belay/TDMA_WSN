interface tdma {

	command void init_tdma();
	command void set_mode (uint8_t id);
	command void Send (uint8_t);
	event   void acked (bool);	
}
