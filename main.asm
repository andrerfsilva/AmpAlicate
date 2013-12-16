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
; Temos uma interrupcao de timer a cada 1000 ciclos de relogio
; O tempo entre as interrupcoes e de 0.05 ms (50 milisegundos)
; Para um sinal com periodo 0.2 ms, inverteremos o valor desse pino
; a cada 2 interrupcoes
#define Bomba   PortB,2

; Definindo os pinos da porta B para selecionar o digito no diplay
Selec:  equ PortB
#define SelUnid Selec,4 ; Pino 25: saida
#define SelDez  Selec,5 ; Pino 26: saida
#define SelCent Selec,6 ; Pino 27: saida
#define SelMil  Selec,7 ; Pino 28: saida

; Definindo saida do display de 7 segmentos
#define Saida   PortC

; Defines auxiliares
#define SETBIT  1   <<

;=======Variaveis=================================================
    CBLOCK 0x70
        SalvaW
        SalvaS   ; W e Status salvos no inicio da rotina de interrupcao
    ENDC

    CBLOCK 0x20
    ENDC

;=======Variaveis auxiliares======================================
    CBLOCK
        Mostra:4    ; Valor a ser apresentado no display
    ENDC

;=======Variaveis da rotina de Interrupcao AD=====================
    CBLOCK
        Conta5      ; Armazena se ocorreu 4 interrupcoes
        Amostra:2   ; Variavel que recolhe as Amostras
        Soma:3      ; Variavel que guarda a soma das Amostras
        Quad:3      ; Variavel que guarda o quadrado da amostra
        SQuad:4     ; Variavel que guarda a soma dos quadrados das amostras
        Contador:2  ; Variavel que guarda a quantidade de amostras coletadas
        DadoL       ; Resultado da consulta a tabela de quadrados (MACRO CAP)
        DadoH
        ProdLi      ; Resultado da multiplicacao entre um valor de 3 bits por um de 7 bits
        ProdHi
        SquadFN:4   ; Variavel que guarda o resultado da ultima Soma dos quadrados
        SomaFN:3    ; Variavel que guarda o resultado da ultima Soma das Amostras
    ENDC

;========Variaveis do Programa Principal==========================
    CBLOCK
        Somadv64:2  ; Variavel que guarda uma copia da Soma das Amostras dividido por 64
        SQuadP:4    ; Variavel que guarda uma copia da Soma dos Quadrados
        CalZ:2      ; Variavel que guarda o valor de calibracao do Zero
        Valor:2     ; Variavel que guardara o Valor a ser apresentado
        ValQ:4      ; Quadrado do valor RMS
        ValQAux:6   ; 
        Quoc:2      ; ValQ / Valor
        Dividendo:4
        CompDivisor:2
        ContaBit    ; Contador do loop de divisao.
        ProdL       ; Resultado da multiplicacao entre dois numeros de 1 byte
        ProdH
        Conv:3      ; Auxiliar para converter Valor para a base 10
    ENDC

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

; Uma etapa da multiplicacao guarda o resultado parcial em PRODH e PRODL
MULBIT  MACRO   Fat1, Numbit
    BTFSC   Fat1, Numbit
    ADDWF   ProdH, F
    RRF     ProdH, F
    RRF     ProdL, F
    ENDM

; Multiplicacao entre 2 numeros de 8 bits. Resultado de 16 bits.
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

; Faz SHL de uma variavel de 6 bytes
SHL6B MACRO Var
    BCF     Status, C
    RLF     Var, F
    RLF     Var+1, F
    RLF     Var+2, F
    RLF     Var+3, F
    RLF     Var+4, F
    RLF     Var+5, F
    ENDM
    
