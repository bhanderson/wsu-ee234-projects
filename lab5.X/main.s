# ***************************************************************************************************************************
# * Author: Bryce Handerson                                                                                                 *
# * Course: EE 234 Microprocessor Systems - Lab #                                                                           *
# * Project: ROBO-MAL PROGRAM                                                                                               *
# * File: main.s                                                                                                            *
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


# ***************************************************************************************************************************
# *                                                                                                                         *
# *                                           Include Files                                                                 *
# *                                                                                                                         *
# ***************************************************************************************************************************


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

program: .word 0x1011, 0x1211, 0x2110, 0x3106, 0x4190, 0x3007, 0x4910, 0x4201, 0x4403, 0x3300, 0x80, 0x00

# ***************************************************************************************************************************
# *                                                                                                                         *
# *                                           Code Segment                                                                  *
# *                                                                                                                         *
# ***************************************************************************************************************************

.TEXT                        # The start of the code segment


.ENT main                    # Setup a main entry point
main:

#	JAL reset                # JAL instruction ensures address of return point is stored in register ra
#	JAL setup_switches
#	JAL setup_LEDs

    LA $a1, program			# Load the program instructions into program memory

	loop:
       # fetch instruction
       LW $s2, ($a1)
       # decode it
       LI $t0, 1
       SRL $t1, $s2, 12
       BEQ $t0, $t1, rm_data
       ADDI $t0, $t0, 1
       BEQ $t0, $t1, rm_math
       ADDI $t0, $t0, 1
       BEQ $t0, $t1, rm_branch
       ADDI $t0, $t0, 1
       BEQ $t0, $t1, rm_control
#TODO Error check
	iterate:
       # execute it
		ADDI $a1, $a1, 4  # iterate program counter

	end:
		J loop               # Embedded programs require that they run forever! So jump back to the beginning of the loop
	error:
		LI $t0, 0xF
		SW $t0, (LATB)
		LI $t0, 0
		SW $t0, (LATB)
		J error
	stop:

.END main

.ENT rm_data
rm_data:
    ANDI $t0, $s2, 0x0F00
    SRL $t0, 8
    LI $t1, 0				#t1 = 0
    BEQ $t0, $t1, rm_data_read
	ADDI $t1, $t1, 1		#t1 = 1 now
	BEQ $t0, $t1, rm_data_write
	ADDI $t1, $t1, 1		#t1 = 2 now
	BEQ $t0, $t1, rm_data_load
	ADDI $t1, $t1, 1		#t1 = 3 now
	BEQ $t0, $t1, rm_data_store
	
    rm_data_read:
		ANDI $t0, $s2, 0xFF	#mask only operand of instruction
		LI $t1, 0x01		
		BEQ $t1, $s2, rm_data_read_var1	#check to see what variable 1 or 2
		LI $t1, 0x11
		BEQ $t1, $s2, rm_data_read_var2
		J error
		rm_data_read_var1:
			
		rm_data_read_var2:

	J iterate
    rm_data_write:

    rm_data_load:


    rm_data_store:


    J iterate
.END rm_data

.ENT rm_math
rm_math:
	ANDI $t0, $s1, 0x0F00
	SRL $t0, 8
    LI $t1, 0			#t1 = 0
    BEQ $t0, $t1, rm_math_add
    ADDI $t1, $t1, 1	#t1 = 1 now
    BEQ $t0, $t1, rm_math_subtract
	ADDI $t1, $t1, 1	#t1 = 2 now
	BEQ $t0, $t1, rm_math_multiply 
	
	rm_math_add:
	rm_math_subtract:
	rm_math_multiply:

    J iterate
.END rm_math

.ENT rm_branch
rm_branch:
	ANDI $t0, $s1, 0x0F00
	SRL $t0, 8
    LI $t1, 0
    BEQ $t0, $t1, rm_branch_address
    ADDI $t1, $t1, 1    #t1 = 1 now
    BEQ $t0, $t1, rm_branch_equal
    ADDI $t1, $t1, 1    #t1 = 2 now
    BEQ $t0, $t1, rm_branch_not_equal
    ADDI $t1, $t1, 1    #t1 = 3 now
    BEQ $t0, $t1, rm_branch_halt
	
	rm_branch_address:
		ANDI $t0, $s1, 0x00FF

	rm_branch_equal:

	rm_branch_not_equal:

    rm_branch_halt:
    J stop    

    J iterate
.END rm_branch

.ENT rm_control
rm_control:
    ANDI $t0, $s1, 0x0F00
    SRL $t0, 8
    LI $t1, 0
    BEQ $t0, $t1, rm_control_left
    ADDI $t1, $t1, 1    #t1 = 1
    BEQ $t0, $t1, rm_control_right
    ADDI $t1, $t1, 1    #t1 = 2
    BEQ $t0, $t1, rm_control_foreward
    ADDI $t1, $t1, 1    #t1 = 3
    BEQ $t0, $t1, rm_control_backward
	ADDI $t1, $t1, 1	#t1 = 4
	BEQ $t0, $t1, rm_control_brake

	rm_control_left:
	
	rm_control_right:

	rm_control_foreward:

	rm_control_backward:

	rm_control_brake:

	J iterate
.END rm_control



.ENT reset
reset:

	# Clear pins connected to PORTB, so LEDs dont always turn on
	MOVE $t0, $zero
	SW $t0, (LATB)

	# Return to caller
	JR $ra

.END reset


.ENT setup_switches
setup_switches:

	# Need to set switch I/O pins to inputs;
	# Switches connected to JK 01:04 of Cerebot;
	# SW1 - RB10, SW2 - RB11, SW3 - RB12, SW4 - RB13

	LI $t0, 0x3C00
	SW $t0, (AD1PCFG) # Set the analog pins to digital

	LW $t0, (TRISB)
	ORI $t0, $t0, 0x3C00 # Only set required pins for switches on PORTB
	SW $t0, (TRISB)

	# Return to caller
	JR $ra

.END setup_switches


.ENT setup_LEDs
setup_LEDs:

	# Need to set LED I/O pins to outputs;
	# Switches connected to JJ 01:04 of Cerebot;
	# LD0 - RB0, LD1 - RB1, LD2 - RB2, LD3 - RB3

	LW $t0, (TRISB)
	ANDI $t0, $t0, 0xFFF0 # Preserve other pins on PORTB
	SW $t0, (TRISB)

	# Return to caller
	JR $ra

.END setup_LEDs
