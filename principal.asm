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

#DEFINE SelUnid Selec,0 ; Seleciona o display de unidades (PINO 2: SAÍDA)
#DEFINE SelDez  Selec,1 ; Seleciona o display de dezenas  (PINO 3: SAÍDA)
#DEFINE SelCent Selec,2 ; Seleciona o display de centenas (PINO 4: SAÍDA)
#DEFINE SelMil  Selec,3 ; Seleciona o display de milhares (PINO 5: SAÍDA)

#DEFINE SetBit  1 <<

ENTRADA:EQU	PORTB
SAIDA:	EQU	PORTC

SALVAW:	EQU	0X7F
SALVAF:	EQU	0X7E

; MACROS UTILITÁRIAS
CPFF: ; copia uma variável para outra posição de memória
    MACRO   Origem, Destino
    MOVWF   Origem, w
    MOVWF   Destino, f
    ENDM

CPFF2B: ; copia variável de 2 bytes
    MACRO   Origem, Destino
    CPFF    Origem, Destino
    CPFF    Origem+1, Destino+1
    ENDM

CPFF3B:	; copia variável de 3 bytes
    MACRO   Origem, Destino
    CPFF    Origem, Destino
    CPFF    Origem+1, Destino+1
    CPFF    Origem+2, Destino+2
    ENDM

CPFF4B: ; copia variável de 4 bytes
    MACRO   Origem, Destino
    CPFF    Origem, Destino
    CPFF    Origem+1, Destino+1
    CPFF    Origem+2, Destino+2
    CPFF    Origem+3, Destino+3
    ENDM

    PAGE

    ORG	0

RESET:
    CRLF    STATUS
    GOTO    Inicio

    ORG	4

InicioInt:
    MOVWF   SalvaW
    SWAPF   STATUS,W
    MOVWF   SalvaF
    CLRF    STATUS

    BTFSS   PIR1,ADIF
    GOTO    TimerInt

