    include P16F870.inc

;    1. MCLR\   28. RB7
;    2. RA0     27. RB6
;    3. RA1     26. RB5
;    4. RA2     25. RB4
;    5. RA3     24. RB3
;    6. RA4     23. RB2
;    7. RA5     22. RB1
;    8. Vss     21. RB0
;    9. OSC1    20. VDD
;   10. OSC2    19. Vss
;   11. RC0     18. RC7
;   12. RC1     17. RC6
;   13. RC2     16. RC5
;   14. RC3     15. RC4

; Definindo pino que indicara a Chave RMS
#define MostraRMS   PortB, 0

; Definindo pino indicador de sinal negativo
#define Negativo  PortB,1

; Definindo pino da "bomba de tensao"
; Temos uma interrupÃ§Ã£o de timer a cada 1000 ciclos de relÃ³gio
; O tempo entre as interrupÃ§Ãµes Ã© de 0.05 ms (50 milisegundos)
; Para um sinal com perÃ­odo 0.2 ms, inverteremos o valor desse pino
; a cada 2 interrupÃ§Ãµes
#define Bomba   PortB,2

; Definindo os pinos da porta B para selecionar o dÃ­gito no diplay
Selec:  equ PortB
#define SelUnid Selec,4 ; Pino 25: saÃ­da
#define SelDez  Selec,5 ; Pino 26: saÃ­da
#define SelCent Selec,6 ; Pino 27: saÃ­da
#define SelMil  Selec,7 ; Pino 28: saÃ­da

; Definindo saÃ­da do display de 7 segmentos
#define Saida   PortC

; Defines auxiliares
#define SETBIT  1   <<

; VariÃ¡veis

; VariÃ¡veis auxiliares
conta5:     equ 0x20    ; Armazena se ocorreu 4 interrupÃ§Ãµes
SalvaW:     equ 0x21    ; armazena w antes da interrupÃ§Ã£o
SalvaSt:    equ 0x22    ; armazena STATUS antes da interrupÃ§Ã£o
Mostra:     equ 0x23    ; 32 Bits

;=======VariÃ¡veis da rotina de InterrupÃ§Ã£o AD=====================

; VariÃ¡vel que recolhe as Amostras
Amostra:    equ 0x27    ; 16 bits

; VariÃ¡vel que guard a soma das Amostras
Soma:       equ 0x29    ; 24 bits

; VariÃ¡vel que guarda o quadrado da amostra
Quad:       equ 0x2C    ; 24 bits

; VariÃ¡vel que guarda a soma dos quadrados das amostras
Squad:      equ 0x2F    ; 32 bits

; VariÃ¡vel que guardarÃ¡ a quantidade de amostras coletadas
Contador:   equ 0x33    ; 16 bits

; VariÃ¡vel que guardarÃ¡ o resultado da Ãºltima Soma dos quadrados
SquadFN:    equ 0x35    ; 32 bits

; VariÃ¡vel que guardarÃ¡ o resultado da Ãºltima Soma das Amostras
SomaFN:     equ 0x39    ; 24 bits

;=========VariÃ¡veis do Programa Principal===================

; VariÃ¡vel que guardarÃ¡ uma cÃ³pia da Soma das Amostras dividido por 64
Somadv64:   equ 0x3C    ; 16 bits

; VariÃ¡vel que guardarÃ¡ uma cÃ³pia da Soma dos Quadrados
SQuadP:     equ 0x3E    ; 32 bits

; VariÃ¡vel que guardarÃ¡ o valor de calibraÃ§Ã£o do Zero
CalZ:       equ 0x42    ; 16 bits

; VariÃ¡vel que guardarÃ¡ o Valor a ser apresentado
Valor:      equ 0x44    ; 16 bits


;==========Macros Auxiliares=================================
; copia uma variavel de 1 byte para outra posicao de memoria
CPFF MACRO Origem, Destino
    MOVFW   Origem
    MOVWF   Destino
    ENDM

; copia variavel de 2 bytes
CPFF2B MACRO Origem, Destino
    CPFF    Origem, Destino
    CPFF    Origem+1, Destino+1
    ENDM

