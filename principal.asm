	INCLUDE	P16F870.INC

; ---- PINOS DO PIC ----
;	 1. MCLR\	28. RB7
;	 2. RA0		27. RB6
;	 3. RA1		26. RB5
;	 4. RA2		25. RB4
;	 5. RA3		24. RB3
;	 6. RA4		23. RB2
;	 7. RA5		22. RB1
;	 8. VSS		21. RB0
;	 9. OSC1	20. VDD
;	10. OSC2	19. VSS
;	11. RC0		18. RC7
;	12. RC1		17. RC6
;	13. RC2		16. RC5
;	14. RC3		15. RC4


Selec:	EQU PortB

#DEFINE SelUnid Selec,0 ; Seleciona o display de unidades (PINO 2: SA�DA)
#DEFINE SelDez  Selec,1 ; Seleciona o display de dezenas  (PINO 3: SA�DA)
#DEFINE SelCent Selec,2 ; Seleciona o display de centenas (PINO 4: SA�DA)
#DEFINE SelMil  Selec,3 ; Seleciona o display de milhares (PINO 5: SA�DA)

#DEFINE SetBit  1 <<

ENTRADA:EQU	PORTB
SAIDA:	EQU	PORTC

SALVAW:	EQU	0X7F
SALVAF:	EQU	0X7E

	PAGE

	ORG	0

RESET:
	CRLF	STATUS
	GOTO	INICIO

	ORG	4

InicioInt:
	MOVWF	SALVAW
	SWAPF	STATUS,W
	MOVWF	SALVAF
	CLRF	STATUS

	BTFSS	PIR1,ADIF
	GOTO	TIMERINT

ADInt:
	MOVLW	0XFF
	MOVWF	SAIDA ; ZERA A SA�DA PARA EVITAR RU�DO NA CONVERS�O

    BSF     STATUS,RP0 ; BANCO 1
    MOVFW   ADRESL-0X80
    BCF     STATUS,RP0 ; BANCO 0
    ADDWF   CONTA, F
    SKPNC
    INCF    CONTA+1, F
    MOVFW   ADRESH
    ADDWF   CONTA+1, F
    DECF    CONTA64, F
    SKPZ
	GOTO FIMADINT

	MOVFW	CONTA
	MOVWF	MOSTRA
	MOVFW	CONTA+1
	MOVWF	MOSTRA+1
	CLRF    CONTA
    CLRF    CONTA+1
    MOVLW   .64
    MOVWF   CONTA64

FimADInt:    
	BCF PIR1, ADIF
	GOTO FIMINT

TIMERINT:	BCF	PIR1,TMR2IF
	BCF	STATUS,C
	BTFSC	SELMIL
	BSF	STATUS,C
	RLF	SELEC,F

	MOVF	MOSTRA,W
	BTFSC	SELDEZ
	SWAPF	MOSTRA,W
	BTFSC	SELCENT
	MOVF	MOSTRA+1,W
	BTFSS	SELMIL
	GOTO SEG
	;BTFSS	ADCON0, GO ; S� PRA N�O ALTERAR O GO DURANTE A CONVERS�O, MAS TALVEZ DENECESS�RIO
	BSF     ADCON0, GO
	SWAPF	MOSTRA+1,W
SEG:CALL	SETESEG
	MOVWF	SAIDA

FimInt:
	SWAPF	SALVAF,W
	MOVWF	STATUS
	SWAPF	SALVAW,F
	SWAPF	SALVAW,W
	RETFIE

;HDSP-521	     UNIDADE  DEZENA
;========	ANODO.	13	14	A0: SEL UNIDADE
; --A--		0. B	10	15	A1: SEL DEZENA
;|     |	1. A	11	16	A2: SEL CENTENA
;F     B	2. C	 8	 3	A3: SEL MILHAR
;|     |	3. D	 6	 2
; --G--		4. E	 5	 1
;|     |	5. F	12	18
;E     C	6. G	 7	17	
;|     |	7. PT	 9	 4
; --D--  @.PT

SEGA:	EQU	SETBIT 1
SEGB:	EQU	SETBIT 0
SEGC:	EQU	SETBIT 2
SEGD:	EQU	SETBIT 3
SEGE:	EQU	SETBIT 4
SEGF:	EQU	SETBIT 5
SEGG:	EQU	SETBIT 6
SEGPT:	EQU	SETBIT 7
TODOS:  EQU	0XFF-SEGPT

SeteSeg:
	; Essa rotina converte o valor no registrador W para o formato a ser
	; apresentado no display de sete segmentos.
	ANDLW	0x0F
	ADDWF	PCL,F
	RETLW	SEGG+SEGPT		; 0
	RETLW	0XFF-SEGB-SEGC		; 1
	RETLW	SEGC+SEGF+SEGPT		; 2
	RETLW	SEGE+SEGF+SEGPT		; 3
	RETLW	SEGA+SEGD+SEGE+SEGPT	; 4
	RETLW	SEGB+SEGE+SEGPT		; 5
	RETLW	SEGB+SEGPT		; 6
	RETLW	0XFF-SEGA-SEGB-SEGC	; 7
	RETLW	SEGPT			; 8
	RETLW	SEGE+SEGPT		; 9
	RETLW	SEGD+SEGPT		; A
	RETLW	SEGA+SEGB+SEGPT		; B
	RETLW	0XFF-SEGD-SEGE-SEGG	; C
	RETLW	SEGA+SEGF+SEGPT		; D
	RETLW	SEGB+SEGC+SEGPT		; E
	RETLW	SEGB+SEGC+SEGD+SEGPT	; F
	
Inicio:	
    ; Configura��o do conversor A/D, timer, vari�veis de estado, etc.

Principal:
	; Calcula o desvio padr�o (raiz da soma dos quadrados)
	; e converte as componentes cont�nuas e alternadas para decimal.

	END

; ------------------------------- FIM --------------------------------
; Tudo abaixo ser� ignorado pelo montador!

MULBIT:	MACRO	NUMBIT
	BTFSC	FAT1,NUMBIT
	ADDWF	PRODH,F
	RRF	PRODH,F
	RRF	PRODL,F
	ENDM

	MOVLW	0
ESPERA:	ADDLW	1	; ESPERA 1024 CICLOS DE INSTRU��O
	SKPZ
	GOTO	ESPERA
	MOVF	ENTRADA,W
	BTFSS	ENTRA1
	MOVWF	FAT1
	BTFSS	ENTRA2
	MOVWF	FAT2
	BTFSS	MULT
	CALL	MUL8X8
	MOVLW	SETBIT 3
	XORWF	PORTA,F
	COMF	PRODH,W
	BTFSS	MOSTRAA
	COMF	PRODL,W
	MOVWF	SAIDA
	GOTO	PRINCIPAL

	PAGE	

MUL8X8:	CLRF	PRODL
	CLRF	PRODH
	BCF	STATUS,C
	MOVF	FAT2,W
	MULBIT	0
	MULBIT	1
	MULBIT	2
	MULBIT	3
	MULBIT	4
	MULBIT	5
	MULBIT	6
	MULBIT	7
	RETURN

	END