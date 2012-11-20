#include <p32xxxx.h>

#pragma config FNOSC	= PRIPLL
#pragma config FPLLMUL	= MUL_20
#pragma config FPLLDIV	= DIV_2
#pragma config FPBDIV	= DIV_2
#pragma config FPLLODIV	= DIV_1

.GLOBAL main
.DATA
# left 40, right 41, forward 42, backward 43, brake 44, advanced 45
# put program here
program: .word 0x4520, 0x4520, 0x4520, 0x4520, 0x4520, 0x4520, 0x4502, 0x4502, 0x4502, 0x4502, 0x4502, 0x4502, 0x4520, 0x4520, 0x4520, 0x4520, 0x4520, 0x4520, 0x4502, 0x4502, 0x4502, 0x4502, 0x4502, 0x4502, 0x3300, 0x80, 0x00
#program: .word 0x4501, 0x4512, 0x4522, 0x4521, 0x4510, 0x4500, 0x4502, 0x4520, 0x3300
#program: .word 0x4190, 0x4090, 0x4190, 0x4090, 0x4190, 0x4090, 0x4190, 0x4090, 0x4190, 0x4090, 0x3300, 0x80, 0x00
#program: .word 0x4090, 0x4210, 0x4190, 0x4210, 0x4090, 0x4210, 0x4190, 0x4210, 0x4090, 0x4210, 0x4190, 0x4210, 0x4090, 0x4210, 0x4190, 0x4210, 0x4090, 0x3300, 0x80, 0x00
#program: .word 0x4090, 0x4090, 0x4090, 0x4090, 0x4090, 0x4090, 0x4090, 0x3300, 0x80, 0x00
#program: .word 0x4190, 0x4190, 0x4190, 0x4190, 0x4190, 0x4190, 0x4190, 0x3300, 0x80, 0x00
#program: .word 0x4200, 0x4200, 0x4201, 0x4201, 0x4210, 0x4210, 0x4200, 0x4200, 0x3000, 0x3300, 0x80, 0x00
#program: .word 0x4300, 0x4300, 0x4301, 0x4301, 0x4310, 0x4310, 0x4300, 0x4300, 0x3000, 0x3300, 0x80, 0x00

.TEXT

.ENT main
main:
	DI
	JAL port_setup
	JAL setupMultiVectoredMode
	JAL setupOutputCompare2Module
	JAL setupOutputCompare3Module
	JAL setupTimer2
	JAL setupTimer3
	JAL enableOutputCompare2Int
	JAL enableOutputCompare3Int
	EI
	LA a1, program
	LI s1, 0

	loop:
		# fetch instruction
		ADDI s1, s1, 1
		LW s2, (a1)
		ANDI s3,s2,0xFF00
		ANDI s4,s2,0x00FF
		# decode it and branch
		LI t0, 1			# checksum for data class (1)
		SRL t1, s2, 12
		BEQ t0, t1, rm_data
		ADDI t0, t0, 1		# checksum for math class (2)
		BEQ t0, t1, rm_math
		ADDI t0, t0, 1		# checksum for branch class (3)
		BEQ t0, t1, rm_branch
		ADDI t0, t0, 1		# checksum for control class (4)
		BEQ t0, t1, rm_control
        LI t0, 0x3300
        BEQ t0, t1, stop
		# there is an error if reach this line
		J error
	iterate:
		# execute it
		ADDI a1, a1, 4	# iterate program counter to the next instruction
		LI t0,0xffff
		MOVE t1,zero
		delay:
			BEQ t0,t1,delay2
			ADDI t1,t1,1
			J delay
        MOVE t1, zero
        delay2:
            BEQ t0, t1, loop
            ADDI t1, t1,1
            J delay2



	end:
		LI t0,0x7fff
		MOVE t1,zero
		delaya:
			BEQ t0,t1,loop
			ADDI t1,t1,1
			J delaya


	error:					# this lable starts the error sequence flashing the led pmods very quickly
		J error
	stop:					# here to end the program
        JAL stop_both
        LI v0, 10
        syscall
    J stop
