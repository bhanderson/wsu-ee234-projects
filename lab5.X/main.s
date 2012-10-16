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
	JAL setup_LEDs

    LA $a1, program			# Load the program instructions into program memory
    LI $s1, 0

	loop:
       # fetch instruction
       ADDI $s1, $s1, 1
       LW $s2, ($a1)
	   ANDI $s3,$s2,0xFF00
	   ANDI $s4,$s2,0x00FF
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
        LI $v0, 10
        syscall
    J stop
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
		ADDI $a2, $t0, 0	# store t0 to a0(operand register) to preserve
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
		LI $t1, 0x10
		BEQ $t1, $t0, rm_data_read_var1	# check to see what variable 1 (0x01) or 2 (0x11)
		LI $t1, 0x11
		BEQ $t1, $t0, rm_data_read_var2
		J error							# hit this if there is an error

		rm_data_read_var1:
			LW $t0,(PORTE)
			ANDI $t0,0xFF
            ADD $t1, $a1, $a2
			SW $s0,($t1)
			J iterate

		rm_data_read_var2:
			LW $t0,(PORTE)
			ANDI $t0,0xFF
            ADD $t1, $a1, $a2
            ADDI $t1, $t1, 4
			SW $s0,($t1)
			J iterate	# rm_data_load is done go to iterate

    rm_data_write:
			LI $t1,0x11
			BEQ $t1,$s4,write1
			#write0
				LW $t0,(PORTE)
                ADD $t2, $a1, $a2
				LW $t1,($t2)
				OR $t0,$t1,$t0
				SW $t0,(PORTE)
				J iterate	# rm_data_write is done go to iterate
			write1:
				LW $t0,(PORTE)
                ADD $t2, $a1, $a2
                ADDI $t2, $t2, 4
				LW $t1,($t2)
				OR $t0,$t1,$t0
				SW $t0,(PORTE)
			J iterate	# rm_data_write is done go to iterate
    rm_data_load:
			LI $t1,0x11
			BEQ $t1,$s4,load1
            #load0
            ADD $t2, $a1, $a2
			LW $s0,($t2)
				J iterate	# rm_data_load is done go to iterate

			load1:
                ADD $t2, $a1, $a2
                ADDI $t2, $t2, 4
				LW $s0,($t2)
				J iterate	# rm_data_load is done go to iterate



    rm_data_store:
		LI $t1,0x11
		BEQ $t1,$s4,store1
		#store0
            ADD $t2, $a1, $a2
			SW $s0,($t2)
			J iterate	# rm_data_store is done go to iterate
		store1:
			ADD $t2, $a1, $a2
            ADDI $t2, $t2, 4
			SW $s0,($t2)
			J iterate	# rm_data_store is done go to iterate

    J iterate		# catchall for rm_data
.END rm_data


.ENT rm_math
rm_math:
	ANDI $t0, $s2, 0x0F00			# this segment checks the operation (see rm_data comments)
	SRL $t0, 8
    LI $t1, 0
	BEQ $t0, $t1, rm_math_add
    ADDI $t1, $t1, 1
    BEQ $t0, $t1, rm_math_subtract
	ADDI $t1, $t1, 1
	BEQ $t0, $t1, rm_math_multiply

	rm_math_add:
		LI $t0,0x0011
		BEQ $t0,$s4,add1
		#cell zero
        ADD $t2, $a1, $a2
		LW $t1,($t2)
		ADDU $s0,$s0,$t1
		J iterate
		add1:
		LW $t1,44($a1)
		ADDU $s0,$s0,$t1
		J iterate	# rm_math_add is done go to iterate
	rm_math_subtract:
		LI $t0,0x0011
		BEQ $t0,$s4,sub1
		#cell zero
        ADD $t2, $a1, $a2
		LW $t1,($t2)
		SUBU $s0,$s0,$t1
		J iterate
		sub1:
		LW $t1,44($a1)
		J iterate	# rm_math_subtract is done go to iterate
	rm_math_multiply:
		LI $t0,0x0011
		BEQ $t0,$s4,mul1
		#cell zero
        ADD $t2, $a1, $a2
		LW $t1,($t2)
		MUL $s0,$s0,$t1
		J iterate
		mul1:
		LW $t1,44($a1)
		J iterate	# rm_math_multiply is done go to iterate

    J iterate		# catchall for rm_math
