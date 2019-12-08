; Oscilloscope.s - Jake Tucker, Ryan Gloekler, Zane Miller
; Display a microphone input on the Nokia screen as a waveform
; Include StartupNokia.s, ATDonline.s, and Nokia5110-Class.s
;***************************************************************
; Program section
;***************************************************************
			AREA	img,DATA,READWRITE
waveimg		SPACE	504		; Space for waveform image
currsamp	SPACE	1		; Move current sample from interrupt to main
samps		SPACE	84		; Space for samples
			AREA    |.text|, READONLY, CODE
			THUMB
			; Interupt symbols
NVIC_ST_CTRL		EQU		0xE000E010
NVIC_ST_RELOAD  	EQU		0xE000E014
NVIC_ST_CURRENT		EQU		0xE000E018
SHP_SYSPRI3	    	EQU		0xE000ED20 	
RELOAD_VALUE		EQU		440		; 110 uS
; EQUs used for memory location & analog comparator setup
ACMP_BASE			EQU		0x4003C000
BASE				EQU		0x400FE000 ; base address for the analog comparator
RCGCACMP			EQU		0x63C	    ; offset for the ACMP Run Mode Clock Gating Control
ACCTL				EQU		0x024		; offset for Analog Comparator Control
ACREFCTL			EQU		0x010		; offset for Analog Comp. Reference Voltage Control
ACRIS				EQU		0x004		; offset for Analog Comp. Raw Interrupt Status
RCGCGPIO			EQU     0x608		; offset for GPIO enable
FIRST				EQU		0x20000400
GPIO_PORTA_DATA		EQU		0x400043FC	; Port A Data
GPIO_PORTC_DIR   	EQU 	0x40006400	; Port Direction
GPIO_PORTC_AFSEL 	EQU 	0x40006420	; Alt Function enable
GPIO_PORTC_DEN   	EQU 	0x4000651C	; Digital Enable
GPIO_PORTC_AMSEL 	EQU 	0x40006528	; Analog enable
GPIO_PORTC_PCTL  	EQU		0x4000652C	; Alternate Functions
			EXTERN	Nokia_Init
			EXTERN	OutImgNokia
			EXTERN	ATD_Init
			EXTERN	ATD_Sample
			EXTERN	Out1BNokia
			EXPORT	Start
Start		BL		Nokia_Init			; initialize LCD
; Setup ATD
			BL		ATD_Init		; Initialize ATD for PE3 pin measurement
			BL 		systick_ini		; initialize systick for interrupts
			BL		analogCMP_ini	; initialize analog comparator
			; set up the analog comparator and poll until 
			; we are ready to start sampling (WFI)
mloop		LDR		R1,=ACMP_BASE
			MOV		R0,#1			; Clear status of comparator
			STR		R0,[R1]
			LDR		R1,=ACMP_BASE + ACRIS
edgechk		LDRB	R0,[R1]			; Check status of comparator
			ANDS	R0,#1			; Check bit 0 - has interrupt occurred?
			BEQ		edgechk			; If not, check again
			MOV		R2,#84			; Use R2 to count remaining samples
			LDR		R1,=samps		; R1 indexes the sample array
			LDR		R3,=currsamp	; R3 grabs the current sample
			CPSIE  I				; Ready to wait for samples
			
wait   		WFI						; Wait for the interrupt to run
			LDRB	R0,[R3]			; Grab the sample
			STRB	R0,[R1],#1		; Store the sample, increment
			SUBS	R2,#1			; Sample done, was this last?
			BNE		wait			; If not, wait again
			
			CPSID	I				; Give screen time to display
			BL 		imgwav			; Create image of waveform
			LDR		R5,=waveimg		; Load location in memory
			BL		OutImgNokia		; Display this message on screen
			LDR		R2,=400000		; Wait
delayend	SUBS	R2,#1
			BNE		delayend
			B		mloop			; Done, next waveform
;*********************************************************************
; Value scaling: Converts ATD output to vertical pixel position
scale_value
		SUB R0, #0x974		; 1.9 V recorded as 0x974
		MOV R1, #0x30		; Multiply by screen height (0x30 px)
		MUL R0, R1
		MOV R1, #0xF8		; Divide by range - 0.2 V recorded as 0xF8
		UDIV R0, R1
		CMP R0, #0x30		; Is this a valid pixel position?
		BLO valid			; If so, return it in R0
		CMP	R0, #0x1000		; If not, map to an edge of the screen
		MOVLO R0, #0x2F		; Voltage over, no overflow, map to bottom
		MOVHS R0, #0x00		; Voltage under, underflow, map to top