.END main

.ENT port_setup
	port_setup:

		SW zero, LATD

		LI t0, 0b11000110 # set rd 7,6,2,1 as output
		SW t0, TRISDCLR

		# set direction

		LW t0, PORTD
		ORI t0, t0, 0b01000000
		SW t0, LATD

		JR ra
.END port_setup

.ENT setupMultiVectoredMode
	setupMultiVectoredMode:

		ADDI sp, sp, -4
		SW s0, 0(sp)

		LA s0, INTCON
		LW t0, (s0)
		ORI t0, t0, 1 << 12
		SW t0, INTCON

		LW s0, 0(sp)
		ADDi sp, sp, 4

		JR ra
.END setupMultiVectoredMode

.ENT setupOutputCompare2Module
	setupOutputCompare2Module:

		# Preserve registers - push to stack
		ADDI sp, sp, -8
		SW ra, 4(sp)
		SW s0, 0(sp)

		# Ensure OC2 is off while setting up module 1
		LA s0, OC2CON # Output compare 1 control register
		MOVE t0, zero
		SW t0, (s0)

		# Initialize the OC2R register before the output compare module, this register determins duty cycle
		LA s0, OC2R
		LI t0, 0 # Shoot for 50% duty cycle, PR2 - 10,000
		SW t0, (s0)
		# The OC2RS secondary output compare register will contain the actual duty cycle
		LA s0, OC2RS
		LI t0, 0 # Shoot for 50% duty cycle
		SW t0, (s0)

		# Now configure the compare module using OC1CON
		# Bits 2:0 - 110 = PWM mode on OC1, 011 = compare event toggles OC1 pin
		# Bit 3 - 1 = Timer 3 clk src, 0 = Timer 2 clk src
		# Bit 5 - 1 = 32-bit comparisons, 0 = 16-bit comparisons
		# Bit 15 - 1 = enable output compare, 0 = disabled, not drawing current
		LA s0, OC2CON
		MOVE t0, zero
		ORI t0, t0, 6 # PWM mode
		ORI t0, t0, 1 << 15 # Enable output compare module
		SW t0, (s0)

		# Set priority of compare match interrupt IPC1<20:18>
		LA s0, IPC2SET
		LI t0, 6 # priority 6
		SLL t0, t0, 18
		SW t0, (s0)

		# Pop registers
		LW s0, 0(sp)
		LW ra, 4(sp)
		ADDI sp, sp, 8

		JR ra
.END setupOutputCompare2Module

.ENT setupOutputCompare3Module
	setupOutputCompare3Module:

	# Preserve registers - push to stack
		ADDI sp, sp, -8
		SW ra, 4(sp)
		SW s0, 0(sp)

		# Ensure OC1 is off while setting up module 1
		LA s0, OC3CON # Output compare 1 control register
		MOVE t0, zero
		SW t0, (s0)

		# Initialize the OC2R register before the output compare module, this register determins duty cycle
		LA s0, OC3R
		LI t0, 0 # Shoot for 50% duty cycle, PR2 - 10,000
		SW t0, (s0)
		# The OC2RS secondary output compare register will contain the actual duty cycle
		LA s0, OC3RS
		LI t0, 0 # Shoot for 50% duty cycle
		SW t0, (s0)

		# Now configure the compare module using OC1CON
		# Bits 2:0 - 110 = PWM mode on OC1, 011 = compare event toggles OC1 pin
		# Bit 3 - 1 = Timer 3 clk src, 0 = Timer 2 clk src
		# Bit 5 - 1 = 32-bit comparisons, 0 = 16-bit comparisons
		# Bit 15 - 1 = enable output compare, 0 = disabled, not drawing current
		LA s0, OC3CON
		MOVE t0, zero
		ORI t0, t0, 6 # PWM mode
		ORI t0, t0, 1 << 15 # Enable output compare module
		ORI t0, t0, 1 << 3  # Timer 3 clk src
		SW t0, (s0)

		# Set priority of compare match interrupt IPC3<20:18>
		LA s0, IPC3SET
		LI t0, 6 # priority 6
		SLL t0, t0, 18
		SW t0, (s0)

		# Pop registers
		LW s0, 0(sp)
		LW ra, 4(sp)
		ADDI sp, sp, 8

		JR ra
