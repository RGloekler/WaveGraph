;****************************************
; NokiaTest-Class-main.s
; Used to test Nokia5110-Class.s
; inlcude startup.s


;***************************************************************
; Program section
;***************************************************************
			
;LABEL		DIRECTIVE	VALUE			COMMENT
			AREA	img,DATA,READWRITE
waveimg		SPACE	504		; Space for waveform image
			AREA    |.text|, READONLY, CODE
			THUMB

tstmsg		DCB		"This is some          text",0x04
			SPACE	0		; added for padding
Stack           	EQU		0x00000400		; Stack size
			; Interupt symbols
NVIC_ST_CTRL		EQU		0xE000E010
NVIC_ST_RELOAD  	EQU		0xE000E014
NVIC_ST_CURRENT		EQU		0xE000E018
SHP_SYSPRI3	    	EQU		0xE000ED20 	
RELOAD_VALUE		EQU		10000000		; 110 uS
; EQUs used for memory location & analog comparator setup
ACMP_BASE			EQU		0x4003C000
BASE				EQU		0x400FE000 ; base address for the analog comparator
RCGCACMP			EQU		0x63C	    ; offset for the ACMP Run Mode Clock Gating Control
RCGCGPIO			EQU     0x608		; offset for GPIO enable
FIRST				EQU		0x20000400
GPIO_PORTA_DATA			EQU	0x400043FC	; Port A Data

				
			EXTERN	Nokia_Init
			EXTERN	OutImgNokia
			EXTERN	SetXYNokia
			EXTERN	Out1BNokia
			EXTERN	OutStrNokia
			EXTERN	ClearNokia

			EXPORT  Start
			EXTERN 	OutChar
			EXTERN  OutStr
			EXTERN	UART_Init
			EXTERN	Out2BSP
			EXTERN	ATD_Init
			EXTERN	ATD_Sample

Start		BL		Nokia_Init			; initialize LCD
; Setup UART
			;BL		UART_Init		; Initialize UART at 9600 baud, 16 MHz clock
; Setup ATD
			BL		ATD_Init		; Initialize ATD for PE3 pin measurement
			BL 		systick_ini		; initialize systick for interrupts
			
			; set up the analog comparator and poll until 
			; we are ready to start sampling (WFI)
			
			CPSIE  I
wait   		WFI
			B wait


delay		PUSH	{R0}
			MOV		R0,#0x8555
			MOVT	R0,#0x0140
del			SUBS	R0,#1
			BNE		del
			POP		{R0}
			BX		LR

delayTrans	PUSH	{R0}
			MOV		R0,#0x5855			;~250ms
			MOVT	R0,#0x0014
dt			SUBS	R0,#1
			BNE		dt
			POP		{R0}
			BX		LR


scale_value
		SUB R0, #0x8F8 ; code for scaling the result of ATD
		MOV R1, #0x30
		MUL R0, R1
		MOV R1, #0x175
		UDIV R0, R1
		CMP R0, #0x30
		BLO valid
		MOV R0, #0x2F
valid   
		BX LR



analogCMP_ini
			; set up the analog comparator to 
			; trigger on a rising edge, compared 
			; to the reference voltage (+ 2.0 V)
			
; Enable the analog comparator clock by writing a value of 0x0000.0001 to the RCGCACMP
; register in the System Control module
		PUSH	{LR, R0}
		MOV 	R0, #0x01
		LDR		R1,=BASE + RCGCACMP
		STR 	R0, [R1] ; storing the correct value in control module
		
		MOV 	R0, #0x02
		LDR 	R1,=BASE + RCGCGPIO
		STR		R0, [R1] ; this enables GPIO Port C for ACMP
		
		


systick_ini							;initialize interupts subroutine
		;LDR 	R1, =NVIC_ST_BASE	; Use this base for Systick registers
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
		LDR		R1,=FIRST	; Load location of samples
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
		
	EXPORT	SysTick_Handler
SysTick_Handler
		PUSH {LR}
		
		LDR		R1, =FIRST
		MOV 	R2, #84 		; use r2 as a counter register
getsamp 
		PUSH	{R1,R2}
		BL		ATD_Sample		; do ATD conversion into r0
		BL 		scale_value
		POP		{R1,R2}
		STRB  	R0, [R1], #1
		SUBS	R2, #1
		BNE		getsamp
		
		BL 		imgwav			; Create image of waveform
		LDR		R5,=waveimg		; Load location in memory
		BL		OutImgNokia		; Display this message on screen


		POP {LR}
		BX LR
			ALIGN
			END