; copia variavel de 3 bytes
CPFF3B MACRO Origem, Destino
    CPFF    Origem, Destino
    CPFF    Origem+1, Destino+1
    CPFF    Origem+2, Destino+2
    ENDM

; copia variavel de 4 bytes
CPFF4B MACRO Origem, Destino             
    CPFF    Origem, Destino
    CPFF    Origem+1, Destino+1
    CPFF    Origem+2, Destino+2
    CPFF    Origem+3, Destino+3
    ENDM

; Uma etapa da multiplicaÃ§Ã£o, guardarÃ¡ o resultado parcial em PRODH e PRODL
MULBIT  MACRO   Fat1, Numbit
    BTFSC   Fat1, Numbit
    ADDWF   ProdH, F
    RRF     ProdH, F
    RRF     ProdL, F
    ENDM

; MultiplicaÃ§Ã£o entre nÃºmeros de 8 bits. Resultado de 16 bits
MULT8 MACRO Fat1, Fat2          
    CLRF    ProdH
    MOVF    Fat2, W
    MULBIT  Fat1, 0
    MULBIT  Fat1, 1
    MULBIT  Fat1, 2
    MULBIT  Fat1, 3
    MULBIT  Fat1, 4
    MULBIT  Fat1, 5
    MULBIT  Fat1, 6
    MULBIT  Fat1, 7
    ENDM

; Faz SHL de uma variÃ¡vel de 6 bytes
SHL6B MACRO Var
    BCF     Status, C
    RLF     Var, F
    RLF     Var+1, F
    RLF     Var+2, F
    RLF     Var+3, F
    RLF     Var+4, F
    RLF     Var+5, F
    ENDM
    
; Macro que capturarÃ¡ o valor de W na Tabela.
; O valor serÃ¡ dado em DadoL e DadoH
CAP     MACRO
    BSF     STATUS,RP1      ; banco 2
    CLRF    EEADRH - 0x100  ; EEADRH Deve ser zerado
    MOVWF   EEADR-0x100     ; EEADRH deve conter a parte alta do endereÃ§o da tabela
    BSF     Status,RP0      ; banco 3
    BSF     EECON1-0x180,RD ; EECON1.EEPGD = 1!
    NOP
    NOP
    ; Nesse momento a captura jÃ¡ foi feita, basta pegÃ¡-lo nos registradores correspondentes
    BCF     STATUS,RP0      ; BANCO 2
    MOVFW   EEDATA-0x100    ; Parte Baixa
    BCF     STATUS, RP1     ; BANCO 0
    MOVWF   DadoL           ; Passou o Resultado da parte Baixa
    BSF     STATUS, RP0     ; BANCO 2
    MOVFW   EEDATH-0x100    ; Parte Alta
    BCF     STATUS, RP0     ; BANCO 0
    MOVWF   DadoH           ; Movendo a parte alta para DadoH
    ENDM

; Soma um numero de 4 bytes (font4) com um de 6 bytes (dest6).
; O resultado é armazenado em Dest6.
ADD4B6B MACRO Font4, Dest6
    MOVFW   Font4
    ADDWF   Dest6, F
    MOVFW   Font4+1
    SKPNC
    ADDLw   .1
    SKPC
    ADDWF   Dest6+1, F
    MOVFW   Font4+2
    SKPNC
    ADDLW   .1
    SKPC
    ADDWF   Dest6+2, F
    MOVFW   Font4+3
    SKPNC
    ADDLW   .1
    SKPC
    ADDWF   Dest6+3, F
    MOVLW   .1
    SKPNC
    ADDWF   Dest6+4, F
    SKPNC
    ADDWF   Dest6+5, F
    ENDM
    
SOMA16 MACRO OP1,OP2,DEST
    MOVF    OP1,W           ; 1
    ADDWF   OP2,DEST        ; 2
    MOVF    OP1+1,W         ; 3
    SKPNC                   ; 4
    ADDLW   1               ; 5
    SKPC                    ; 6
    ADDWF   OP2+1,DEST      ; 7
    ENDM