.END setupOutputCompare3Module

.ENT enableOutputCompare2Int
	enableOutputCompare2Int:

		# Preserve registers - push to stack
		ADDI sp, sp, -8
		SW ra, 4(sp)
		SW s0, 0(sp)

		LA s0, IEC0 # Interrupt enable control register - our mask register
		LW t0, (s0)
		ORI t0, t0, 1 << 10 # Set corresponding mask bit to 1 to enable, 6 is Output Compare Interrupt Enable 2 (OCIE1)
		SW t0, (s0)

		# Pop registers
		LW s0, 0(sp)
		LW ra, 4(sp)
		ADDI sp, sp, 8

		JR ra
.END enableOutputCompare2Int

.ENT enableOutputCompare3Int
	enableOutputCompare3Int:
		# Preserve registers - push to stack
		ADDI sp, sp, -8
		SW ra, 4(sp)
		SW s0, 0(sp)

		LA s0, IEC0 # Interrupt enable control register - our mask register
		LW t0, (s0)
		ORI t0, t0, 1 << 14 # Set corresponding mask bit to 1 to enable, 6 is Output Compare Interrupt Enable 1 (OCIE1)
		SW t0, (s0)

		# Pop registers
		LW s0, 0(sp)
		LW ra, 4(sp)
		ADDI sp, sp, 8

		JR ra
.END enableOutputCompare3Int

.ENT setupTimer2
	setupTimer2:

		ADDI sp, sp, -4
		SW s0, 0(sp)

		# stop timer 2
		LA s0, T2CON
		SW zero, (s0)

		# clear timer value
		LA s0, TMR2
		SW zero, (s0)

		# timer max value = 65,535
		LA s0, PR2
		LI t0, 99 # OCxR / PRx + 1 = duty cycle
		SW t0, (s0)

		LA s0, T2CON
		LI t0, 0x8050	# PBCLK /16, TMR2 on
		SW t0, (s0)


		# Pop registers
		LW s0, 0(sp)
		ADDI sp, sp, 4

		JR ra
.END setupTimer2

.ENT setupTimer3
	setupTimer3:

		ADDI sp, sp, -4
		SW s0, 0(sp)

		# T3CON - Control Register for Timer 3
		# Bit 15 - ON Timer On bit, 1 = timer enable, 0 disabled
		LA s0, T3CON
		SW zero, (s0) # stop timer 3

		LA s0, TMR3
		SW zero, (s0) # clear timer value

		LA s0, PR3
		LI t0, 99 # OCxR / PRx +1 = Duty cycle
		SW t0, (s0)

		# turn on and set pbclk / 64, 16 bit timer mode, use pbclk
		LA s0, T3CON
		LI t0, 0x8050
		SW t0, (s0)

		# pop register
		LW s0, 0(sp)
		ADDI sp, sp, 4

		JR ra
.END setupTimer3

.ENT rm_search_program
	rm_search_program:
		LI t0, 0				# t0 is the counter
		LI t1, 0x3300			# t1 is the checksum for end of program, (variables follow this instruction)
		ADD t2, zero, a1     # t2 is the copy of a1 fto protect it

		rm_search_program_loop:
			LW t3, 0(t2)							# load the first instruction into t3 (might be able to combine this and next line)
			BEQ t1, t3, rm_search_program_done	# if it is end of program branch to done
			ADDI t2, t2, 4						# else it is not a variable, increment temp program counter
			ADDI t0, t0, 4    					# increment counter by 4
			J rm_search_program_loop				# restart loop

		rm_search_program_done:
			ADDI t0, t0, 4	# increment t0 by 4 to put it at the first variable
			ADDI a2, t0, 0	# store t0 to a0(operand register) to preserve
			JR ra				# jump back to what called search
