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

; Definindo pino que indicará a Chave RMS
#define MostraRMS   PortB, 0

; Definindo pino indicador de sinal negativo
#define Negativo  PortB,1

; Definindo pino da "bomba de tensão"
; Temos uma interrupção de timer a cada 1000 ciclos de relógio
; O tempo entre as interrupções é de 0.05 ms (50 milisegundos)
; Para um sinal com período 0.2 ms, inverteremos o valor desse pino
; a cada 2 interrupções
#define Bomba   PortB,2

; Definindo os pinos da porta B para selecionar o dígito no diplay
Selec:  equ PortB
#define SelUnid Selec,4 ; Pino 25: saída
#define SelDez  Selec,5 ; Pino 26: saída
#define SelCent Selec,6 ; Pino 27: saída
#define SelMil  Selec,7 ; Pino 28: saída

; Definindo saída do display de 7 segmentos
#define Saida   PortC

; Defines auxiliares
#define SETBIT  1   <<

; Variáveis

; Variáveis auxiliares
conta5:     equ 0x20    ; Armazena se ocorreu 4 interrupções
SalvaW:     equ 0x21    ; armazena w antes da interrupção
SalvaSt:    equ 0x22    ; armazena STATUS antes da interrupção
Mostra:     equ 0x23    ; 32 Bits

;=======Variáveis da rotina de Interrupção AD=====================

; Variável que recolhe as Amostras
Amostra:    equ 0x27    ; 16 bits

; Variável que guard a soma das Amostras
Soma:       equ 0x29    ; 24 bits

; Variável que guarda o quadrado da amostra
Quad:       equ 0x2C    ; 24 bits

; Variável que guarda a soma dos quadrados das amostras
Squad:      equ 0x2F    ; 32 bits

; Variável que guardará a quantidade de amostras coletadas
Contador:   equ 0x33    ; 16 bits

; Variável que guardará o resultado da última Soma dos quadrados
SquadFN:    equ 0x35    ; 32 bits

; Variável que guardará o resultado da última Soma das Amostras
SomaFN:     equ 0x39    ; 24 bits

;=========Variáveis do Programa Principal===================

; Variável que guardará uma cópia da Soma das Amostras dividido por 64
Somadv64:   equ 0x3C    ; 16 bits

; Variável que guardará uma cópia da Soma dos Quadrados
SQuadP:     equ 0x3E    ; 32 bits

; Variável que guardará o valor de calibração do Zero
CalZ:       equ 0x42    ; 16 bits

; Variável que guardará o Valor a ser apresentado
Valor:      equ 0x44    ; 16 bits


;==========Macros Auxiliares=================================
; copia uma variável para outra posição de memória
CPFF    MACRO   Origem, Destino
    MOVFW   Origem
    MOVWF   Destino
    ENDM

; copia variável de 2 bytes
CPFF2B  MACRO   Origem, Destino
    CPFF    Origem, Destino
    CPFF    Origem+1, Destino+1
    ENDM

; copia variável de 3 bytes
CPFF3B  MACRO   Origem, Destino
    CPFF    Origem, Destino
    CPFF    Origem+1, Destino+1
    CPFF    Origem+2, Destino+2
    ENDM

; copia variável de 4 bytes
CPFF4B  MACRO   Origem, Destino             
    CPFF    Origem, Destino
    CPFF    Origem+1, Destino+1
    CPFF    Origem+2, Destino+2
    CPFF    Origem+3, Destino+3
    ENDM

; Uma etapa da multiplicação, guardará o resultado parcial em PRODH e PRODL
MULBIT  MACRO   Fat1, Numbit
    BTFSC   Fat1, Numbit
    ADDWF   ProdH, F
    RRF     ProdH, F
    RRF     ProdL, F
    ENDM

; Multiplicação entre números de 8 bits. Resultado de 16 bits
MULT8   MACRO Fat1, Fat2          
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
    
