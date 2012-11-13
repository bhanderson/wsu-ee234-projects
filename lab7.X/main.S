// Include necessary standard and user-defined libraries
#include <p32xxxx.h>

// Setup the PB clock to 40MHz
// SYSCLK = 80 MHz (8MHz / FPLLIDIV * FPLLMUL / FPLLODIV)

#pragma config FNOSC	= PRIPLL
#pragma config FPLLMUL	= MUL_20
#pragma config FPLLDIV	= DIV_2
#pragma config FPBDIV	= DIV_2
#pragma config FPLLODIV	= DIV_1

.GLOBAL main
.DATA                        # The start of the data segment

program: .word 0x1011, 0x1211, 0x2110, 0x3106, 0x4190, 0x3007, 0x4910, 0x4201, 0x4403, 0x3300, 0x80, 0x00

.TEXT                       # The start of the code segment

.ENT main					# Setup a main entry point
main:
	DI						# Disable system wide interrupts

	JAL disableTimer2Int	# Disable Timer 1 interrupt;
	JAL disableTimer3Int
	JAL port_setup
    LA a1, program			# Load the program instructions into program memory
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
	   # there is an error if reach this line
	   J error
	iterate:
       # execute it
		ADDI a1, a1, 4	# iterate program counter to the next instruction

	end:
		J loop				# Embedded programs require that they run forever! So jump back to the beginning of the loop

	error:					# this lable starts the error sequence flashing the led pmods very quickly
		LI t0, 0xF
		SW t0, (LATB)
		LI t0, 0
		SW t0, (LATB)
		J error
	stop:					# here to end the program
        LI v0, 10
        syscall
    J stop
.END main


.ENT rm_search_program
rm_search_program:
	LI t0, 0				# t0 is the counter
	LI t1, 0x3300			# t1 is the checksum for end of program, (variables follow this instruction)
	ADD t2, zero, a1     # t2 is the copy of a1 to protect it

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
    ANDI t0, s2, 0x0F00
    SRL t0, 8
    LI t1, 0
    BEQ t0, t1, rm_control_left
    ADDI t1, t1, 1    #t1 = 1
    BEQ t0, t1, rm_control_right
    ADDI t1, t1, 1    #t1 = 2
    BEQ t0, t1, rm_control_foreward
    ADDI t1, t1, 1    #t1 = 3
    BEQ t0, t1, rm_control_backward
	ADDI t1, t1, 1	#t1 = 4
	BEQ t0, t1, rm_control_brake

	rm_control_left:
		J iterate
	rm_control_right:
		J iterate

	rm_control_foreward:
		J iterate
	rm_control_backward:
		J iterate
	rm_control_brake:
		J iterate
.END rm_control


.ENT rm_control_advanced
rm_control_advanced:
	rm_control_advanced_left:
	rm_control_advanced_right:
	rm_control_advanced_foreward:
	rm_control_advanced_brake:
	
.END rm_control_advanced

.ENT port_setup
port_setup:
	# Set these to pins to outputs
	# First Motor H-bridge: DIR - RG09; EN RG08
	LI t0, 1 << 9
	SW t0, TRISGCLR
	LI t0, 1 << 8
	SW t0, TRISGCLR
	# Second Motor H-bridge: DIR - RB15; EN RD05
	LI t0, 1 << 15
	SW t0, TRISBCLR
	LI t0, 1 << 5
	SW t0, TRISDCLR
	
	# LEDs LD4:1 RB13:10 - digital output
	LA s0, TRISB
	LW t0, (s0)
	ANDI t0, t0, 0x3C00
	SW t0, (s0)

	JR ra

.END port_setup

.ENT setupMultiVectoredMode
setupMultiVectoredMode:

	# Preserve registers - push to stack
	ADDI sp, sp, -8
	SW ra, 4(sp)
	SW s0, 0(sp)
	
	# Interrupt control register
	LA s0, INTCON # Register necessary for setting multi-vectored mode
	LW t0, (s0)
	ORI t0, t0, 1 << 12 # Set for mutli-vectored mode
	SW t0, INTCON

	# Pop registers
	LW s0, 0(sp)
	LW ra, 4(sp)
	ADDI sp, sp, 8
	
	JR ra