.END rm_search_program

.ENT rm_data
	rm_data:
		ADDI sp, sp, -4		# push ra to stack
		SW ra, 0(sp)
		JAL rm_search_program	# search for the first variable and store it in s4
		LW ra, 0(sp)
		ADDI sp, sp, 4		# pop ra from stack


		ANDI t0, s2, 0x0F00		# mask operation (second digit)
		SRL t0, 8					# shift right 8 for ease of access
		LI t1, 0					# t1 is the checksum
		BEQ t0, t1, rm_data_read
		ADDI t1, t1, 1			# t1 = 1
		BEQ t0, t1, rm_data_write
		ADDI t1, t1, 1			# t1 = 2
		BEQ t0, t1, rm_data_load
		ADDI t1, t1, 1			# t1 = 3
		BEQ t0, t1, rm_data_store
		J error						# hit this if there is an error


		# not sure if this is what is needed for this may need to rewrite this segment
		rm_data_read:
			ANDI t0, s2, 0xFF				# mask only operand of instruction
			LI t1, 0x10
			BEQ t1, t0, rm_data_read_var1	# check to see what variable 1 (0x01) or 2 (0x11)
			LI t1, 0x11
			BEQ t1, t0, rm_data_read_var2
			J error							# hit this if there is an error

			rm_data_read_var1:
				LW t0,(PORTE)
				ANDI t0,0xFF
				ADD t1, a1, a2
				SW s0,(t1)
				J iterate

			rm_data_read_var2:
				LW t0,(PORTE)
				ANDI t0,0xFF
				ADD t1, a1, a2
				ADDI t1, t1, 4
				SW s0,(t1)
				J iterate	# rm_data_load is done go to iterate

		rm_data_write:
				LI t1,0x11
				BEQ t1,s4,write1
				#write0
					LW t0,(PORTE)
					ADD t2, a1, a2
					LW t1,(t2)
					OR t0,t1,t0
					SW t0,(PORTE)
					J iterate	# rm_data_write is done go to iterate
				write1:
					LW t0,(PORTE)
					ADD t2, a1, a2
					ADDI t2, t2, 4
					LW t1,(t2)
					OR t0,t1,t0
					SW t0,(PORTE)
				J iterate	# rm_data_write is done go to iterate
		rm_data_load:
				LI t1,0x11
				BEQ t1,s4,load1
				#load0
				ADD t2, a1, a2
				LW s0,(t2)
					J iterate	# rm_data_load is done go to iterate

				load1:
					ADD t2, a1, a2
					ADDI t2, t2, 4
					LW s0,(t2)
					J iterate	# rm_data_load is done go to iterate



		rm_data_store:
			LI t1,0x11
			BEQ t1,s4,store1
			#store0
				ADD t2, a1, a2
				SW s0,(t2)
				J iterate	# rm_data_store is done go to iterate
			store1:
				ADD t2, a1, a2
				ADDI t2, t2, 4
				SW s0,(t2)
				J iterate	# rm_data_store is done go to iterate

		J iterate		# catchall for rm_data
.END rm_data

