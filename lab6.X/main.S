# ***************************************************************************************************************************
# * Author: Alex Schuldberg and Bryce Handerson                                                                                                              *
# * Course: EE 234 Microprocessor Systems - Lab #6                                                                           *
# * Project:  Timers                                                                                                              *
# * File: main.S                                                                                                            *
# * Description: This file is provided to help you get started with MIPS32 (.s) assembly programs.                          *
# *              You may use this template for getting started with .S files also, in which preprocessor directives         *
# *              are allowed.                                                                                               *
# *                                                                                                                         *
# * Inputs:                                                                                                                 *
# * Outputs:                                                                                                                *
# * Computations:                                                                                                           *
# *                                                                                                                         *
# * Revision History:                                                                                                       *
# ***************************************************************************************************************************

# XXXXXXXXXXXXXXX Timer 1 Example XXXXXXXXXXXXXXXXXXX


# ***************************************************************************************************************************
# *                                                                                                                         *
# *                                           Include Files                                                                 *
# *                                                                                                                         *
# ***************************************************************************************************************************

/* #include all necessary standard and user-defined libraries */
#include <p32xxxx.h> /* Includes all major functions and macros required to develop
                        programs for the PIC32MX4 */


/* SYSCLK = 80 MHz (8 MHz Crystal/ FPLLIDIV * FPLLMUL / FPLLODIV)
// PBCLK = 40 MHz
// Primary Osc w/PLL (XT+,HS+,EC+PLL)
// WDT OFF
// Other options are don't care */

#pragma config FNOSC	 = PRIPLL
#pragma config FPLLMUL  = MUL_20
#pragma config FPLLIDIV  = DIV_2
#pragma config FPBDIV  = DIV_2 /* Divide SYSCLK by 2 ==> PBCLK */
#pragma config FPLLODIV  = DIV_1

# ***************************************************************************************************************************
# *                                                                                                                         *
# *                                           Global Symbols                                                                *
# *                                                                                                                         *
# ***************************************************************************************************************************

.GLOBAL main

# ***************************************************************************************************************************
# *                                                                                                                         *
# *                                           Data Segment                                                                  *
# *                                                                                                                         *
# ***************************************************************************************************************************

# This is where all variables are defined.
# We generally assign pointer/address registers to these variables and access them indirectly via these registers.

.DATA                        # The start of the data segment

# ***************************************************************************************************************************
# *                                                                                                                         *
# *                                           Code Segment                                                                  *
# *                                                                                                                         *
# ***************************************************************************************************************************

.TEXT                        # The start of the code segment

.ENT main                    # Setup a main entry point
main:

	DI	# Disable system wide interrupts; dont respond to spurious interrupts

	JAL disableTimer1Int	# Ensure external Timer 1 Interrupt is disabled. Recall its a maskable interrupt
	JAL setupPORTs	# Setup pins to switches as inputs, and pins to on-board LEDs as outputs
	JAL clearLEDs	# Flush out LEDs
	JAL setupMultiVectoredMode	# Want mult-vectored interrupts - each interrupt may have a location in interrupt vector table
	JAL setupTimer1	# Configure Timer 1
	JAL enableTimer1Int	# Allow Timer 1 to grab attention of CPU

	EI	# Enable system wide interrupts

	loop:
		# Event loop
		J loop      # Embedded programs require that they run forever So jump back to the beginning of the loop

.END main

# ***************************************************************************************************************************
# *                                                                                                                         *
# *                                           Subroutine Definitions                                                        *
# *                                                                                                                         *
# ***************************************************************************************************************************

# The below comment block is required for all defined subroutines!
# ***************************************************************************************************************************
# * Function Name:                                                                                                          *
# * Description:                                                                                                            *
# *                                                                                                                         *
# * Inputs:		                                                                                                            *
# * Outputs:	                                                                                                            *
# * Computations:                                                                                                           *
# *                                                                                                                         *
# * Errors:                                                                                                                 *
# * Registers Preserved:                                                                                                    *
# *                                                                                                                         *
# * Preconditions:                                                                                                          *
# * Postconditions:                                                                                                         *
# *                                                                                                                         *
# * Revision History:                                                                                                       *
# ***************************************************************************************************************************