.END setupMultiVectoredMode

.ENT setupOutputCompare1Module
setupOutputCompare1Module:

	# Preserve registers - push to stack
	ADDI sp, sp, -8
	SW ra, 4(sp)
	SW s0, 0(sp)

	# Ensure OC1 is off while setting up module 1
	LA s0, OC1CON # Output compare 1 control register
	MOVE t0, zero
	SW t0, (s0)
	
	# Initialize the OC1R register before the output compare module, this register determins duty cycle
	LA s0, OC1R
	LI t0, 0x0 # Shoot for 0% duty cycle, PR2 - 10,000
	SW t0, (s0)
	# The OC1RS secondary output compare register will contain the actual duty cycle
	LA s0, OC1RS
	LI t0, 0x0 # Shoot for 0% duty cycle
	SW t0, (s0)

	# Now configure the compare module using OC1CON
	# Bits 2:0 - 110 = PWM mode on OC1, 011 = compare event toggles OC1 pin
	# Bit 3 - 1 = Timer 3 clk src, 0 = Timer 2 clk src
	# Bit 5 - 1 = 32-bit comparisons, 0 = 16-bit comparisons
	# Bit 15 - 1 = enable output compare, 0 = disabled, not drawing current
	LA s0, OC1CON
	MOVE t0, zero
	ORI t0, t0, 6 # PWM mode
	ORI t0, t0, 1 << 15 # Enable output compare module
	SW t0, (s0)
	
	# Set priority of compare match interrupt IPC1<20:18>
	LA s0, IPC1SET
	LI t0, 6 # priority 6
	SLL t0, t0, 18
	SW t0, (s0)

	# Pop registers
	LW s0, 0(sp)
	LW ra, 4(sp)
	ADDI sp, sp, 8
	
	JR ra
	
.END setupOutputCompare1Module

.ENT enableOutputCompare1Int
enableOutputCompare1Int:
	
	# Preserve registers - push to stack
	ADDI sp, sp, -8
	SW ra, 4(sp)
	SW s0, 0(sp)
	
	LA s0, IEC0 # Interrupt enable control register - our mask register
	LW t0, (s0)
	ORI t0, t0, 1 << 6 # Set corresponding mask bit to 1 to enable, 6 is Output Compare Interrupt Enable 1 (OCIE1)
	SW t0, (s0)

	# Pop registers
	LW s0, 0(sp)
	LW ra, 4(sp)
	ADDI sp, sp, 8
	
	JR ra
	

.END enableOutputCompare1Int


.SECTION .vector_6, code
	J OutputCompare1IntHandler
.TEXT

.ENT OutputCompare1IntHandler
OutputCompare1IntHandler:

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

	# Clear Output Compare 1 Interrupt status flag
	LA t0, IFS0CLR
	LW t1, (t0)
	ORI t1, t1, 1 << 6 
	SW t1, (t0)

	# Can set new duty cycle in this handler
	# Use OC1RS, the secondary compare register
	
	LA t0, LATGINV
	LI t1, 3
	SW t1, (t0)

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

.END OutputCompare1IntHandler

.ENT setupOutputCompare2Module
setupOutputCompare2Module:

	# Preserve registers - push to stack
	ADDI sp, sp, -8
	SW ra, 4(sp)
	SW s0, 0(sp)

	# Ensure OC1 is off while setting up module 1
	LA s0, OC2CON # Output compare 1 control register
	MOVE t0, zero
	SW t0, (s0)
	
	# Initialize the OC1R register before the output compare module, this register determins duty cycle
	LA s0, OC2R
	LI t0, 0x0 # Shoot for 0% duty cycle, PR2 - 10,000
	SW t0, (s0)
	# The OC1RS secondary output compare register will contain the actual duty cycle
	LA s0, OC2RS
	LI t0, 0x0 # Shoot for 0% duty cycle
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
	ORI t0, t0, 1 << 3  # Timer 3 clk src
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

