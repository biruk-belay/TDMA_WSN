#include <Timer.h>

//This change is supposed to not show up

generic configuration Timer32C() {
	provides interface Timer<T32khz> as Timer32khz;
}
implementation
{
	components Timer32P;
	
	Timer32khz = Timer32P.Timer32khz[unique("Timer32khz")];
}
