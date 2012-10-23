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
