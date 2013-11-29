Soma:		3 bytes
SQuad:		4 bytes
Amostra:	2 bytes
Quad: 		3 bytes
NAmostras:	2 bytes


IntTimer:
;

IntAD:	;Passará o valor da conversão AD para a variável Amostra

; ....

SomaAD:	
	MOVF	Amostra, w
	ADDWF	SomaFN, f
	MOVF	Amostra+1, w
	SKPNC	
	ADDLW	1
	SKPC
	ADDWF	SOMAFN+1, f
	SKPNC
	INCF	SOMAFN+2, f

CalcQuad:
	MOVF    Amostra,w
	ANDLW   0x7F        ; 2.5.1. W = Amostra & 0x7F;
	CLRF    Quad+1
	CLRF    Quad+2      ; Quad = 0;
	BTFSC   Amostra+1,1 ; if ( Amostra & 0x200 )
	ADDWF   QUAD+1,f    ;    Quad += W * 256; //* nunca pode dar vai um!
	RLF 	Quad+1,f
	RLF 	Quad+2,f    ; Quad *= 2;
	BTFSC   Amostra+1,0 ; if ( Amostra & 0x100 )
	ADDWF   Quad+1,f    ;    Quad += W * 256;
	SKPNC           ; if ( vai um )
	INCF    Quad+2,f    ;    Quad += 0x10000;
	BCF 	STATUS,C
	RLF 	Quad+1,f
	RLF 	Quad+2,f    ; Quad *= 2;
	BTFSC   Amostra,7   ; if ( Amostra & 0x80 )
	ADDWF   Quad+1,f    ;    Quad += W * 256;
	SKPNC           ; if ( vai um )
	INCF    Quad+2,f    ;    Quad += 0x10000;
	; 2.5.2. Quad = W * ( Amostra >> 7 ) * 256;
	BSF 	Status,RP1  ; banco 2
	MOVWF   EEADR-0x100 ; EEADRH deve conter a parte alta do endereço da tabela
	BSF	Status,RP0  ; banco 3
	BSF	EECON1-0x180,RD ; EECON1.EEPGD = 1!
	NOP
	NOP
	BCF	STATUS,RP0  ; banco 2
	MOVF	EEDATA-0x100,w
;   	BCF 	STATUS,RP1  ; banco 0: Não é necessário porque Quad é acessível no banco 2!
	MOVWF	QUAD
;   	BSF 	STATUS,RP1  ; banco 2
	MOVF    EEDATH-0x100,w
;   	BCF 	STATUS,RP1  ; banco 0: Não é necessário porque Quad e Amostra são acessíveis!
	ADDWF   QUAD+1,f
	SKPNC
	INCF    Quad+2,f    ; 2.5.3. Quad += TabQuad [ W ];
	RLF 	Amostra,w
	RLF 	Amostra+1,w
	ADDLW   	0x80
;   	BSF 	Status,RI1  ; banco 2
	MOVWF   EEADR-0x100 ; EEADRH deve conter a parte alta do endereço da tabela
	BSF 	Status,RP0  ; banco 3
	BSF 	EECON1-0x180,RD ; EECON1.EEPGD = 1!
	NOP
	NOP
	BCF 	STATUS,RP0  ; banco 2
	MOVF    EEDATA-0x100,w
;   	BCF 	STATUS,RP1  ; banco 0: Não é necessário porque Quad é acessível no banco 2!
	ADDWF   QUAD+1,f
	SKPNC
	INCF    Quad+2,f
;   	BSF 	STATUS,RP1  ; banco 2
	MOVF    EEDATH-0x100,w
	BCF 	STATUS,RP1  ; banco 0
	ADDWF   QUAD+2,f    ; 2.5.4. Quad += TabQuad [ ( Amostra * 2 ) >> 8 + 0x80 ];

SomaQuad:
	MOVF 	Quad, w
	ADDWF	SQuad, f
	MOVF	Quad+1, w
	SKPNC
	ADDLW	1
	SKPC
	ADDWF	SQuad+1, f
	MOVF	Quad+2, f
	SKPNC
	ADDLW	1
	SKPC
	ADDWF	Squad+2, f
	SKPNC
	INCF	Squad+3, f