; Macro que consulta o valor de W na Tabela.
; O valor sera dado em DadoL e DadoH.
CAP     MACRO
    BSF     STATUS,RP1      ; BANCO 2
    MOVWF   EEADR-0x100     ; EEADR contem a parte baixa do endereco da tabela (EEADR = W)
    MOVLW   PagTabQuad
    MOVWF   EEADRH-0x100    ; EEADRH contem a parte alta do endereco da tabela (EEADRH = PagTabQuad)
    BSF     Status,RP0      ; BANCO 3
    BSF     EECON1-0x180,RD ; EECON1.EEPGD = 1!
    NOP
    NOP
    ; Nesse momento a captura ja foi feita, basta pega-lo nos registradores correspondentes
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
; O resultado e armazenado em Dest6.
ADD4B6B MACRO Font4, Dest6
    MOVFW   Font4
    ADDWF   Dest6, F
    MOVFW   Font4+1
    SKPNC
    ADDLW   .1
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

; Soma duas variaveis de 4 bytes.
ADD4B MACRO Font4, Dest4
    MOVFW   Font4
    ADDWF   Dest4, F
    MOVFW   Font4+1
    SKPNC
    ADDLW   .1
    SKPC
    ADDWF   Dest4+1, F
    MOVFW   Font4+2
    SKPNC
    ADDLW   .1
    SKPC
    ADDWF   Dest4+2, F
    MOVFW   Font4+3
    SKPNC
    ADDLW   .1
    SKPC
    ADDWF   Dest4+3, F
    ENDM

; Complemento a 2 de uma variavel de 4 bytes. Var4 = -Var4
COM2F4B MACRO Var4
    COMF    Var4, F
    COMF    Var4+1, F
    COMF    Var4+2, F
    COMF    Var4+3, F
    MOVLW   .1
    ADDWF   Var4, F
    SKPNC
    ADDWF   Var4+1, F
    SKPNC
    ADDWF   Var4+2, F
    SKPNC
    ADDWF   Var4+3, F
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


; Rotate Left numa variavel de 3 bytes.
RL3	MACRO	FONTE
	RLF	FONTE,F
	RLF	FONTE+1,F
	RLF	FONTE+2,F
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
    MOVWF   SalvaS
    CLRF    STATUS
    MOVLW   0xFF
    MOVWF   Saida

    BTFSC   PIR1, ADIF
    GOTO    ADINT
    BTFSC   PIR1, TMR2IF
    GOTO    TM2INT
    GOTO    FimInt

ADINT:
    ; ZERA A SAIDA PARA EVITAR RUIDO NA CONVERSAO
    MOVLW   0XFF
    MOVWF   Saida

    ; MOVE A AMOSTRA DO AD PARA A VARIAVEL AMOSTRA
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
    CLRF    Quad            ; Zera o valor do Quadrado, pois ainda iremos calcular
    CLRF    Quad+1
    CLRF    Quad+2
    BCF     STATUS, C       ; Pois precisara dar alguns Rotates
    RLF     Amostra, F
    RLF     Amostra+1, F    ; Amostra+1 possui os 3 bits mais significativos.
                            ; Agora devemos fazer o Amostra ficar com os outros 7
                            ; nos seus bits mais a direita.
    BCF     STATUS, C
    RRF     Amostra, F      ; Amostra agora possui os 7 bits menos significativos
                            ; Agora basta aplicar o algoritmo aprendido em sala.
                            ; Amostra+1 equivale ao X e Amostra ao Y, sendo o numero XY
    MOVFW   Amostra+1       ; Movendo a parte de 3 bits do numero
    CAP                     ; Capturando o valor do Quadrado na tabela
    MOVFW   DADOL           ; Sendo o Amostra+1 um numero de 3 bits, entao o DadoH com certeza
                            ; Sera 0
    MOVFW   Quad+2          ; Equivalente a multiplicar por 2^16, porem devemos multiplicar por
                            ; 2^14, portanto iremos dar dois RRF
    RRF     Quad+2, F
    RRF     Quad+1, F       ; Impossivel dar Carry pois foi zerado no inicio do procedimento
    RRF     Quad+2, F
    RRF     Quad+1, F
    
    ;Calculou o X*Y
    CLRF    ProdLi
    CLRF    ProdHi
    BCF     STATUS, C
    MOVFW   Amostra
    BTFSC   Amostra+1, 2
    MOVWF   ProdLi
    RLF     ProdLi, F
    BTFSC   Amostra+1, 1
    ADDWF   ProdLi, F
    SKPNC
    INCF    ProdHi, F
    RLF     ProdLi, F
    RLF     ProdHi, F
    BTFSC   Amostra+1, 0
    ADDWF   ProdLi, F
    SKPNC
    INCF    ProdHi, F

    MOVFW   PRODLi
    ADDWF   Quad+1, F
    SKPNC
    INCF    Quad+2, F
    MOVFW   PRODHi
    ADDWF   Quad+2, F           ; Quad += X*Y*2^8
    
    MOVFW   Amostra         ; Movendo a parte de 7 bits do numero
    CAP                     ; Capturando o valor do Quadrado do numero de 7 bits
    MOVFW   DADOL
    ADDWF   Quad, F
    MOVFW   DADOH
    SKPNC
    ADDLW   .1
    SKPC
    ADDWF   Quad+1, F

    SKPNC
    INCF    Quad+2, F       ; Quad += Y^2
    
    ; SOMA DOS QUADRADOS DAS AMOSTRAS
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
    BTFSS   Contador+1, 4 ; testa se sao 4000 amostras
    GOTO    FimADInt
    MOVLW   .96
    MOVWF   Contador
    CLRF    Contador+1
    BSF     Contador+1, 7
    CPFF3B  Soma, SomaFN
    CPFF4B  SQuad, SQuadFN
    CLRF    Soma
    CLRF    Soma+1
    CLRF    Soma+2
    CLRF    SQuad
    CLRF    SQuad+1
    CLRF    SQuad+2
    CLRF    SQuad+3

