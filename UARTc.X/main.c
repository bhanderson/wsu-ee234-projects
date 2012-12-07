/*
 * File:   main.c
 * Author: Bryce Handerson
 *
 * Created on December 5, 2012, 2:11 PM
 */

#include <plib.h>


#pragma config FNOSC	= PRIPLL
#pragma config FPLLMUL	= MUL_20
#pragma config FPLLIDIV	= DIV_2
#pragma config FPBDIV	= DIV_2
#pragma config FPLLODIV	= DIV_1

#define SYSTEM_CLOCK		80000000
#define DESIRED_BAUD		9600

void setup_ports (void);
void setup_UART1 (unsigned int pb_clock);



int main(void)
{
	unsigned int pb_clock = 0;
	unsigned char data = 'B';

	pb_clock = SYSTEMConfigPerformance (SYSTEM_CLOCK);

	setup_ports ();

	setup_UART1 (pb_clock);

	while(UART_TRANSMITTER_EMPTY)
	{
            //putcUART1('b');
            if(DataRdyUART1()){
                data = ReadUART1();
                putcUART1(data);

            }
	}

    return (EXIT_SUCCESS);
}

void setup_ports (void)
{
	// UART 1 port pins - connected to PC
	// JE-01:04 RD14:15 RF2:8
	PORTSetPinsDigitalIn	(IOPORT_F, BIT_2);
	PORTSetPinsDigitalOut	(IOPORT_F, BIT_2);
	return;
}

void setup_UART1 (unsigned int pb_clock)
{
    UARTEnable(UART1, UART_ENABLE_FLAGS(UART_PERIPHERAL | UART_RX | UART_TX));
    U1BRG = 51;
    // 259 = 1923 200 = 2500 100 = 4,808 50 = 10,000
    // OpenUART1 (config1, config2, ubrg)
    /*
	OpenUART1 (UART_EN | UART_IDLE_CON | UART_RX_TX | UART_DIS_WAKE | UART_DIS_LOOPBACK | UART_DIS_ABAUD | UART_NO_PAR_8BIT | UART_1STOPBIT | UART_IRDA_DIS |
               UART_MODE_FLOWCTRL | UART_DIS_BCLK_CTS_RTS | UART_NORMAL_RX | UART_BRGH_SIXTEEN,
               UART_TX_PIN_LOW | UART_RX_ENABLE | UART_TX_ENABLE | UART_INT_TX | UART_INT_RX_CHAR | UART_ADR_DETECT_DIS	| UART_RX_OVERRUN_CLEAR,
			   mUARTBRG(pb_clock, DESIRED_BAUD));*/

}