.END rm_math


.ENT rm_branch
rm_branch:
	ANDI $t0, $s2, 0x0F00			# this segment checks the operation (see rm_data comments)
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
		ANDI $t0, $s2, 0x00FF	# 0x3007 branch to cell 7
		LI $t1, 4				# size of instruction to muliply to
		MUL $t0, $t0, $t1		# multiply the cell number ($t0) to the size of a word (t1) to get the byte address of the program counter
        LI $t2, 0xA0000200
        OR $a1, $t0, $t2
#		ADDI $s2, $t0, $a1		# change program counter
		J loop
	rm_branch_equal:
		BEQZ $s0,rm_branch_address
		J iterate
	rm_branch_not_equal:
		BEQZ $s0,iterate
		J rm_branch_address
    rm_branch_halt:
    J stop

    J iterate
.END rm_branch



.ENT rm_control
rm_control:
    ANDI $t0, $s2, 0x0F00
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
		#No robot so instead we turn PERF LD 3 on
			LI $t0,0b1000
			SW $t0,(LATB)
			# Count
		    MOVE $t6,$zero
		    # Max
		    MOVE $t7,$zero
		    ADDI $t7, 32767

		    loop0:
		   	 ADDI $t6,1
		   	 BEQ $t6,$t7,end0
		   	 NOP
		   	 NOP
		   	 NOP
		   	 NOP
		    J loop0
			end0:
				LI $t0,0x0
				SW $t0,(LATB)
				J iterate
	rm_control_right:
			#No robot so instead we turn PERF LD 0 on
			LI $t0,0b0001
			SW $t0,(LATB)
			# Count
		    MOVE $t6,$zero
		    # Max
		    MOVE $t7,$zero
		    ADDI $t7, 32767

		    loop1:
		   	 ADDI $t6,1
		   	 BEQ $t6,$t7,end1
		   	 NOP
		   	 NOP
		   	 NOP
		   	 NOP
		    J loop1
			end1:
				LI $t0,0x0
				SW $t0,(LATB)
				J iterate

	rm_control_foreward:
		#No robot so instead we have PERF LD 1 and 2 blink
			LI $t3,0
			start2:
			LI $t0,0b0110
			SW $t0,(LATB)
			# Count
		    MOVE $t6,$zero
		    # Max
		    MOVE $t7,$zero
		    ADDI $t7, 16000

		    loop2:
		   	 ADDI $t6,1
		   	 BEQ $t6,$t7,end2
		   	 NOP
		   	 NOP
		   	 NOP
		   	 NOP
		    J loop2
			end2:
				LI $t0,0x0
				SW $t0,(LATB)
				MOVE $t6,$zero
			    # Max
			    MOVE $t7,$zero
			    ADDI $t7, 16000

			    loop3:
			   	 ADDI $t6,1
			   	 BEQ $t6,$t7,end3
			   	 NOP
			   	 NOP
			   	 NOP
			   	 NOP
			    J loop3
			end3:
				LI $t2,1
				ADDI $t3,1
				BEQ $t2,$t3,start2
				J iterate
	rm_control_backward:
		#No robot so instead we turn PERF LD 1 and 2 on
			LI $t0,0b0110
			SW $t0,(LATB)
			# Count
		    MOVE $t6,$zero
		    # Max
		    MOVE $t7,$zero
		    ADDI $t7, 32767

		    loop4:
		   	 ADDI $t6,1
		   	 BEQ $t6,$t7,end4
		   	 NOP
		   	 NOP
		   	 NOP
		   	 NOP
		    J loop4
			end4:
				LI $t0,0x0
				SW $t0,(LATB)
				J iterate
	rm_control_brake:
		#no instructions for break I guess
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