FimADInt:
    BCF     PIR1, ADIF
    GOTO    FimInt

TM2INT:	
    MOVLW   0xFF
    MOVWF   Saida 		    ;Apaga o display de 7 segmentos
    
    BTFSC   SelMil
    GOTO    TMil
    BTFSC   SelCent
    GOTO    TCent
    BTFSC   SelDez
    GOTO    TDez
    BTFSC   SelUnid
    GOTO    TUnid
        
TMil:
    BCF     SelMil
    BSF     SelCent
    MOVF    Mostra+2,W
    GOTO    MostraDigito
    
TCent:
    BCF     SelCent
    BSF     SelDez
    MOVF    Mostra+1,W
    GOTO    MostraDigito
    
TDez:
    BCF     SelDez
    BSF     SelUnid
    MOVF    Mostra,W
    GOTO    MostraDigito

TUnid:
    BCF     SelUnid
    BSF     SelMil
    MOVF    Mostra+3,W
    
MostraDigito:
    MOVWF   Saida
    
    BTFSC   SelDez      ; Bomba de tensao, periodo = 0.2 ms
    BCF     Bomba
    BTFSC   SelMil
    BSF     Bomba
    
    DECFSZ  Conta5, F   ; Decrementa em 1 o numero de vezes que entrou na interrupcao
    GOTO    FimTM2INT
    BSF     ADCON0, GO  ; Inicia a conversao AD a cada 250 ms
    MOVLW   .5
    MOVWF   Conta5

FimTM2INT:
    BCF     PIR1, TMR2IF
    
