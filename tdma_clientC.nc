configuration tdma_clientC {}

implementation {

	components new ApplicationC () as app;
	components tdma_clientP as client;
	components MainC;		
	components new Timer32C() as Timer_send;
//	components new Timer32C() as Timer_send_test;
	client.tdma -> app.tdma;
	components ActiveMessageC;
        client.Boot -> MainC.Boot;
	client.AMControl_client -> ActiveMessageC;
	client.Timer_send -> Timer_send;
//	client.Timer_send_test -> Timer_send_test;
}
