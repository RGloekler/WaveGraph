; Nokia5110-Class.s (trimmed & slightly modified)
; Sets up SSI0, PA6, PA to work with the
; SParkFun version of the Nokia 5110
; Pin connections
; ------------------------------------------
; Signal        (Nokia 5110) LaunchPad pin
; ------------------------------------------
; 3.3V          (VCC, pin 1) power
; Ground        (GND, pin 2) ground
; SSI0Fss       (SCE, pin 3) connected to PA3
; Reset         (RST, pin 4) connected to PA7
; Data/Command  (D/C, pin 5) connected to PA6
; SSI0Tx        (DN,  pin 6) connected to PA5
; SSI0Clk       (SCLK, pin 7) connected to PA2
; back light    (LED, pin 8) not connected, consists of 4 white LEDs which draw ~80mA total
;GPIO Registers
GPIO_PORTA_DATA			EQU	0x400043FC	; Port A Data
GPIO_PORTA_IM      		EQU 0x40004010	; Interrupt Mask
GPIO_PORTA_DIR   		EQU 0x40004400	; Port Direction
GPIO_PORTA_AFSEL 		EQU 0x40004420	; Alt Function enable
GPIO_PORTA_DEN   		EQU 0x4000451C	; Digital Enable
GPIO_PORTA_AMSEL 		EQU 0x40004528	; Analog enable
GPIO_PORTA_PCTL  		EQU 0x4000452C	; Alternate Functions
GPIO_PORTB_DATA			EQU	0x400053FC	; Port B Data
GPIO_PORTB_IM      		EQU 0x40005010	; Interrupt Mask
GPIO_PORTB_DIR   		EQU 0x40005400	; Port Direction
GPIO_PORTB_AFSEL 		EQU 0x40005420	; Alt Function enable
GPIO_PORTB_DEN   		EQU 0x4000551C	; Digital Enable
GPIO_PORTB_AMSEL 		EQU 0x40005528	; Analog enable
GPIO_PORTB_PCTL  		EQU 0x4000552C	; Alternate Functions
;SSI Registers
SSI0_CR0				EQU	0x40008000
SSI0_CR1				EQU	0x40008004
SSI0_DR					EQU	0x40008008
SSI0_SR					EQU	0x4000800C
SSI0_CPSR				EQU	0x40008010
SSI0_CC					EQU	0x40008FC8
;System Registers
SYSCTL_RCGCGPIO  		EQU 0x400FE608	; GPIO Gate Control
SYSCTL_RCGCSSI			EQU	0x400FE61C	; SSI Gate Control
	    AREA    timer, CODE, READONLY
        THUMB
		EXPORT	Nokia_Init
		EXPORT	OutImgNokia
		EXPORT	Out1BNokia
;*****************************************************************
; Initializes Nokia display
Nokia_Init
		PUSH	{LR}
	;Setup GPIO
		LDR 	R1, =SYSCTL_RCGCGPIO	; start GPIO clock                 
		MOV 	R0, #0x01     			; set bit 0	------------------
		STR 	R0, [R1]                   
		NOP								; allow clock to settle
		NOP
		NOP								
		LDR		R1,=GPIO_PORTA_DIR		; make PA2,3,5,6,7 output
		MOV 	R0, #0xEF            	; and make PA4 input ---------------------
		STR		R0,[R1]
		LDR		R1,=GPIO_PORTA_AFSEL	; enable alt funct on PA2,3,4,5
		MOV 	R0, #0x3C				;---------------------
		STR		R0,[R1]
		LDR		R1,=GPIO_PORTA_DEN		; enable digital I/O at PA2,3,4,5,6,7
		MOV		R0, #0xFC			;---------------------
		STR		R0,[R1]					
		LDR		R1,=GPIO_PORTA_PCTL 	; configure PA2,3,4,5 as SSI
		LDR 	R0, =0x222200           ; set 2,3,4 and 5 nibble ---------------
		STR		R0,[R1]
		LDR		R1,=GPIO_PORTA_AMSEL	; disable analog functionality
		MOV R0, #0x0
		STR		R0,[R1]
	;Setup SSI	
		LDR 	R1,=SYSCTL_RCGCSSI		; start SSI clock                  
		MOV 	R0, #0x01                ; set bit 0 for SSI0 -------------------
		STR 	R0,[R1]                
		; small delay
		MOV		R0,#0x0F
waitSSIClk								; allow clock to settle
		SUBS	R0,R0,#0x01
		BNE		waitSSIClk
		LDR		R1,=SSI0_CR1			; disable SSI during setup and also set to Master
		LDR 	R0, [R1];added
		BIC 	R0, #0xFF			; clear bit 1	and  clear bit 2 (you can clear all bits)
		STR		R0,[R1]
		; Configure baud rate PIOSC=16MHz,Baud=2MHz,CPSDVSR=4,SCR=1
		; BR=SysClk/(CPSDVSR * (1 + SCR))
		LDR		R1,=SSI0_CC				; use PIOSC (16MHz)		
		MOV 	R0, #0x05			; set bits 3:0 of the SSICC to 0x5-------------------- 
		STR		R0,[R1]
		LDR		R1,=SSI0_CR0			; set SCR bits to 0x01
		LDR		R0,[R1]
		ORR 	R0, #0x0100			;---------------------------
		STR		R0,[R1]
		LDR		R1,=SSI0_CPSR			; set CPSDVSR (prescale) to 0x04
		MOV		R0, #0x04		    ;--------------------
		STR		R0,[R1]
		LDR		R1,=SSI0_CR0			; clear SPH,SPO
		LDR		R0,[R1]					; choose Freescale frame format
		BIC		R0, #0xFF             ; clear bits 5:4 --------------------	
		ORR		R0, #0x07				; choose 8-bit data (set DSS bits to 0x07) -----------------
		STR		R0,[R1]
		LDR		R1,=SSI0_CR1			; enable SSI
		MOV		R0,#0x2     		; set bit 1----------------------asdfasdf
		STR		R0,[R1]
	; DC = PA7
	; Reset LCD memory	- reset already low
		; ensure reset is low
		LDR		R1,=GPIO_PORTA_DATA	
		LDR 	R0, [R1];added
		BIC		R0, #0x80 			; clear reset(PA7)--------------------- 	
		STR		R0,[R1]
		MOV		R0,#10