.ENT rm_math
	rm_math:
		ANDI t0, s2, 0x0F00			# this segment checks the operation (see rm_data comments)
		SRL t0, 8
		LI t1, 0
		BEQ t0, t1, rm_math_add
		ADDI t1, t1, 1
		BEQ t0, t1, rm_math_subtract
		ADDI t1, t1, 1
		BEQ t0, t1, rm_math_multiply

		rm_math_add:
			LI t0,0x0011
			BEQ t0,s4,add1
			#cell zero
			ADD t2, a1, a2
			LW t1,(t2)
			ADDU s0,s0,t1
			J iterate
			add1:
			LW t1,44(a1)
			ADDU s0,s0,t1
			J iterate	# rm_math_add is done go to iterate
		rm_math_subtract:
			LI t0,0x0011
			BEQ t0,s4,sub1
			#cell zero
			ADD t2, a1, a2
			LW t1,(t2)
			SUBU s0,s0,t1
			J iterate
			sub1:
			ADD t2, a1, a2
			LW t1,4(t2)
			J iterate	# rm_math_subtract is done go to iterate
		rm_math_multiply:
			LI t0,0x0011
			BEQ t0,s4,mul1
			#cell zero
			ADD t2, a1, a2
			LW t1,(t2)
			MUL s0,s0,t1
			J iterate
			mul1:
			ADD t2, a1, a2
			LW t1,4(t2)
			J iterate	# rm_math_multiply is done go to iterate

		J iterate		# catchall for rm_math
.END rm_math

.ENT rm_branch
	rm_branch:
		ANDI t0, s2, 0x0F00			# this segment checks the operation (see rm_data comments)
		SRL t0, 8
		LI t1, 0
		BEQ t0, t1, rm_branch_address
		ADDI t1, t1, 1
		BEQ t0, t1, rm_branch_equal
		ADDI t1, t1, 1
		BEQ t0, t1, rm_branch_not_equal
		ADDI t1, t1, 1
		BEQ t0, t1, rm_branch_halt

		rm_branch_address:
			ANDI t0, s2, 0x00FF	# 0x3007 branch to cell 7
			LI t1, 4				# size of instruction to muliply to
			MUL t0, t0, t1		# multiply the cell number (t0) to the size of a word (t1) to get the byte address of the program counter
			LI t2, 0xA0000200
			OR a1, t0, t2
			J loop
		rm_branch_equal:
			BEQZ s0,rm_branch_address
			J iterate
		rm_branch_not_equal:
			BEQZ s0,iterate
			J rm_branch_address
		rm_branch_halt:
			J stop

		J iterate
.END rm_branch