.ENT setupPorts
setupPorts

	# Preserver register - push to stack
	ADDI $sp, $sp, -4
	SW $s0, 0($sp)

	LA $s0, TRISB
	# LEDs LD4:1 RB13:10
	LW $t0, ($s0)
	ANDI $t0, $t0, 0b1100001111110000
	SW $t0, ($s0)

	# Switch JF04:01 SW1 - RA14, SW2 - RA15, SW3 - RA6, SW4 - RA7
	LA $s0, TRISA
	LW $t0, ($s0)
	ORI $t0, $t0, 0b1100000011000000
	SW $t0, ($s0)

	# Pop registers
	LW $s0, 0($sp)
	ADDI $sp, $sp, 4

	JR $ra

.END setupPorts



.ENT clearLEDs
clearLEDs:
	ADDI $sp, $sp, -4
	SW $s0, 0($sp)

	LA $s0, LATB
	# LEDs LD4:1 RB13:10 
	LW $t0, ($s0)
	ANDI ($t0), ($t0), 0b1100001111110000
	SW $t0, ($s0)

	LW $s0, 0($sp)
	ADDI $sp, $sp, 4

	JR $ra

.END clearLEDs


.ENT setupMultiVectoredMode
setupMultiVectoredMode:

	# Preserver registers - push to stack
	ADDI $sp, $sp, -4
	SW $s0, 0($sp)
	
	LA $s0, INTCON				# multi-vectored mode register
	LW $t0, ($s0)
	ORI $t0, $t0, 3 << 12	# set 0b11 multi-vectored mode
	SW $t0, INTCON

	# Pop registers
	LW $s0, 0($sp)
	ADDI $sp, $sp, 4

	JR $ra

.END setupMultiVectoredMode

.ENT setupTimer1
setupTimer1:

	# Preserve registers - push to stack
	ADDI sp, sp, -8
	SW ra, 4(sp)
	SW s0, 0(sp)

	# T1CON - Control Register for Timer 1
	# Bit 15 - ON Timer On bit, 1 = timer enabled, 0 = disabled
	LA s0, T1CON
	LI t0, 0x0 # stop Timer 1
	SW t0, (s0)

	# TMR1 register contains 16-bit current value of Timer 1
	LA s0, TMR1
	MOVE t0, zero # clear timer value
	SW t0, (s0)

	# PR1 register contains 16-bit period match value, i.e. TMR1 value == PR1 value ==> interrupt
	LA s0, PR1
	LI t0, 0x1F40 # Affects how often interrupt is triggered: the smaller the number, the more often interrupt request occurs
	#LI t0, 0xFFFF # match at 65,535
	SW t0, (s0)

	# T1CON - Control Register for Timer 1
	# Bit 1 - TCS Timer Clock Source, 0 = internal peripheral clk (PBCLK)
	# Bits 5:4 - TCKPS Timer Clock Prescale Select bits, 11 = /256, 10 = /64, 01 = /8, 00 = /1
	# Bit 11 - TWIP Asynchronous Timer Write in Progress bit, 1 = Asynchronous write to TMR1 register in progress, 0 = write to TMR1 register complete
	# Bit 15 - ON Timer On bit, 1 = timer enabled, 0 = disabled

	LA s0, T1CON
	LI t0, 0x8020 # PBCLK / 64, Timer 1 on
	SW t0, (s0)

	# Set priority
	LA s0, IPC1 # Interrupt priority register for Timer 1
	# IPC1 T1IP <4:2> for Timer 1
	LW t0, (s0)
	ORI t0, t0, 6 << 2 # priority 6
	SW t0, (s0)

	# Pop registers
	LW s0, 0(sp)
	LW ra, 4(sp)
	ADDI sp, sp, 8

	JR ra

.END setupTimer1

.ENT enableTimer1Int
enableTimer1Int:

	# Preserve registers - push to stack
	ADDI sp, sp, -8
	SW ra, 4(sp)
	SW s0, 0(sp)

	LA s0, IEC0 # Interrupt enable control register - our mask register
	LW t0, (s0)
	ORI t0, t0, 1 << 4 # Set corresponding mask bit to 1 to enable, 4 is T1IE (Timer 1 Interrupt Enable) position
	SW t0, (s0)

	# Pop registers
	LW s0, 0(sp)
	LW ra, 4(sp)
	ADDI sp, sp, 8

	JR ra

.END enableTimer1Int