delReset		
		SUBS	R0,R0,#1
		BNE		delReset
		LDR		R1,=GPIO_PORTA_DATA		; 
		LDR 	R0, [R1];added
		ORR		R0, #0x80			; set reset(PA7)------------------------
		STR		R0,[R1]					;
	; Setup LCD
		LDR		R1,=GPIO_PORTA_DATA		; set PA6 low for Command
		LDR		R0,[R1]
		BIC		R0, #0x40			;
		STR		R0,[R1]
		;chip active (PD=0)
		;extended instruction set (H=1)
		MOV		R5,#0x21
		BL		Out1BNokia	
		;set contrast
		MOV		R5,#0xB8
		BL		Out1BNokia
		;set temp coefficient
		MOV		R5,#0x04
		BL		Out1BNokia
		;set bias 1:48: try 0x13 or 0x14
		MOV		R5,#0x14
		BL		Out1BNokia
		;change H=0
		MOV		R5,#0x20
		BL		Out1BNokia
		;set control mode to normal
		MOV		R5,#0x0C
		BL		Out1BNokia
		; clear screen
		; screen memory is undefined after startup
		BL		ClearNokia
waitCMDDone		
		LDR		R1,=SSI0_SR				; wait until SSI is done
		LDR		R0,[R1]
		ANDS	R0,R0,#0x10
		BNE		waitCMDDone
		POP		{LR}
		BX		LR
;*****************************************************************	
; SSI Send routine. Bits to be sent passed via R5
Out1BNokia
		PUSH	{R0,R1}
waitSendNokia		
		LDR		R1,=SSI0_SR				; wait if buffer is full
		LDR		R0,[R1]
		ANDS	R0,R0,#0x02
		BEQ		waitSendNokia
		LDR		R1,=SSI0_DR
		STRB	R5,[R1]
		POP		{R0,R1}
		BX		LR
;*****************************************************************
; Send Image to Nokia routine	
OutImgNokia
		PUSH	{R0-R4,LR}
		PUSH	{R5}					; save Img address
		LDR		R1,=GPIO_PORTA_DATA		; set PA6 low for Command
		LDR		R0,[R1]
		BIC		R0,#0x40
		STR		R0,[R1]
		MOV		R5,#0x22	; Only modification. Ensure H=0, V=1
		BL		Out1BNokia	
		MOV		R5,#0x40				; set Y address to 0
		BL		Out1BNokia
		MOV		R5,#0x80				; set X address to 0
		BL		Out1BNokia	
waitImgReady		
		LDR		R1,=SSI0_SR				; wait until SSI is done
		LDR		R0,[R1]
		ANDS	R0,R0,#0x10
		BNE		waitImgReady
		LDR		R1,=GPIO_PORTA_DATA		; ready: set PA6 high for Data
		LDR		R0,[R1]
		ORR		R0,#0x40
		STR		R0,[R1]	
		POP		{R5}
		MOV		R0,#504					; 504 bytes in full image
		MOV		R1,R5					; put img address in R1
sendNxtByteNokia		
		LDRB	R5,[R1],#1		; load R5 with byte, post inc address
		BL		Out1BNokia
		SUBS	R0,#1
		BNE		sendNxtByteNokia		
		POP		{R0-R4,LR}
		BX		LR
;*****************************************************************
; clear LCD screen
ClearNokia
		PUSH	{R0-R5,LR}
		LDR		R1,=GPIO_PORTA_DATA		; set PA6 low for Command
		LDR		R0,[R1]
		BIC		R0,#0x40
		STR		R0,[R1]
		MOV		R5,#0x20				; ensure H=0
		BL		Out1BNokia	
		MOV		R5,#0x40				; set Y address to 0
		BL		Out1BNokia
		MOV		R5,#0x80				; set X address to 0
		BL		Out1BNokia	
waitClrReady		
		LDR		R1,=SSI0_SR				; wait until SSI is done
		LDR		R0,[R1]
		ANDS	R0,R0,#0x10
		BNE		waitClrReady
		LDR		R1,=GPIO_PORTA_DATA		; set PA6 high for Data
		LDR		R0,[R1]
		ORR		R0,#0x40
		STR		R0,[R1]	
		MOV		R0,#504					; 504 bytes in full image
		MOV		R5,#0x00				; load zeros to send
clrNxtNokia		
		BL		Out1BNokia
		SUBS	R0,#1
		BNE		clrNxtNokia
waitClrDone			
		LDR		R1,=SSI0_SR				; wait until SSI is done
		LDR		R0,[R1]
		ANDS	R0,R0,#0x10
		BNE		waitClrDone
		POP		{R0-R5,LR}
		BX		LR		
;*****************************************************************		
		ALIGN
		END