; Macro que capturará o valor de W na Tabela.
; O valor será dado em DadoL e DadoH
CAP     MACRO
    BSF     STATUS,RP1      ; banco 2
    CLRF    EEADRH - 0x100  ; EEADRH Deve ser zerado
    MOVWF   EEADR-0x100     ; EEADRH deve conter a parte alta do endereço da tabela
    BSF     Status,RP0      ; banco 3
    BSF     EECON1-0x180,RD ; EECON1.EEPGD = 1!
    NOP
    NOP
    ; Nesse momento a captura já foi feita, basta pegá-lo nos registradores correspondentes
    BCF     STATUS,RP0      ; BANCO 2
    MOVFW   EEDATA-0x100    ; Parte Baixa
    BCF     STATUS, RP1     ; BANCO 0
    MOVWF   DadoL           ; Passou o Resultado da parte Baixa
    BSF     STATUS, RP0     ; BANCO 2
    MOVFW   EEDATH-0x100    ; Parte Alta
    BCF     STATUS, RP0     ; BANCO 0
    MOVWF   DadoH           ; Movendo a parte alta para DadoH
    
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
    ; ZERA A SAÍDA PARA EVITAR RUÍDO NA CONVERSÃO
    MOVLW   0XFF
    MOVWF   Saida

    ; MOVE A AMOSTRA DO AD PARA A VARIÁVEL AMOSTRA
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
    BCF     STATUS, C       ; Pois precisará dar alguns Rotates
    RLF     Amostra
    RLF     Amostra+1       ; Amostra+1 já possui os 3 bits mais significativos
                            ; Agora devemos fazer o Amostra ficar com os outros 7
                            ; Nos seus bits mais a esquerda
    BCF     STATUS, C
    RRF     Amostra         ; Amostra agora possui os 7 bits menos significativo
                            ; Agora basta aplicar o algoritmo aprendido em sala.
                            ; Amostra+1 equivale ao X e Amostra ao Y, sendo o número XY
    MOVFW   Amostra+1       ; Movendo a parte de 3 bits do número
    CAP                     ; Capturando o valor do Quadrado na tabela
    MOVFW   DADOL           ; Sendo o Amostra+1 um número de 3 bits, então o DadoH com certeza
                            ; Será 0
    MOVFW   Quad+2          ; Equivalente a multiplicar por 2^16, porém devemos multiplicar por
                            ; 2^14, portanto iremos dar dois RRF
    RRF     Quad+2
    RRF     Quad+1          ; Impossível dar Carry pois foi zerado no início do procedimento
    RRF     Quad+2
    RRF     Quad+1
    
    MULT8   Amostra, Amostra+1  ;Calculou o X*Y
    MOVFW   PRODL
    ADDWF   Quad+1, F
    SKPNC
    INCF    Quad+2
    MOVFW   PRODH
    ADDWF   Quad+2, F           ; Quad += X*Y*2^8
    
    MOVFW   Amostra         ; Movendo a parte de 7 bits do número
    CAP                     ; Capturando o valor do Quadrado do número de 7 bits
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
    
    DECF    conta5, F	    ;Decrementa em 1 o número de vezes que entrou na interrupção
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
    MOVWF   conta5              ; Armazena o valor 4 que irá ser decrementado a cada interrupção

    BCF     Status, RP0         ; BANCO 0
    BCF     Status, RP1         ; 
    BSF     INTCON,PEIE
    BSF     INTCON,GIE
    MOVLW   0x1C                ; Seleciona on no Timer2, seleciona o poscaler como 4, e o prescaler como 1
    MOVWF   T2CON
    CLRF    PortA               ; Inicializa PortA limpando toda a sua saída

    BSF     Status, RP0         ; BANCO 1
    MOVLW   0x0F                ; Valor usado para iniciar o sentido dos dados
    MOVWF   TRISA-0x80          ; Selecionou de RA0 a RA3 como entrada
    MOVLW   0x8D                ; Colocou como Right Justified (6 bits de ADRESH lidos como 0
                                ; e configurou para RA3 e RA2 serem VREF+ e VREF- e RA0 e RA1
                                ; como entradas analógicas
    MOVWF   ADCON1-0x80         ; Colocou as configurações acima no registrador ADCON1
    MOVLW   0x01                ; RB0 é definido como entrada, RB1-RB7 são definidos como saída
    MOVWF   TRISB-0x80          ; Passou as configurações para TrisB
    CLRF    TRISC-0x80          ; A Porta C é configurada como sendo totalmente de saída
                                ; ? Dúvida em como configurar o registrador ADCON 0, os 
                                ; 2 últimos bits, bits que configuram em relação ao clock xx000001
    MOVLW   .249                ; Módulo do Timer2 será de 250
    MOVWF   PR2-0x80            ; Uma interrupção ocorrerá a cada 1000 ciclos de relógio
                                ; Será necessário fazer uma conversão AD a cada 5000 ciclos de relógio
    BSF     PIE1-0x80, TMR2IE   ; Interrupção do Timer2 habilitada
    BSF     PIE1-0x80, ADIE     ; Interrupção A/D habilitada
    MOVLW   0x80                ; PortB PULLUP
    MOVWF   OPTION_REG-0x80	
    MOVLW   0x81                ; FOSC/32 - retorna AD após 32 ciclos de clock, ADON, habilita para poder
                                ; começar a receber interrupções AD

    CLRF    STATUS              ; BANCO 0
	
	
	

Principal:
    ; COPIA VARIÁVEIS DE SOMATÓRIO
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

    ; VERIFICA SE VAI MOSTRAR COMPONENTE ALTERNADA OU CONTÍNUA
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
    MOVFW   Somadv64            ; Somadv64 = XY (dois números de 8 bits)
    CAP
    MOVFW   DadoL               ; ValQ = (X^2)*(2^16)
    MOVWF   ValQ+2
    MOVFW   DadoH
    MOVWF   ValQ+3
    MULT8   Somadv64, Somadv64+1 ; ValQ += X*Y*(2^9)
    BCF     STATUS, C
    RLF     ProdL
    RLF     ProdH
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

Escala:
    
    GOTO    Principal

    END