.ENT disableTimer1Int
disableTimer1Int:

	# Preserve registers - push to stack
	ADDI sp, sp, -8
	SW ra, 4(sp)
	SW s0, 0(sp)

	LA s0, IEC0CLR # Used to clear bit to disable Timer 1 interrupt
	LI t1, 1
	SLL t1, t1, 4
	SW t1, (s0)

	# Pop registers
	LW s0, 0(sp)
	LW ra, 4(sp)
	ADDI sp, sp, 8

	JR ra

.END disableTimer1Int

.SECTION .vector_4, code	# Attach jump to handler in vector corresponding to INT4

   J      Timer1IntHandler


.TEXT

.ENT Timer1IntHandler
Timer1IntHandler:

	# We want our handlers to be as short as possible. We do want them
	# to execute in as few clock cycles as possible. We generally do
	# not want to call procedures from within these handlers.

	# Coprocessor 0 is necessary to communciate status and control between
	# software and CPU. Will uyse Coprocessor 0 registers in the handler.
	DI	# Disable system wide interrupts

	# Register preservation courtesy of section 8 interrupts ref manual p. 21, 22
	RDPGPR sp, sp
	MFC0 k0, $13	# Cause register
	MFC0 k1, $14	# EPC
	SRL k0, k0, 0xA
	ADDIU sp, sp, -76
	SW k1, 0(sp)
	MFC0 k1, $12	# Status register
	SW k1, 4(sp)
	INS k1, k0, 10, 6
	INS k1, zero, 1, 4
	MTC0 k1, $12	# Status register
	SW s8, 8(sp)
	SW a0, 12(sp)
	SW a1, 16(sp)
	SW a2, 20(sp)
	SW a3, 24(sp)
	SW v0, 28(sp)
	SW v1, 32(sp)
	SW t0, 36(sp)
	SW t1, 40(sp)
	SW t2, 44(sp)
	SW t3, 48(sp)
	SW t4, 52(sp)
	SW t5, 56(sp)
	SW t6, 60(sp)
	SW t7, 64(sp)
	SW t8, 68(sp)
	SW t9, 72(sp)
	ADDU s8, sp, zero

	# Clear Timer 1 Interrupt status flag
	LA t0, IFS0CLR
	LW t1, (t0)
	ORI t1, t1, 1 << 4 # Timer 1 bit position
	SW t1, (t0)



    BEQZ a1,countup  # if $a1 = 0 then count up
    LI t0, 1
    BEQ t0, a1, countdown # if $a1 = 1 then jump to count down
    J timer1end # else if $a1 = 2 then do nothing, because we are puased.
    countup:
        LI t0,15
        BEQ t0,a0,clear
        ADDI a0,a0,1
        J noclear
        clear:
        LI a0,0
        noclear:
        SW a0,12(sp)
        LI t3,0
        SLL t4,a0,10
        SW t4,(LATB)
        J timer1end
   countdown:
        BEQZ a0,reset
        ADDI a0,a0,-1
        J noreset
        reset:
        LI a0,15
        noreset:
        SW a0,12(sp)
        SLL t4,a0,10
        SW t4,(LATB)
   timer1end:

	ADDU sp, s8, zero
	LW t9, 72(sp)
	LW t8, 68(sp)
	LW t7, 64(sp)
	LW t6, 60(sp)
	LW t5, 56(sp)
	LW t4, 52(sp)
	LW t3, 48(sp)
	LW t2, 44(sp)
	LW t1, 40(sp)
	LW t0, 36(sp)
	LW v1, 32(sp)
	LW v0, 28(sp)
	LW a3, 24(sp)
	LW a2, 20(sp)
	LW a1, 16(sp)
	LW a0, 12(sp)
	LW s8, 8(sp)


	LW k0, 0(sp)
	MTC0 k0, $14	# EPC register
	LW k0, 4(sp)
	MTC0 k0, $12	# Status register

	EI	# Enable system wide interrupts

	ERET # PC = EPC

.END Timer1IntHandler



