#include <p32xxxx.h>

#pragma config FNOSC	= PRIPLL
#pragma config FPLLMUL	= MUL_20
#pragma config FPLLDIV	= DIV_2
#pragma config FPBDIV	= DIV_2
#pragma config FPLLODIV	= DIV_1

.GLOBAL main
.DATA
# data
.TEXT
.ENT main
main:
    JAL setupPorts
    JAL clearLEDs
    JAL setupUART1

    loop:
    # check if shift register buffer is empty
    LW s0, U1STA
    ANDI s0, s0, 1 << 8
    BEQZ s0, loop
    # load next byte to transmit
    LI t0, 'A'
    SW t0, U1TXREG
    J loop

.END main

.ENT setupPorts
setupPorts:
    ADDI sp, sp, -8
    SW s0, 0(sp)

    # Set LD4:1 RB13:10 as output
    LI t0, 0x3C00
    SW t0, TRISBCLR
    LA s0, TRISB

    LW s0, 0(sp)
    ADDI sp, sp, 8

    JR ra
.END setupPorts

.ENT clearLEDs
clearLEDs:
    ADDI sp, sp, -8
    SW s0, 0(sp)

    # clear LD4:1 RB13:10
    LI t0, 0x3C00
    SW t0, LATBCLR

    LW s0, 0(sp)
    ADDI sp, sp, 8

    JR ra

.END clearLEDs

.ENT setupUART1
setupUART1:
    ADDI sp, sp, -8
    SW s0, 0(sp)

    # clear and reset UART1 control/config register
    LA s0, U1MODE
    SW zero, (s0)

    # Clear Tx and Rx buffers
    LA s0, U1TXREG
    SW zero, (s0)
    LA s0, U1RXREG
    SW zero, (s0)

    # Set baud rate
    LA s0, U1BRG
    LI t0, 259  # (PBCLK / (16 * baud)) -1 = 9600 bps
    SW t0, (s0)

    # enable Tx on Status and Control Reg
    LA s0, U1STA
    LI t0, 1 << 10
    SW t0, (s0)

    # enable UART1
    LA s0, U1MODE
    LI t0, 0x8000
    SW t0, (s0)


    LW s0, 0(sp)
    ADDI sp, sp, 8
    JR ra

.END setupUART1