.ENT enableOutputCompare2Int
enableOutputCompare2Int:
	

	# Preserve registers - push to stack
	ADDI sp, sp, -8
	SW ra, 4(sp)
	SW s0, 0(sp)
	
	LA s0, IEC0 # Interrupt enable control register - our mask register
	LW t0, (s0)
	ORI t0, t0, 1 << 10 # Set corresponding mask bit to 1 to enable, 6 is Output Compare Interrupt Enable 1 (OCIE1)
	SW t0, (s0)

	# Pop registers
	LW s0, 0(sp)
	LW ra, 4(sp)
	ADDI sp, sp, 8
	
	JR ra
	
.END enableOutputCompare2Int

.SECTION .vector_10, code
	J OutputCompare2IntHandler
.TEXT


.ENT OutputCompare2IntHandler
OutputCompare2IntHandler:

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

	# Clear Output Compare 1 Interrupt status flag
	LA t0, IFS0CLR
	LW t1, (t0)
	ORI t1, t1, 1 << 10 
	SW t1, (t0)

	# Can set new duty cycle in this handler
	# Use OC1RS, the secondary compare register
	
	LA t0, LATGINV
	LI t1, 1 << 13
	SW t1, (t0)

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

.END OutputCompare2IntHandler




.ENT setupTimer3
setupTimer3:

	ADDI sp, sp, -4
	SW s0, 0(sp)

	# T3CON - Control Register for Timer 3
	# Bit 15 - ON Timer On bit, 1 = timer enable, 0 disabled
	LA s0, T3CON
	SW zero, (s0) # stop timer 3
	
	LA s0, TMR2
	SW zero, (s0) # clear timer value

	LA s0, PR3
	LI t0, 0x2710 # Period register of 10,000 base 10
	SW t0, (s0)
	
	# turn on and set pbclk / 64, 16 bit timer mode, use pbclk
	LA s0, T3CON
	LI t0, 0x8050
	SW t0, (s0)

	# Set priority
	LA s0, IPC3			# Interrupt priority register for Timer 3
	LW t0, (s0)
	ORI t0, t0, 6 << 2	# priority of 6
	SW t0, (s0)

	# pop register
	LW s0, 0(sp)
	ADDI sp, sp, 4

	JR ra

.END setupTimer3

.ENT enableTimer3Int
enableTimer3Int:

	ADDI sp, sp, -4
	SW s0, 0(sp)
	
	LA s0, IEC0
	
	LW t0, (s0)
	ORI t0, t0, 1 << 12 # mas 1 to enable, 12 is T3IE position
	SW t0, (s0)

	LW s0, 0(sp)
	ADDI sp, sp, 4

.END enableTimer3Int

.ENT disableTimer3Int
disableTimer3Int:
	
	ADDI sp, sp, -4
	SW s0, 0(sp)
	
	LA s0, IEC0CLR		# clear bit disable Timer 2 interrupt
	LI t1, 1 << 12
	SW t1, (s0)

	LW s0, 0(sp)
	ADDI sp, sp, 4

	JR ra

.END disableTimer3Int

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
	LI t0, 0x2710 # PRx 10,000
	SW t0, (s0)

	LA s0, T2CON
	LI t0, 0x8050	# PBCLK /16, TMR2 on
	SW t0, (s0)

	# Set priority
	LA s0, IPC2			# Interrupt priority register for Timer 2
	LW t0, (s0)			# IPC2 T2IP <4:2> for Timer 2
	ORI t0, t0, 6 << 2	# priority 6
	SW t0, (s0)

	# Pop registers
	LW s0, 0(sp)
	ADDI sp, sp, 4

	JR ra

.END setupTimer2

.ENT enableTimer2Int
enableTimer2Int:

	ADDI sp, sp, -4
	SW s0, 0(sp)

	LA s0, IEC0

	LW t0, (s0)
	ORI t0, t0, 1 << 8	# mask 1 to enable, 8 is T2IE positioni
	SW t0, (s0)

	LW s0, 0(sp)
	ADDI sp, sp, 4

	JR ra
.END enableTimer2Int


.ENT disableTimer2Int
disableTimer2Int:
	
	ADDI sp, sp, -4
	SW s0, 0(sp)

	LA s0, IEC0CLR		# clear bit disable Timer 2 interrupt
	LI t1, 1 << 8
	SW t1, (s0)

	LW s0, 0(sp)
	ADDI sp, sp, 4

	JR ra

.END disableTimer2Int