; PROGRAMA


	ORG	0

RESET:	
    CLRF    STATUS
    GOTO    INICIO

    ORG	4

INT:	
    MOVWF   SalvaW
    SWAPF   STATUS,W
    MOVWF   SalvaSt
    CLRF    STATUS
    MOVLW   0xFF
    MOVWF   Saida

    BTFSC   PIR1, ADIF
    GOTO    ADINT
    BTFSC   PIR1, TMR2IF
    GOTO    TM2INT
    GOTO    FimInt

ADINT:
    ; ZERA A SAÃDA PARA EVITAR RUÃDO NA CONVERSÃƒO
    MOVLW   0XFF
    MOVWF   Saida

    ; MOVE A AMOSTRA DO AD PARA A VARIÃVEL AMOSTRA
    BSF     STATUS,RP0      ; BANCO 1
    MOVFW   ADRESL-0X80
    BCF     STATUS,RP0      ; BANCO 0
    MOVWF   Amostra         ; move a parte baixa da amostra
    MOVFW   ADRESH
    MOVWF   Amostra+1       ; move a parte alta da amostra
    
    ; SOMA DAS AMOSTRAS
    MOVF    Amostra, W
    ADDWF   Soma, F
    MOVF    Amostra+1, W
    SKPNC
    ADDLW   .1
    SKPC
    ADDWF   Soma+1, F
    SKPNC
    INCF    Soma+2, F
    
    ; CALCULA QUADRADO DA AMOSTRA
    CLRF    Quad            ; Zera o valor doQuadrado, pois ainda iremos calcular
    CLRF    Quad+1
    CLRF    Quad+2
    BCF     STATUS, C       ; Pois precisarÃ¡ dar alguns Rotates
    RLF     Amostra
    RLF     Amostra+1       ; Amostra+1 jÃ¡ possui os 3 bits mais significativos
                            ; Agora devemos fazer o Amostra ficar com os outros 7
                            ; Nos seus bits mais a esquerda
    BCF     STATUS, C
    RRF     Amostra         ; Amostra agora possui os 7 bits menos significativo
                            ; Agora basta aplicar o algoritmo aprendido em sala.
                            ; Amostra+1 equivale ao X e Amostra ao Y, sendo o nÃºmero XY
    MOVFW   Amostra+1       ; Movendo a parte de 3 bits do nÃºmero
    CAP                     ; Capturando o valor do Quadrado na tabela
    MOVFW   DADOL           ; Sendo o Amostra+1 um nÃºmero de 3 bits, entÃ£o o DadoH com certeza
                            ; SerÃ¡ 0
    MOVFW   Quad+2          ; Equivalente a multiplicar por 2^16, porÃ©m devemos multiplicar por
                            ; 2^14, portanto iremos dar dois RRF
    RRF     Quad+2
    RRF     Quad+1          ; ImpossÃ­vel dar Carry pois foi zerado no inÃ­cio do procedimento
    RRF     Quad+2
    RRF     Quad+1
    
    MULT8   Amostra, Amostra+1  ;Calculou o X*Y
    MOVFW   PRODL
    ADDWF   Quad+1, F
    SKPNC
    INCF    Quad+2
    MOVFW   PRODH
    ADDWF   Quad+2, F           ; Quad += X*Y*2^8
    
    MOVFW   Amostra         ; Movendo a parte de 7 bits do nÃºmero
    CAP                     ; Capturando o valor do Quadrado do nÃºmero de 7 bits
    MOVFW   DADOL
    ADDWF   Quad, F
    MOVFW   DADOH
    SKPNC
    ADDLW   .1
    SKPC
    ADDWF   Quad+1, F

    SKPNC
    INCF    Quad+2, F       ; Quad += Y^2
    
    ; SOMA DOS QUADRADOS DAS AMOSTRASs
    MOVF    Quad, W
    ADDWF   SQuad, F
    MOVF    Quad+1, W
    SKPNC
    ADDLW   .1
    SKPC
    ADDWF   SQuad+1, F
    MOVF    Quad+2, W
    SKPNC
    ADDLW   .1
    SKPC
    ADDWF   SQuad+2, F
    SKPNC
    INCF    SQuad+3, F
    
    ; CONTADOR DE AMOSTRAS
    INCF    Contador, F
    SKPNC
    INCF    Contador+1, F
    BTFSS   Contador+1, 4 ; testa se sÃ£o 4000 amostras
    GOTO    FimADInt
    MOVLW   .96
    MOVWF   Contador
    CLRF    Contador+1
    CPFF3B  Soma, SomaFN
    CPFF4B  SQuad, SQuadFN
    