ADInt:
    ; ZERA A SAÍDA PARA EVITAR RUÍDO NA CONVERSÃO
    MOVLW   0XFF
    MOVWF   Saida

    ; MOVE A AMOSTRA DO AD PARA A VARIÁVEL AMOSTRA
    BSF     STATUS,RP0   ; BANCO 1
    MOVFW   ADRESL-0X80
    BCF     STATUS,RP0   ; BANCO 0
    MOVWF   Amostra, f   ; move a parte baixa da amostra
    MOVFW   ADRESH
    MOVWF   Amostra+1, f ; move a parte alta da amostra

	; SOMA DAS AMOSTRAS
    MOVF    Amostra, w
    ADDWF   Soma, f
    MOVF    Amostra+1, w
    SKPNC
    ADDLW   1
    SKPC
    ADDWF   Soma+1, f
    SKPNC
    INCF    Soma+2, f

    ; CALCULA QUADRADO DA AMOSTRA
    MOVF    Amostra,w
    ANDLW   0x7F        ; 2.5.1. W = Amostra & 0x7F;
    CLRF    Quad+1
    CLRF    Quad+2      ; Quad = 0;
    BTFSC   Amostra+1,1 ; if ( Amostra & 0x200 )
    ADDWF   Quad+1,f    ;    Quad += W * 256; //* nunca pode dar vai um!
    RLF     Quad+1,f
    RLF     Quad+2,f    ; Quad *= 2;
    BTFSC   Amostra+1,0 ; if ( Amostra & 0x100 )
    ADDWF   Quad+1,f    ;    Quad += W * 256;
    SKPNC               ; if ( vai um )
    INCF    Quad+2,f    ;    Quad += 0x10000;
    BCF     STATUS,C
    RLF     Quad+1,f
    RLF     Quad+2,f    ; Quad *= 2;
    BTFSC   Amostra,7   ; if ( Amostra & 0x80 )
    ADDWF   Quad+1,f	;    Quad += W * 256;
    SKPNC			    ; if ( vai um )
    INCF    Quad+2,f	;    Quad += 0x10000;
				        ; 2.5.2. Quad = W * ( Amostra >> 7 ) * 256;
    BSF     STATUS,RP1	; banco 2
    MOVWF   EEADR-0x100	; EEADRH deve conter a parte alta do endereço da tabela
    BSF     Status,RP0	; banco 3
    BSF     EECON1-0x180,RD	; EECON1.EEPGD = 1!
    NOP
    NOP
    BCF     STATUS,RP0	; banco 2
    MOVF    EEDATA-0x100,w
    ;BCF    STATUS,RP1	; banco 0: Não é necessário porque Quad é acessível no banco 2!
    MOVWF   QUAD
    ;BSF    STATUS,RP1	; banco 2
    MOVF    EEDATH-0x100,w
    ;BCF    STATUS,RP1	; banco 0: Não é necessário porque Quad e Amostra são acessíveis!
    ADDWF   QUAD+1,f
    SKPNC
    INCF    Quad+2,f	; 2.5.3. Quad += TabQuad [ W ];
    RLF     Amostra,w
    RLF     Amostra+1,w
    ADDLW   0x80
    ;BSF    Status,RI1	; banco 2
    MOVWF   EEADR-0x100	; EEADRH deve conter a parte alta do endereço da tabela
    BSF     Status,RP0	; banco 3
    BSF     EECON1-0x180,RD ; EECON1.EEPGD = 1!
    NOP
    NOP
    BCF     STATUS,RP0	; banco 2
    MOVF	EEDATA-0x100,w
    ;BCF    STATUS,RP1	; banco 0: Não é necessário porque Quad é acessível no banco 2!
    ADDWF   QUAD+1,f
    SKPNC
    INCF    Quad+2,f
    ;BSF    STATUS,RP1	; banco 2
    MOVF    EEDATH-0x100,w
    BCF     STATUS,RP1	; banco 0
    ADDWF   QUAD+2,f	; 2.5.4. Quad += TabQuad [ ( Amostra * 2 ) >> 8 + 0x80 ];

    ; SOMA DOS QUADRADOS DAS AMOSTRASs
    MOVF    Quad, w
    ADDWF   SQuad, f
    MOVF    Quad+1, w
    SKPNC
    ADDLW   1
    SKPC
    ADDWF   SQuad+1, f
    MOVF    Quad+2, f
    SKPNC
    ADDLW   1
    SKPC
    ADDWF   SQuad+2, f
    SKPNC
    INCF    SQuad+3, f

    ; CONTADOR DE AMOSTRAS
    INCF    Contador
    SKPNC
    INCF    Contador+1
    BTFSS   Contador+1, 4 ; testa se são 4000 amostras
    GOTO    FimADInt
    MOVLW   .96
    MOVWF   Contador
    CLRF    Contador+1
    CPFF3B  Soma, SomaFN
    CPFF4B  SQuad, SQuadFN

FimADInt:    
    BCF     PIR1, ADIF
    GOTO    FimInt

TimerInt:
    BCF     PIR1,TMR2IF
    BCF     STATUS,C
    BTFSC   SELMIL
    BSF     STATUS,C
    RLF     SELEC,F

    MOVF    MOSTRA,W
    BTFSC   SELDEZ
    SWAPF   MOSTRA,W
    BTFSC   SELCENT
    MOVF    MOSTRA+1,W
    BTFSS   SELMIL
    GOTO    SEG
    ;BTFSS  ADCON0, GO ; SÓ PRA NÃO ALTERAR O GO DURANTE A CONVERSÃO, MAS TALVEZ DENECESSÁRIO
    BSF     ADCON0, GO
    SWAPF   MOSTRA+1,W

SEG:
    CALL    SETESEG
    MOVWF   SAIDA

FimInt:
    SWAPF   SALVAF,W
    MOVWF   STATUS
    SWAPF   SALVAW,F
    SWAPF   SALVAW,W
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
    ; Configuração do conversor A/D, timer, variáveis de estado, etc.

	; INICIALIZANDO CONTADOR DE AMOSTRAS
    MOVLW   .96
    MOVWF   Contador
    CLRF	Contador+1

Principal:
	; Calcula o desvio padrão (raiz da soma dos quadrados)
	; e converte as componentes contínuas e alternadas para decimal.

	END

; ------------------------------- FIM --------------------------------
; Tudo abaixo será ignorado pelo montador!

MULBIT:	MACRO	NUMBIT
	BTFSC	FAT1,NUMBIT
	ADDWF	PRODH,F
	RRF	PRODH,F
	RRF	PRODL,F
	ENDM

	MOVLW	0
ESPERA:	ADDLW	1	; ESPERA 1024 CICLOS DE INSTRUÇÃO
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