.ENT rm_control
	rm_control:
		ANDI t0, s2, 0x0F00		# mask direction
		SRL t0, 8
		LI t1, 0
		BEQ t0, t1, rm_control_left
		ADDI t1, t1, 1    #t1 = 1
		BEQ t0, t1, rm_control_right
		ADDI t1, t1, 1    #t1 = 2
		BEQ t0, t1, rm_control_forward
		ADDI t1, t1, 1    #t1 = 3
		BEQ t0, t1, rm_control_backward
		ADDI t1, t1, 1	#t1 = 4
		BEQ t0, t1, rm_control_brake
        ADDI t1, t1, 1  #t1 = 5
        BEQ t0, t1, rm_control_advanced

		rm_control_left:
			# Preserve registers - push to stack
			ADDI sp, sp, -8
			SW ra, 4(sp)
			SW a0, 0(sp)

			LI a0, 0b1111100011 # forward right wheel speed=99
			JAL start_motor

			LI a0,1
			JAL stop_motor

			# pop pushed registers
			LW a0, 0(sp)
			LW ra, 4(sp)
			ADDI sp, sp, 8
			J iterate

		rm_control_right:
			# 6:0 = speed: (0-99)
			# 8:7 = wheel: 3 = both, 2 = right, 1 = left
			# 9 = direction: 1 = forward, 0 = reverse
			# Preserve registers - push to stack
			ADDI sp, sp, -8
			SW ra, 4(sp)
			SW a0, 0(sp)

			LI a0,0b1011100011	# forward wheel left speed 99
			JAL start_motor

			LI a0,2
			JAL stop_motor

			# Pop registers
			LW a0, 0(sp)
			LW ra, 4(sp)
			ADDI sp, sp, 8
			J iterate

		rm_control_forward:
			# 6:0 = speed: (0-99)
			# 8:7 = wheel: 3 = both, 2 = right, 1 = left
			# 9 = direction: 1 = forward, 0 = reverse
			# Preserve registers - push to stack
			ADDI sp, sp, -8
			SW ra, 4(sp)
			SW a0, 0(sp)
			ANDI t0, s2, 0xFF	# 00 = slow 01 = medium 10 = fast
			ADDI t0, t0, 1		# 1 = 50% 2 = 70% 3 = 90%
			MUL t0, t0, 20		# multiply to equal percentage
			ADDI t0, t0, 30
			LI a0,0b1110000000
			OR a0, a0, t0		# save percentage in a0 command
			JAL start_motor

			# Pop registers
			LW a0, 0(sp)
			LW ra, 4(sp)
			ADDI sp, sp, 8
			J iterate

		rm_control_backward:
			# 6:0 = speed: (0-99)
			# 8:7 = wheel: 3 = both, 2 = right, 1 = left
			# 9 = direction: 1 = forward, 0 = reverse
			ADDI sp, sp, -8
			SW ra, 4(sp)
			SW a0, 0(sp)

			LI a0,3 # stop both motors
			JAL stop_motor

			ANDI t0, s2, 0xFF	# 00 = slow 01 = medium 10 = fast
			ADDI t0, t0, 1		# 1 = 30% 2 = 60% 3 = 90%
			MUL t0, t0, 30		# multiply to equal percentage
			LI a0,0b0110000000
			OR a0, a0, t0		# save percentage in a0 command
			JAL start_motor


			# Pop registers
			LW a0, 0(sp)
			LW ra, 4(sp)
			ADDI sp, sp, 8

			J iterate

		rm_control_brake:
			# Preserve registers - push to stack
			ADDI sp, sp, -8
			SW ra, 4(sp)
			SW a0, 0(sp)

			LI a0,3
			JAL stop_motor

			# Pop registers
			LW a0, 0(sp)
			LW ra, 4(sp)
			ADDI sp, sp, 8
			J iterate
.END rm_control

.ENT rm_control_advanced
	rm_control_advanced:
		# arguments are stored in a0
		# 6:0 = speed (0-99)
		# 8:7 = wheel 3 = both, 2 = right, 1 = left
		# 9 = direction 1 = forward, 0 = back
        ADDI sp, sp, -8
		SW ra, 4(sp)
		SW a0, 0(sp)

		# left wheel
		ANDI t0, s2, 0xF0		# mask speed
		SRL t0, 4				# shift speed 
		ADDI t0, t0, 1				# add 1 to make it multiplyable
		MUL t0, t0, 20			# multiply to get a bigger duty cycle
		ADDI t0, t0, 30			# add constant to increase duty cycle further
		LI a0, 0b1010000000		# load left wheel command
		OR a0, a0, t0			# or speed with left wheel
		JAL start_motor


		# right wheel
		ANDI t0, s2, 0xF		# mask speed
		ADDI t0, t0, 1			# add 1 to make it multiplyable
		MUL t0, t0, 20			# multiply to get a bigger duty cycle
		ADDI t0, t0, 30			# add constant to increase duty cycle further
    #   SW t0, OC3RS
		LI a0, 0b1100000000		# load left wheel command
		OR a0, a0, t0			# or speed with left wheel
		JAL start_motor

		# pop registers
		LW ra, 4(sp)
		LW a0, 0(sp)
		ADDI sp, sp, 8
	J iterate
.END rm_control_advanced