FimADInt:
    BCF     PIR1, ADIF
    GOTO    FimInt



TM2INT:	
    MOVLW   0xFF
    MOVWF   Saida 		    ;Apaga o display de 7 segmentos

    BCF     STATUS,C
    BTFSC   SELMIL
    BSF     STATUS,C
    RLF     SELEC,F
    
    MOVF    Mostra,W
    BTFSC   SelDez
    MOVF    Mostra+1,W
    BTFSC   SelCent
    MOVF    Mostra+2,W
    BTFSC   SelMil
    MOVF    Mostra+3,W
    
SEG:
    CALL    SETESEG
    MOVWF   Saida
    
    DECF    conta5, F	    ;Decrementa em 1 o nÃºmero de vezes que entrou na interrupÃ§Ã£o
    SKPZ
    GOTO    FimTM2INT
    BSF     ADCON0, GO
    MOVLW   .5
    MOVWF   conta5

FimTM2INT:
    BCF     PIR1, TMR2IF
    
FimInt:    
    SWAPF   SalvaSt,W
    MOVWF   STATUS
    SWAPF   SalvaW,F
    SWAPF   SalvaW,W
    RETFIE

;HDSP-521       Unidade  Dezena
;========   Anodo.	13	14	A0: sel unidade
; --a--     0. b	10	15	A1: sel dezena
;|     |    1. a	11	16	A2: sel centena
;f     b    2. c	 8	 3	A3: sel milhar
;|     |    3. d	 6	 2
; --g--     4. e	 5	 1
;|     |    5. f	12	18
;e     c    6. g	 7	17	
;|     |    7. pt	 9	 4
; --d--     @.pt

SegA:   equ SetBit 1
SegB:   equ SetBit 0
SegC:   equ SetBit 2
SegD:   equ SetBit 3
SegE:   equ SetBit 4
SegF:   equ SetBit 5
SegG:   equ SetBit 6
SegPt:  equ SetBit 7
Todos:  equ 0xFF-SegPt

SeteSeg:
    ANDLW   0x0F
    ADDWF   PCL,f
    RETLW   SegG+SegPt          ; 0
    RETLW   0xFF-SegB-SegC      ; 1
    RETLW   SegC+SegF+SegPt     ; 2
    RETLW   SegE+SegF+SegPt     ; 3
    RETLW   SegA+SegD+SegE+SegPt; 4
    RETLW   SegB+SegE+SegPt     ; 5
    RETLW   SegB+SegPt          ; 6
    RETLW   0xFF-SegA-SegB-SegC ; 7
    RETLW   SegPt               ; 8
    RETLW   SegE+SegPt          ; 9
    RETLW   SegD+SegPt          ; A
    RETLW   SegA+SegB+SegPt     ; b
    RETLW   0xFF-SegD-SegE-SegG ; c
    RETLW   SegA+SegF+SegPt     ; d
    RETLW   SegB+SegC+SegPt     ; E
    RETLW   SegB+SegC+SegD+SegPt; F

