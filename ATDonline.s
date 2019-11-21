; ***************************************************************
; ATDonline.s                                                   *
; Runs on TM4C123                           Bill Eads  10-20-19 *
;		                                                        *
; Setup and run ATD sampling on ADC0 (PE3)       *
; Stores results in R0                                          *
; ***************************************************************	
	
; ADC Registers
RCGCADC				EQU	0x400FE638	; ADC clock register
ADC0_ACTSS			EQU 0x40038000	; Sample sequencer (ADC0 base address)
ADC0_PC				EQU 0x40038FC4	; Sample rate
SSCTL3				EQU 0xA4		; Offsets from ADC0 base address
PSSI				EQU 0x28
RIS					EQU 0x04
SSFIFO3				EQU 0xA8
ISC					EQU 0x0C

; GPIO Registers 
RCGCGPIO		  	EQU 0x400FE608	; GPIO clock register
; PORT E base address = 0x40024000
PORTE_DEN			EQU 0x4002451C	; Digital Enable
PORTE_PCTL		  	EQU 0x4002452C	; Alternate function select
PORTE_AFSEL		 	EQU 0x40024420	; Enable Alt functions
PORTE_AMSEL		 	EQU 0x40024528	; Enable analog
	
        AREA    |.text|, READONLY, CODE, ALIGN=2
        THUMB
		
        EXPORT  ATD_Init
		EXPORT  ATD_Sample

ATD_Init

		LDR		R1, =RCGCGPIO			; Turn on GPIO clock
		LDR		R0, [R1]
		ORR		R0, #0x10    			; set bit 4 to enable port E clock
		STR		R0, [R1]
; Don't need to let clock stabilize. Why not?
		
		LDR		R1, =RCGCADC			; Turn on ADC clock
		LDR		R0, [R1]
		MOV 	R0, #0x01    			; set bit 0 to enable ADC0 clock
		STR		R0, [R1]
; Don't need to let clock stabilize. Why not?

; Setup GPIO to make PE3 or temperature sensor be input for ADC0	
	
; GPIO: Enable alternate functions
		LDR		R1, =PORTE_AFSEL
		LDR		R0, [R1]
		MOV     R0, #0x08           	; set bit 3 to enable alt functions on PE3
		STR		R0, [R1]
; PCTL does not have to be configured since ADC0 is automatically selected
; when port pin is set to analog.
; Disable digital on  PE3
		LDR		R1, =PORTE_DEN
		LDR		R0, [R1]
		BIC 	R0, #0x08    			; clear bit 3 to disable analog on PE3
		STR		R0, [R1]	
; Enable analog on PE3
		LDR		R1, =PORTE_AMSEL
		LDR		R0, [R1]
		MOV 	R0, #0x08    			; set bit 3 to enable analog on PE3
		STR		R0, [R1]
		
; Setup ADC
; Disable sequencer while ADC setup
		LDR		R1, =ADC0_ACTSS			; Base Address fir ADC0
		LDR		R0, [R1]
		BIC		R0, #0x08   			; clear bit 3 to disable seq'r 3
		STR		R0, [R1]	
		
; Config sample sequence for temperature sensor
		LDR		R0, [R1,#SSCTL3]		; ADC0_SSCTL3
		MOV 	R0, #0x06   			; To voltage on PE3,set bits 2:1 (IE0, END0)
		STR		R0, [R1,#SSCTL3]		; Change this to measure temperature

; Set sample rate
		LDR		R2, =ADC0_PC
		LDR		R0, [R2]
		MOV		R0, #0x01				; set bits 3:0 to 001 for 125k sps
		STR		R0, [R2]	
		
; Done with setup, enable sequencer
		LDR		R0, [R1]				; ADC0ACTSS
		MOV		R0, #0x08   			; set bit 3 to enable seq'r 3
		STR		R0, [R1]
		BX		LR						; Return to caller

ATD_Sample		; start sampling routine

		LDR		R2, =ADC0_ACTSS			; preload ADC0 base address
		LDR		R0, [R2,#PSSI]			; ADC0_PSSI
		MOV 	R0, #0x08				; set bit 3 to enable seq'r 3
		STR		R0, [R2,#PSSI]			; (take sample)
		
ATD_Check		
		LDR		R0, [R2,#RIS]			; ADC0_RIS check if sample is complete	
		ANDS	R0, R0, #0x08
		BEQ		ATD_Check
		LDR		R0, [R2,#SSFIFO3]		; ADC0_SSFIFO3 load results
		LDR		R1, [R2,#ISC]			; ADC0_ISC clear interrupt flag
		MOV     R1, #0x08				; set bit 3 to clear interrupt flag
		STR		R1, [R2,#ISC]
		BX		LR						; Return from caller
				
		ALIGN	
		END