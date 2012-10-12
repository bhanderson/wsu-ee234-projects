# ***************************************************************************************************************************
# * Author: Bryce Handerson & Alex Schuldberg                                                                               *
# * Course: EE 234 Microprocessor Systems - Lab #5                                                                          *
# * Project: ROBO-MAL PROGRAM                                                                                               *
# * File: main.s                                                                                                            *
# * Description: This file is the beginning to a robo mal program that takes in a program using hex digits                  *
# *              and operates on the operation and operand. It uses the cerebot MX4ck by Digilent using the 				*
# *				 PIC32MX460F512L																							*
# *              are allowed.                                                                                               *
# *                                                                                                                         *
# * Inputs:                                                                                                                 *
# * Outputs:                                                                                                                *
# * Computations:                                                                                                           *
# *                                                                                                                         *
# * Revision History:                                                                                                       *
# ***************************************************************************************************************************

# ******************************************* Include Files *****************************************************************

# ******************************************* Global Symbols ****************************************************************

.GLOBAL main

# ******************************************* Data Segment ******************************************************************

.DATA                        # The start of the data segment

program: .word 0x1011, 0x1211, 0x2110, 0x3106, 0x4190, 0x3007, 0x4910, 0x4201, 0x4403, 0x3300, 0x80, 0x00

# ******************************************* Code Segment ******************************************************************

.TEXT                       # The start of the code segment

.ENT main					# Setup a main entry point
main:

#	JAL reset				# JAL instruction ensures address of return point is stored in register ra
#	JAL setup_switches
#	JAL setup_LEDs

    LA $a1, program			# Load the program instructions into program memory

	loop:
       # fetch instruction
       LW $s2, ($a1)
       # decode it and branch
       LI $t0, 1			# checksum for data class (1)
       SRL $t1, $s2, 12
       BEQ $t0, $t1, rm_data
       ADDI $t0, $t0, 1		# checksum for math class (2)
       BEQ $t0, $t1, rm_math
       ADDI $t0, $t0, 1		# checksum for branch class (3)
       BEQ $t0, $t1, rm_branch
       ADDI $t0, $t0, 1		# checksum for control class (4)
       BEQ $t0, $t1, rm_control
	   # error if reach this line
	   J error
	iterate:
       # execute it
		ADDI $a1, $a1, 4	# iterate program counter to the next instruction

	end:
		J loop				# Embedded programs require that they run forever! So jump back to the beginning of the loop

	error:					# this lable starts the error sequence flashing the led pmods very quickly
		LI $t0, 0xF
		SW $t0, (LATB)
		LI $t0, 0
		SW $t0, (LATB)
		J error
	stop:					# here to end the program

.END main


.ENT rm_search_program
rm_search_program:
	LI $t0, 0				# t0 is the counter
	LI $t1, 0x3300			# t1 is the checksum for end of program, (variables follow this instruction)
	ADD $t2, $zero, $a1     # t2 is the copy of a1 to protect it

	rm_search_program_loop:
        LW $t3, 0($t2)							# load the first instruction into t3 (might be able to combine this and next line)
		BEQ $t1, $t3, rm_search_program_done	# if it is end of program branch to done
		ADDI $t2, $t2, 4						# else it is not a variable, increment temp program counter
        ADDI $t0, $t0, 4    					# increment counter by 4
		J rm_search_program_loop				# restart loop

	rm_search_program_done:
		ADDI $t0, $t0, 4	# increment t0 by 4 to put it at the first variable
		ADDI $s4, $t0, 0	# store t0 to s4(operand register) to preserve
		JR $ra				# jump back to what called search
.END rm_search_program


.ENT rm_data
rm_data:
	ADDI $sp, $sp, -4		# push ra to stack
	SW $ra, 0($sp)
	JAL rm_search_program	# search for the first variable and store it in s4
	LW $ra, 0($sp)
	ADDI $sp, $sp, 4		# pop ra from stack


    ANDI $t0, $s2, 0x0F00		# mask operation (second digit)
    SRL $t0, 8					# shift right 8 for ease of access
    LI $t1, 0					# t1 is the checksum
    BEQ $t0, $t1, rm_data_read
	ADDI $t1, $t1, 1			# t1 = 1 
	BEQ $t0, $t1, rm_data_write
	ADDI $t1, $t1, 1			# t1 = 2 
	BEQ $t0, $t1, rm_data_load
	ADDI $t1, $t1, 1			# t1 = 3 
	BEQ $t0, $t1, rm_data_store
	J error						# hit this if there is an error


	# not sure if this is what is needed for this may need to rewrite this segment
    rm_data_read:
		ANDI $t0, $s2, 0xFF				# mask only operand of instruction
		LI $t1, 0x01		
		BEQ $t1, $s2, rm_data_read_var1	# check to see what variable 1 (0x01) or 2 (0x11)
		LI $t1, 0x11
		BEQ $t1, $s2, rm_data_read_var2
		J error							# hit this if there is an error

		rm_data_read_var1:
			
			
		rm_data_read_var2:

		J iterate	# rm_data_load is done go to iterate

    rm_data_write:

		J iterate	# rm_data_write is done go to iterate

    rm_data_load:

		J iterate	# rm_data_load is done go to iterate

    rm_data_store:

		J iterate	# rm_data_store is done go to iterate

    J iterate		# catchall for rm_data
.END rm_data


.ENT rm_math
rm_math:
	ANDI $t0, $s1, 0x0F00			# this segment checks the operation (see rm_data comments)
	SRL $t0, 8
    LI $t1, 0
	BEQ $t0, $t1, rm_math_add
    ADDI $t1, $t1, 1
    BEQ $t0, $t1, rm_math_subtract
	ADDI $t1, $t1, 1
	BEQ $t0, $t1, rm_math_multiply 
	
	rm_math_add:
		J iterate	# rm_math_add is done go to iterate
	rm_math_subtract:
		J iterate	# rm_math_subtract is done go to iterate
	rm_math_multiply:
		J iterate	# rm_math_multiply is done go to iterate

    J iterate		# catchall for rm_math
.END rm_math


.ENT rm_branch
rm_branch:
	ANDI $t0, $s1, 0x0F00			# this segment checks the operation (see rm_data comments)
	SRL $t0, 8
    LI $t1, 0
    BEQ $t0, $t1, rm_branch_address
    ADDI $t1, $t1, 1
    BEQ $t0, $t1, rm_branch_equal
    ADDI $t1, $t1, 1
    BEQ $t0, $t1, rm_branch_not_equal
    ADDI $t1, $t1, 1
    BEQ $t0, $t1, rm_branch_halt
	
	rm_branch_address:
		ANDI $t0, $s1, 0x00FF	# 0x3007 branch to cell 7
		LI $t1, 4				# size of instruction to muliply to
		MUL $t0, $t0, $t1		# multiply the cell number ($t0) to the size of a word (t1) to get the byte address of the program counter
		ADDI $s2, $t0, $a1		# change program counter
		J loop
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