INICIO:	
    MOVLW   .5
    MOVWF   conta5              ; Armazena o valor 4 que irÃ¡ ser decrementado a cada interrupÃ§Ã£o

    BCF     Status, RP0         ; BANCO 0
    BCF     Status, RP1         ; 
    BSF     INTCON,PEIE
    BSF     INTCON,GIE
    MOVLW   0x1C                ; Seleciona on no Timer2, seleciona o poscaler como 4, e o prescaler como 1
    MOVWF   T2CON
    CLRF    PortA               ; Inicializa PortA limpando toda a sua saÃ­da

    BSF     Status, RP0         ; BANCO 1
    MOVLW   0x0F                ; Valor usado para iniciar o sentido dos dados
    MOVWF   TRISA-0x80          ; Selecionou de RA0 a RA3 como entrada
    MOVLW   0x8D                ; Colocou como Right Justified (6 bits de ADRESH lidos como 0
                                ; e configurou para RA3 e RA2 serem VREF+ e VREF- e RA0 e RA1
                                ; como entradas analÃ³gicas
    MOVWF   ADCON1-0x80         ; Colocou as configuraÃ§Ãµes acima no registrador ADCON1
    MOVLW   0x01                ; RB0 Ã© definido como entrada, RB1-RB7 sÃ£o definidos como saÃ­da
    MOVWF   TRISB-0x80          ; Passou as configuraÃ§Ãµes para TrisB
    CLRF    TRISC-0x80          ; A Porta C Ã© configurada como sendo totalmente de saÃ­da
                                ; ? DÃºvida em como configurar o registrador ADCON 0, os 
                                ; 2 Ãºltimos bits, bits que configuram em relaÃ§Ã£o ao clock xx000001
    MOVLW   .249                ; MÃ³dulo do Timer2 serÃ¡ de 250
    MOVWF   PR2-0x80            ; Uma interrupÃ§Ã£o ocorrerÃ¡ a cada 1000 ciclos de relÃ³gio
                                ; SerÃ¡ necessÃ¡rio fazer uma conversÃ£o AD a cada 5000 ciclos de relÃ³gio
    BSF     PIE1-0x80, TMR2IE   ; InterrupÃ§Ã£o do Timer2 habilitada
    BSF     PIE1-0x80, ADIE     ; InterrupÃ§Ã£o A/D habilitada
    MOVLW   0x80                ; PortB PULLUP
    MOVWF   OPTION_REG-0x80	
    MOVLW   0x81                ; FOSC/32 - retorna AD apÃ³s 32 ciclos de clock, ADON, habilita para poder
                                ; comeÃ§ar a receber interrupÃ§Ãµes AD

    CLRF    STATUS              ; BANCO 0
	
	
	

Principal:
    ; COPIA VARIÃVEIS DE SOMATÃ“RIO
    BCF     STATUS, C
    RLF     Soma
    RLF     Soma+1
    RLF     Soma+2
    BCF     STATUS, C
    RLF     Soma
    RLF     Soma+1
    RLF     Soma+2
    CPFF2B  Soma+1, Somadv64    ; Somadv64 = Soma / 64
    CPFF4B  SQuadFN, SQuadP     ; Copia de trabalho, SQuadP = SQuadFN

    ; APAGA LED INDICADOR DE NEGATIVO
    BCF     Negativo

    ; VERIFICA SE VAI MOSTRAR COMPONENTE ALTERNADA OU CONTÃNUA
    BTFSS   MostraRMS
    GOTO    ChaveRMS

ChaveDC:
    MOVFW   CalZ                ; Valor = Somadv64 - CalZ
    SUBWF   Somadv64, F
    SKPC
    DECF    Somadv64+1, F
    MOVFW   CalZ+1
    SUBWF   Somadv64+1, F
    SKPNC
    GOTO    FimChaveDC
    BSF     Negativo
    MOVLW   0xFF                ; Complemento a 2
    XORWF   Somadv64, F
    XORWF   Somadv64+1, F
    INCF    Somadv64, F
    SKPNC
    INCF    Somadv64+1, F

FimChaveDC:
    CPFF2B  Somadv64, Valor
    GOTO    Escala
    
ChaveRMS:
    ; ValQ = Somadv64 ^ 2
    MOVFW   Somadv64            ; Somadv64 = XY (dois nÃºmeros de 8 bits)
    CAP
    MOVFW   DadoL               ; ValQ = (X^2)*(2^16)
    MOVWF   ValQ+2
    MOVFW   DadoH
    MOVWF   ValQ+3
    MULT8   Somadv64, Somadv64+1 ; ValQ += X*Y*(2^9)
    BCF     STATUS, C
    RLF     ProdL, F
    RLF     ProdH, F
    BTFSC   STATUS, C
    INCF    ValQ+3, F
    MOVFW   ProdL
    ADDWF   ValQ+1, F
    MOVFW   ProdH
    SKPNC
    ADDLW   .1
    SKPC
    ADDWF   ValQ+2, F
    SKPNC
    INCF    ValQ+3, F
    MOVFW   Somadv64+1          ; ValQ += Y^2
    CAP
    MOVFW   DadoL
    ADDWF   ValQ
    MOVFW   DadoH
    SKPNC
    ADDLW   .1
    SKPC
    ADDWF   ValQ+1, F
    SKPNC	
    INCF    ValQ+2, F
    SKPNC
    INCF    ValQ+3, F           ; ValQ = Somadv64^2

    ; ValQ = ValQ * 128 / 150
    CPFF4B  ValQ, ValQAux
    CRLF    ValQAux+4
    CRLF    ValQAux+5
    SHL6B   ValQAux
    ADD4B6B ValQ, ValQAux
    SHL6B   ValQAux
    SHL6B   ValQAux
    SHL6B   ValQAux
    SHL6B   ValQAux
    ADD4B6B ValQ, ValQAux
    SHL6B   ValQAux
    SHL6B   ValQAux
    SHL6B   ValQAux
    ADD4B6B ValQ, ValQAux
    SHL6B   ValQAux
    ADD4B6B ValQ, ValQAux       ; ValQAux = ValQ * 0x0625
    ADD4B   ValQ, ValQAux+2     ; ValQAux += ValQ * 2^16
    CPFF4B  ValQAux+2, ValQ     ; ValQ = ValQAux >> 16

    ; ValQ = SQuadP - ValQ
    COM2F4B  ValQ
    ADD4B    SQuadP, ValQ

    ; SQRT (ValQ)
    ; W = bit mais significativo de SQuadP + 1
    CLRF    Valor+1
    MOVLW   .32
    MOVWF   Valor

    BTFSC   SQuadP+3, 7
    GOTO    CalcValor
    DECF    Valor, F
    BTFSC   SQuadP+3, 6
    GOTO    CalcValor
    DECF    Valor, F
    BTFSC   SQuadP+3, 5
    GOTO    CalcValor
    DECF    Valor, F
    BTFSC   SQuadP+3, 4
    GOTO    CalcValor
    DECF    Valor, F
    BTFSC   SQuadP+3, 3
    GOTO    CalcValor
    DECF    Valor, F
    BTFSC   SQuadP+3, 2
    GOTO    CalcValor
    DECF    Valor, F
    BTFSC   SQuadP+3, 1
    GOTO    CalcValor
    DECF    Valor, F
    BTFSC   SQuadP+3, 0
    GOTO    CalcValor
    DECF    Valor, F
    BTFSC   SQuadP+2, 7
    GOTO    CalcValor
    DECF    Valor, F
    BTFSC   SQuadP+2, 6
    GOTO    CalcValor
    DECF    Valor, F
    BTFSC   SQuadP+2, 5
    GOTO    CalcValor
    DECF    Valor, F
    BTFSC   SQuadP+2, 4
    GOTO    CalcValor
    DECF    Valor, F
    BTFSC   SQuadP+2, 3
    GOTO    CalcValor
    DECF    Valor, F
    BTFSC   SQuadP+2, 2
    GOTO    CalcValor
    DECF    Valor, F
    BTFSC   SQuadP+2, 1
    GOTO    CalcValor
    DECF    Valor, F
    BTFSC   SQuadP+2, 0
    GOTO    CalcValor
    DECF    Valor, F
    BTFSC   SQuadP+1, 7
    GOTO    CalcValor
    DECF    Valor, F
    BTFSC   SQuadP+1, 6
    GOTO    CalcValor
    DECF    Valor, F
    BTFSC   SQuadP+1, 5
    GOTO    CalcValor
    DECF    Valor, F
    BTFSC   SQuadP+1, 4
    GOTO    CalcValor
    DECF    Valor, F
    BTFSC   SQuadP+1, 3
    GOTO    CalcValor
    DECF    Valor, F
    BTFSC   SQuadP+1, 2
    GOTO    CalcValor
    DECF    Valor, F
    BTFSC   SQuadP+1, 1
    GOTO    CalcValor
    DECF    Valor, F
    BTFSC   SQuadP+1, 0
    GOTO    CalcValor
    DECF    Valor, F
    BTFSC   SQuadP, 7
    GOTO    CalcValor
    DECF    Valor, F
    BTFSC   SQuadP, 6
    GOTO    CalcValor
    DECF    Valor, F
    BTFSC   SQuadP, 5
    GOTO    CalcValor
    DECF    Valor, F
    BTFSC   SQuadP, 4
    GOTO    CalcValor
    DECF    Valor, F
    BTFSC   SQuadP, 3
    GOTO    CalcValor
    DECF    Valor, F
    BTFSC   SQuadP, 2
    GOTO    CalcValor
    DECF    Valor, F
    BTFSC   SQuadP, 1
    GOTO    CalcValor
    DECF    Valor, F

CalcValor:
    ; Valor =  (W + 1) / 2
    BSF     STATUS, C
    RRF     Valor, F
    ; Valor = (1 >> Valor) - 1
    MOVFW   Valor
    SKPNZ
    GOTO    CalcQuoc
    CLRF    Valor
    INCF    Valor, F

Rotate:
    BSF     STATUS, C
    RLF     Valor, F
    RLF     Valor+1, F
    SUBLW   .1
    SKPZ
    GOTO    Rotate

    MOVLW   .1
    SUBWF   Valor, F
    SKPC
    DECF    Valor+1, F

CalcQuoc:
    ; Quoc = ValQ / Valor
;DV32P16:
    CPFF4B  VALQ,DIVIDENDO  ; 01-08
    COMF    VALOR,W         ; 09
    ADDLW   1               ; 10
    MOVWF   COMPDIV         ; 11
    COMF    VALOR+1,W       ; 12
    SKPNC                   ; 13
    ADDLW   1               ; 14
    MOVWF   COMPDIV+1       ; 15
    MOVLW   .16             ; 17
    MOVWF   CONTABIT        ; 18
DESLOCA:
    RLF     DIVIDENDO,F     ; 19,38|45
    RLF     DIVIDENDO+1,F   ; 20,
    RLF     DIVIDENDO+2,F   ; 21,
    RLF     DIVIDENDO+3,F   ; 22,
    SKPNC                   ; 23,
    GOTO    SUBTRAI         ; 24-25
    SOMA16  DIVIDENDO+2,COMPDIV,W   ; 25-31
    SKPC                    ; 32,
    GOTO    PRXBIT          ; 33-34,
SUBTRAI:
    SOMA16  DIVIDENDO+2,COMPDIV,F   ; 35-41,
PRXBIT:
    DECFSZ  CONTABIT,F      ; 35|42
    GOTO    DESLOCA         ; 36-37|43-44
    RLF     DIVIDENDO,F
    RLF     DIVIDENDDO+1,F
    ; Valor = (Valor + Quoc) / 2
    SOMA16   Quoc, Valor, F
    BCF     STATUS, C
    RRF     Valor, F
    RRF     Valor+1, F

    ; (Quoc == Valor)?
    MOVFW   Valor
    SUBWF   Quoc, W
    SKPZ
    GOTO    TestaMais
    MOVFW   Valor+1, W
    SUBWF   Quoc+1, W
    SKPNZ
    GOTO    Escala

TestaMais:
    ; (Quoc + 1 == Valor)?
    MOVLW   .1
    ADDWF   Quoc, F
    SKPNC
    INCF    Quoc+1, F

    MOVFW   Valor
    SUBWF   Quoc, W
    SKPZ
    GOTO    CalcQuoc
    MOVFW   Valor+1, W
    SUBWF   Quoc+1, W
    SKPZ
    GOTO    CalcQuoc

Escala:
    
    GOTO    Principal

    END