.ENT setupINT4
setupINT4:
	
	# Preserver registers
	ADDI $sp, $sp, -4
	SW $s0, 0($sp)
	
	# Set priority
	LA $s0, IPC4 # Interrupt priority register
	# IPC4 <28:26> for INT4
	LW $t0, ($s0)
	LI $t1, 1
	SLL $t1, $t1, 26
	OR $t0, $t0, $t1
	SW $t0, ($s0)

	# Set the polarity
	# interrupt control register
	LA $s0, INTCON	# Register necessary for setting polarity of interrupt trigger
	LW $t0, ($s0)
	ORI $t0, $t0, 1 << 4 # enable int external interrupt
	SW $t0, ($s0)
	
	# Pop registers
	LW $s0, 0($sp)
	ADDI $sp, $sp, 4

	JR $ra

.END setupINT4

.ENT enableINT4
enableINT4:

	# Preserve registers - push to stack
	ADDI $sp, $sp, -4
	SW $s0, 0($sp)

	LA $s0, IEC0	# Interrupt enable control register - mask register
	LW $t0, ($s0)
	LI $t1, 1
	SLL $t1, $t1, 19
	OR $t0, $t0, $t1 # Set mask bit to 1 enable, INT4 19 position
	SW $t0, ($s0)

	# Pop registers
	LW $s0, 0($sp)
	ADDI $sp, $sp, 4

	JR $ra

.END enableINT4

.ENT disableINT4
disableINT4:
	
	# Preserve registers - push to stack
	ADDI $sp, $sp, -4
	SW $s0, 0($sp)

	LA $s0, IEC0CLR # Used to clear bit to disable INT4
	LI $t1, 1
	SLL $t1, $t1, 19
	SW $t1, ($s0)

	# Pop Registers
	LW $s0, 0($s0)
	ADDI $sp, $sp, 4

	JR $ra

.END disableINT4

.SECTION .vector_19, code	# Jump handler for INT4
	
	J	ExtInt4Handler


.TEXT

.ENT ExtInt4Handler
ExtInt4Handler:

	DI	# Disable system wide interrupts

	# Preserve all registers
	RDPGPR $sp, $sp
	MFC0 $k0, $13	# Cause register
	MFC0 $k1, $14	# EPC
	SRL $k0, $k0, 0xA
	ADDIU $sp, $sp, -76
	SW $k1, 0($sp)
	MFC0 $k1, $12	# Status register
	SW $k1, 4($sp)
	INS $k1, $k0, 10, 6
	INS $k1, $zero, 1, 4
	MTC0 $k1, $12	# Status register
	SW $s8, 8($sp)
	SW $a0, 12($sp)
	SW $a1, 16($sp)
	SW $a2, 20($sp)
	SW $a3, 24($sp)
	SW $v0, 28($sp)
	SW $v1, 32($sp)
	SW $t0, 36($sp)
	SW $t1, 40($sp)
	SW $t2, 44($sp)
	SW $t3, 48($sp)
	SW $t4, 52($sp)
	SW $t5, 56($sp)
	SW $t6, 60($sp)
	SW $t7, 64($sp)
	SW $t8, 68($sp)
	SW $t9, 72($sp)
	ADDU $s8, $sp, $zero

	# Clear INT4 status flag
	LA $t0, IFS0CLR
	LI $t1, 1
	# Need to shift, mask too big for ANDI
	SLL $t1, $t1, 19
	SW $t1, ($t0)

	# Copy the value of LEDs to P-Mod LEDs
	LA $t0, LATB
	LW $t1, ($t0)
	OR $t2, $t1, $zero
	ANDI $t2, $t2, 0x3c00
	SRL $t2, 10
	OR $t1, $t1, $t2
	SW $t1, ($t0)

	ADDU $sp, $s8, $zero
	LW $t9, 72($sp)
	LW $t8, 68($sp)
	LW $t7, 64($sp)
	LW $t6, 60($sp)
	LW $t5, 56($sp)
	LW $t4, 52($sp)
	LW $t3, 48($sp)
	LW $t2, 44($sp)
	LW $t1, 40($sp)
	LW $t0, 36($sp)
	LW $v1, 32($sp)
	LW $v0, 28($sp)
	LW $a3, 24($sp)
	LW $a2, 20($sp)
	LW $a1, 16($sp)
	LW $a0, 12($sp)
	LW $s8, 8($sp)


	LW $k0, 0($sp)
	MTC0 $k0, $14	# EPC register
	LW $k0, 4($sp)
	MTC0 $k0, $12	# Status register

	EI	# Enable system wide interrupts

	ERET # PC = EPC

.END ExtInt4Handler