valid   BX LR
;*********************************************************************
; Initialize the analog comparator. Trigger: falling edge, 2.0 V
analogCMP_ini
; Enable the analog comparator clock by writing a value of 0x0000.0001
; to the RCGCACMP register in the System Control module
		PUSH	{R0}
		MOV 	R0, #0x01
		LDR		R1,=BASE + RCGCACMP
		STR 	R0, [R1] ; storing the correct value in control module
		LDR		R1,=GPIO_PORTC_DIR		; Set up port C direction
		MOV 	R0, #0x40            	; Make PC7 input, others unused
		STR		R0,[R1]
		LDR		R1,=GPIO_PORTC_AFSEL	; Enable alt funct on PC7
		MOV 	R0, #0x40
		STR		R0,[R1]
		LDR		R1,=GPIO_PORTC_AMSEL	; Enable analog on PC7
		MOV 	R0, #0x40
		STR		R0,[R1]
		LDR		R1,=ACMP_BASE + ACCTL	; Configure comparator:
		MOV		R0,#0x402				; set bits 10 and 2
		STR		R0,[R1]					; for internal ref, falling edge
		LDR		R1,=ACMP_BASE + ACREFCTL; Configure reference:
		MOV		R0,#0x20B				; set bit 9 to enable
		STR		R0,[R1]					; and set bits 3:0 to 0xB for ~2V
		POP		{R0}
		BX		LR
;********************************************************************
; SysTick initialization: same as used in lab 7
systick_ini							;initialize interupts subroutine
    	PUSH	{R0}
		MOV 	R0, #0
		LDR 	R1,=NVIC_ST_CTRL
    	STR 	R0, [R1]			; Turn Off Systick
		LDR 	R1,=NVIC_ST_RELOAD
    	LDR 	R0, =RELOAD_VALUE	
    	STR 	R0, [R1]    		; Set reload value
		LDR 	R1,=NVIC_ST_CURRENT
	    STR 	R0, [R1]			; Reset current counter value
		LDR 	R2, =SHP_SYSPRI3	 
    	MOV 	R0, #0x40000000		; Systick interrupt priority > 0
		STR 	R0, [R2]
    	MOV 	R0, #0x03 			; Turn on Systick with Precision Clock
		LDR 	R1,=NVIC_ST_CTRL
    	STR 	R0, [R1]    	;  and enabling interrupts	
		POP		{R0}
		BX LR
;********************************************************************
; Image waveform generator: generates an image from set of coordinates
imgwav
		PUSH	{LR}
		LDR		R7,=GPIO_PORTA_DATA
		LDRB	R0,[R7]
		BIC		R0,#0x40	; Set PA6 low for command
		STR		R0,[R7]
		MOV		R5,#0x40	; Reset Y address
		BL		Out1BNokia
		MOV		R5,#0x80	; Reset X address
		BL		Out1BNokia
		LDR		R1,=samps	; Load location of samples
		LDR		R2,=waveimg	; Load location of waveform image
		MOV		R3,#84		; Loop 84 columns
imgcol	LDRB	R0,[R1],#1	; Load sample
		MOV		R4,#6		; Loop 6 bytes
imgrow	CMP		R0,#8		; Is R0 in this byte?
		MOVLO	R5,#1		; If so, store in in R5
		LSLLO	R5,R0
		MOVHS	R5,#0		; Otherwise, store 0
		STRB	R5,[R2],#1	; Store byte of image
		SUB		R0,#8		; Check if R0 is in next byte
		SUBS	R4,#1		; Byte finished
		BNE		imgrow		; Loop until end of column
		SUBS	R3,#1		; Column finished
		BNE		imgcol		; Loop until end of image
		POP		{LR}		; Image complete
		BX		LR
;*******************************************************************
; SysTick handler: grabs samples at defined intervals
	EXPORT	SysTick_Handler
SysTick_Handler
		PUSH {LR}
		BL		ATD_Sample		; do ATD conversion into r0
		BL 		scale_value		; scale the value to a screen coordinate
		LDR		R1,=currsamp
		STRB	R0,[R1]			; store the sample for the main code
		POP {LR}
		BX LR
			ALIGN
			END