FimInt:    
    SWAPF   SalvaS,W
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
    BCF     Status, RP0         ; BANCO 0
    BCF     Status, RP1
    
    ; Inicializando variaveis
    MOVLW   .5
    MOVWF   Conta5              ; Armazena o valor 5 que sera decrementado a cada interrupcao de timer
    MOVLW   .96
    MOVWF   Contador            ; Inicializa contador de amostras (4000 por segundo)
    CLRF    Contador+1
    
    BSF     INTCON,PEIE
    BSF     INTCON,GIE
    MOVLW   0x1C                ; Seleciona on no Timer2, seleciona o poscaler como 4, e o prescaler como 1
    MOVWF   T2CON

    BSF     Status, RP0         ; BANCO 1
    MOVLW   0x0F                ; Valor usado para iniciar o sentido dos dados
    MOVWF   TRISA-0x80          ; Selecionou de RA0 a RA3 como entrada
    MOVLW   0x8D                ; Colocou como Right Justified (6 bits de ADRESH lidos como 0
                                ; e configurou para RA3 e RA2 serem VREF+ e VREF- e RA0 e RA1
                                ; como entradas analogicas
    MOVWF   ADCON1-0x80         ; Colocou as configuracoes acima no registrador ADCON1
    MOVLW   0x01                ; RB0 e definido como entrada, RB1-RB7 sao definidos como saida
    MOVWF   TRISB-0x80          ; Passou as configuracoes para TrisB
    CLRF    TRISC-0x80          ; A Porta C e configurada como sendo totalmente de saida
                                ; ? Duvida em como configurar o registrador ADCON 0, os 
                                ; 2 ultimos bits, bits que configuram em relacao ao clock xx000001
    MOVLW   .249                ; Modulo do Timer2 sera de 250
    MOVWF   PR2-0x80            ; Uma interrupcao ocorrera a cada 1000 ciclos de relogio
                                ; Sera necessario fazer uma conversao AD a cada 5000 ciclos de relogio
    BSF     PIE1-0x80, TMR2IE   ; Interrupcao do Timer2 habilitada
    BSF     PIE1-0x80, ADIE     ; Interrupcao A/D habilitada
    MOVLW   0x80                ; PortB PULLUP
    MOVWF   OPTION_REG-0x80	
    MOVLW   0x81                ; FOSC/32 - retorna AD apos 32 ciclos de clock, ADON, habilita para poder
                                ; comecar a receber interrupcoes AD

    CLRF    STATUS              ; BANCO 0

Calibra:
    ; CALIBRA O ZERO NO RESET
    BTFSS   Contador+1, 7       ; Espera bit de sincronizacao
    GOTO    Principal
    BCF     Contador+1, 7

    BCF     STATUS, C
    RLF     SomaFN, F
    RLF     SomaFN+1, F
    RLF     SomaFN+2, F
    BCF     STATUS, C
    RLF     SomaFN, F
    RLF     SomaFN+1, F
    RLF     SomaFN+2, F
    CPFF2B  SomaFN+1, CalZ

Principal:
    BTFSS   Contador+1, 7       ; Espera bit de sincronizacao
    GOTO    Principal
    BCF     Contador+1, 7

    ; COPIA VARIAVEIS DE SOMATORIO
    BCF     STATUS, C
    RLF     SomaFN, F
    RLF     SomaFN+1, F
    RLF     SomaFN+2, F
    BCF     STATUS, C
    RLF     SomaFN, F
    RLF     SomaFN+1, F
    RLF     SomaFN+2, F
    CPFF2B  SomaFN+1, Somadv64  ; Somadv64 = Soma / 64
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
    ; Complemento a 2
    COMF    Somadv64, F
    COMF    Somadv64+1, F
    MOVLW   .1
    ADDWF   Somadv64, F
    SKPNC
    INCF    Somadv64+1, F

FimChaveDC:
    CPFF2B  Somadv64, Valor
    GOTO    Escala
    
ChaveRMS:
    CLRF    ValQ
    CLRF    ValQ+1
    ; ValQ = Somadv64 ^ 2
    ; Somadv64 = XY (dois numeros de 8 bits)
    MULT8   Somadv64, Somadv64
    MOVFW   ProdL               ; ValQ = (X^2)*(2^16)
    MOVWF   ValQ+2
    MOVFW   ProdH
    MOVWF   ValQ+3
    MULT8   Somadv64, Somadv64+1 ; ValQ += X*Y*(2^9)
    BCF     STATUS, C
    RLF     ProdL, F
    RLF     ProdH, F
    SKPNC
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
    MULT8   Somadv64+1, Somadv64+1 ; ValQ += Y^2
    MOVFW   ProdL
    ADDWF   ValQ, F
    MOVFW   ProdH
    SKPNC
    ADDLW   .1
    SKPC
    ADDWF   ValQ+1, F
    SKPNC	
    INCF    ValQ+2, F
    SKPNC
    INCF    ValQ+3, F           ; ValQ = Somadv64^2

    ; ValQ = ValQ * 128 / 125
    CPFF4B  ValQ, ValQAux
    CLRF    ValQAux+4
    CLRF    ValQAux+5
    SHL6B   ValQAux             ; 0x0625 = 0000 0110 0010 0101 
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
    SHL6B   ValQAux
    ADD4B6B ValQ, ValQAux       ; ValQAux = ValQ * 0x0625
    ADD4B   ValQAux+2, ValQ     ; ValQ = ValQ * (128 / 125)

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
    MOVWF   COMPDIVISOR     ; 11
    COMF    VALOR+1,W       ; 12
    SKPNC                   ; 13
    ADDLW   1               ; 14
    MOVWF   COMPDIVISOR+1   ; 15
    MOVLW   .16             ; 17
    MOVWF   CONTABIT        ; 18
DESLOCA:
    RLF     DIVIDENDO,F     ; 19,38|45
    RLF     DIVIDENDO+1,F   ; 20,
    RLF     DIVIDENDO+2,F   ; 21,
    RLF     DIVIDENDO+3,F   ; 22,
    SKPNC                   ; 23,
    GOTO    SUBTRAI         ; 24-25
    SOMA16  DIVIDENDO+2,COMPDIVISOR,W   ; 25-31
    SKPC                    ; 32,
    GOTO    PRXBIT          ; 33-34,
SUBTRAI:
    SOMA16  DIVIDENDO+2,COMPDIVISOR,F   ; 35-41,
PRXBIT:
    DECFSZ  CONTABIT,F      ; 35|42
    GOTO    DESLOCA         ; 36-37|43-44
    RLF     DIVIDENDO,F
    RLF     DIVIDENDO+1,F
    ; Valor = (Valor + Quoc) / 2
    SOMA16   Quoc, Valor, F
    RRF     Valor, F
    RRF     Valor+1, F

    ; (Quoc == Valor)?
    MOVFW   Valor
    SUBWF   Quoc, W
    SKPZ
    GOTO    TestaMais
    MOVFW   Valor+1
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
    MOVFW   Valor+1
    SUBWF   Quoc+1, W
    SKPZ
    GOTO    CalcQuoc

Escala:

ConvBase10:
    ; Converte Valor para a base 10. Conv = (10)Valor
    ; e armazena os digitos no formato SeteSeg em Mostra.
    call	Mul5
	movf	Conv+2,w
	call	SeteSeg
	movwf	Mostra+3
	CPFF2B	Conv,Valor
	call	Mul5
	RL3     Conv
	movf	Conv+2,w
	call	SeteSeg
	movwf	Mostra+2	
	CPFF2B	Conv,Valor
	call	Mul5
	RL3     Conv
	movf	Conv+2,w
	call	SeteSeg
	movwf	Mostra+1
	CPFF2B	Conv,Valor
	call	Mul5
	RL3     Conv
	movf	Conv+2,w
	call	SeteSeg
	movwf	Mostra
	
    
    GOTO    Principal
    
 ;-------------------- ROTINAS --------------------------
Mul5:	clrf	Conv+2	; rotina que faz Conv = Valor * 5.
	bcf	STATUS,C
	rlf	Valor,w
	movwf	Conv
	rlf	Valor+1,w
	movwf	Conv+1
	rlf	Conv+2,f
	rlf	Conv,f
	rlf	Conv+1,f
	rlf	Conv+2,f
	movf	Valor,w
	addwf	Conv,f
	movf	Valor+1,w
	skpnc
	addlw	.1
	skpz
	addwf	Conv+1,f
	skpnc
	incf	Conv+2,f
	return


;-------- TABELA DE QUADRADOS PARA NUMEROS DE 7 BITS ---------
PagTabQuad: equ 7

    ORG PagTabQuad * 0x100

Num:    =   0
    WHILE   ( Num < 0x80 )
    DW  Num * Num
Num:    +=  1
    ENDW

    END