.ENT stop_motor
	stop_motor:
		LI t0,1
		BEQ t0,a0,stopleft
		ADDI t0,t0,1
		BEQ t0,a0,stopright

		stop_both:
			LI t0, 0
			SW t0, OC2RS
			SW t0, OC3RS
			LI t0, 1 << 1
			SW t0, TRISDSET
			LI t0, 1 << 2
			SW t0, TRISDSET
			JR ra
		stopleft:
			LI t0, 0
			SW t0, OC3RS
			LI t0, 1 << 1
			SW t0, TRISDSET
			JR ra
		stopright:
			LI t0, 0
			SW t0, OC2RS
			LI t0, 1 << 2
			SW t0, TRISDSET
			JR ra
.END stop_motor

.ENT start_motor
	start_motor:
		# arguments are stored in a0
		# 6:0 = speed (0-99)
		# 8:7 = wheel 3 = both, 2 = right, 1 = left
		# 9 = direction 1 = forward, 0 = back
		ADDI sp, sp, -8
		SW a0, 0(sp)
		SW ra, 4(sp)

		# mask direction and set direction
		ANDI t0, a0, 0b1000000000
		SRL t0, t0, 9
		LI t1, 1
		BEQ t0, zero, set_reverse
		BEQ t0, t1, set_forward
		
		set_reverse: # direction pins are PORTD 7:6
			# Turn motors off before changing direction
            LW t2, OC2RS
            LW t3, OC3RS
			SW zero, OC2RS
			SW zero, OC3RS
			LI t0, 0b110
			SW t0, TRISDSET

            # set direction of motors
			LI t0, 0b10000000
			SW t0, LATDSET
			LI t0, 0b01000000
			SW t0, LATDCLR
			
			# Turn on motors after changing direction
			SW t2, OC2RS
			SW t3, OC3RS
			LI t0, 0b110
			SW t0, TRISDCLR
			J start_motor_sequence

		set_forward: # direction pins are PORTD 7:6
			# Turn motors off before changing direction
            LW t2, OC2RS
            LW t3, OC3RS
			SW zero, OC2RS
			SW zero, OC3RS
			LI t0, 0b110
			SW t0, TRISDSET
			
			# Set direction of motors
            LI t0, 0b10000000
			SW t0, LATDCLR
            LI t0, 0b01000000
            SW t0, LATDSET

            # Turn on motors after changing direction
            SW t2, OC2RS
            SW t3, OC3RS
            LI t0, 0b110
            SW t0, TRISDCLR
			J start_motor_sequence
		
		# Start motors
		# arguments are stored in a0
		# 6:0 = speed (0-99)
		# 8:7 = wheel 3 = both, 2 = right, 1 = left
		# 9 = direction 1 = forward, 0 = back
		start_motor_sequence:
			ANDI t0,a0,	0b110000000	# mask wheel command
			LI t1,		0b010000000	# mask left wheel
			BEQ t1,t0,startleft
			LI t1,		0b110000000	# mask both wheels
			BEQ t1,t0,startboth

			# start individual motors
			startright:
				ANDI t0,a0,0x7F		# mask speed
				SW t0,OC2RS         # set speed
				LI t0, 1 << 2
				SW t0, TRISDCLR		# set right motor to output
				J end_motor_sequence

			startleft:
				ANDI t0,a0,0x7F		# mask speed
				SW t0,OC3RS			# set speed
				LI t0, 1 << 1
				SW t0, TRISDCLR		# set left motor to output
                LI t0, 0xFFF
                extradelay:
                ADDI t0, t0, -1
                BNE t0, zero, extradelay
				J end_motor_sequence

			startboth:
				ANDI t0,a0,0x7F		# mask speed
				#SLL t0, t0, 5
				SW t0,OC2RS			# set both speeds
				SW t0,OC3RS
				LI t0, 0b110		# set both motors to output
				SW t0, TRISDCLR
				J end_motor_sequence
			
		end_motor_sequence:
			LW a0, 0(sp)
			LW ra, 4(sp)
			ADDI sp, sp, 8
			JR ra
.END start_motor
