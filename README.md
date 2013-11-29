Pequenas mudanças:
==================

1. Tinha esquecido a saída para a "bomba de tensão" necessária para gerar -4V e + 9V;
2. Inclui esta saída e mudei a ordem dos bits da porta B;
3. Aumentei o tempo entre as amostras de 200 para 250 microssegundos;
4. Diminui o número total de amostras por medida de 4096 para 4000;
5. As alterações 4 e 5 fazem o tempo total de cada medida ficar igual a exatamente:
	250 x 4000 microssegundos =  1 segundo.


Amplificador operacional:
=========================
1. Deve ser alimentado com -4V e +9V
2. ganho 1 + 100 / 11 = 10.090909....
3. Entrada +: recebe a saída do sensor "Hall"
4. Entrada -: recebe 3 resistores:
	R1=100K, vai para a saída do amplificador; 
	R2=22k, vai para terra; 
	R3=22k, vai para +5V.

Portas de ES:
=============
1. A:	A0 a A3 são usados pelo conversor AD;
2. B:	B0 recebe a chave "DC/RMS",
	B1 controla o LED de "negativo", B2 produz o sinal para a "bomba de tensão",
	B4 a B7 selecionam os algarismos mostrados ( B4=milésimos, B5=centésimos, B6=décimos, B7=unidades ); 
3. C:	segmentos do mostrador de sete segmentos + ponto decimal;


Pinos do PIC16F870:
===================

```
	Sinais	Pinos		Pinos	Sinais
	Reset\	 1.MCLR\	28.RB7	SelUnidade
	AmpOp	 2.RA0=AN0	27.RB6	SelDécimo
		 3.RA1=AN1	26.RB5	SelCentésimo
	Terra	 4.RA2=VRef-	25.RB4	SelMilésimo
	+5V	 5.RA3=VRef+	24.RB3
		 6.RA4		23.RB2	"Bomba de Tensão"
		 7.RA5		22.RB1	LED de negativo
	Terra	 8.Vss		21.RB0	Chave "DC/RMS"
	Xtal1	 9.Osc1		20.VDD	+5V
	Xtal2	10.Osc2		19.Vss	Terra
	SegA\	11.RC0		18.RC7	SegPonto\
	SegB\	12.RC1		17.RC6	SegG\
	SegC\	13.RC2		16.RC5	SegF\
	SegD\	14.RC3		15.RC4	SegE\
```


Estrutura geral do programa:
============================

Declaracao de variável: recebe o nome da variável e seu tamanho em bytes.

```
Var:	MACRO	Nome,Tam
Nome:	equ	PrxVar
PrxVar:	+=	Tam
	ENDM

;PrxVar:	=	0x20		; endereço da primeira variável
```

Outra forma para declarar variáveis, que é um pouco melhor:

```
	cblock	0x70
		SalvaW,SalvaS	; W e Status salvos no início da rotina de interrupção
		ENDC

	cblock	0x20
		endc
```

Rotina de interrupção:
======================

```
	ORG	4

IniInt:	macro
	movwf	SalvaW
	swapf	STATUS,W
	movwf	SalvaS
	clrf	STATUS
	ENDM

FimInt: macro
	swapf	SalvaW,f
	swapf	SalvaS,W
	movwf	STATUS
	swapf	SalvaW,w
	RETFIE
	ENDM

Interrupcao:
	IniInt
	btfsc	PIR1,TMR2IF
	goto	Acada250
	btfsc	PIR1,ADIF
	goto	FimConvAD
FinalInt:
	FimInt
```

1. Acada250: Interrupção do temporizador ( a cada 250 microssegundos = 1250 ciclos de instrução ):
	```
	CBlock	
		PrxAlg		; próximo algarismo a ser apresentado
		Numero:4	; algarismos do número que está sendo apresentado:
				;  	[0]=milésimo, [1]=centésimo, [2]=décimo, [3]=unidade.
		ENDC
	1.1. ZeraInt: { bcf PIR1,TMR2IF };
	1.2. Apaga: apaga o algarismo apresentado ( PortC = 0xFF );
	1.3. IniAD: inicia conversão AD; { bsf ADCON0,GO }
	1.4. CalcSelAlg: Calcula o próximo algarismo do número que será apresentado;
		1.4.1. PortB += PortB & 0xF0; { movf PORTB,W / andlw 0xF0 / addwf SelAlg,f }
		1.4.2. se ( deu vai um ) Seta o bit 4 de SelAlg; { skpnc / bsf SelAlg,4 }
		1.4.3. W = Numero[0];
		1.4.4. se ( SelAlg & 0x20 ) W = Numero[1];
		1.4.5. se ( SelAlg & 0x40 ) W = Numero[2];
		1.4.6. se ( SelAlg & 0x80 ) W = Numero[3];
		1.4.7. PrxAlg = W;
	1.5. FimInt: restaura o contexto do programa interrompido.
	```

2. FimConvAD: Final da conversão AD:
	```
	Cblock	
		Amostra:2	; valor da amostra obtida pelo AD
		Quad:3		; valor do quadrado da amostra obtida pelo AD
		Soma:3		; somatório das amostras ( max=4000x1023=4092000: 22 bits )
		SQuad:4		; somatório dos quadrados das amostras ( max=4000x1023x1023=4.186E9: 32 bits )
		Conta:2		; contador de amostras ( max=4000: 12 bits )
		SomaFN:3	; valor final do somatório das amostras
		SQuadFN:4	; valor final do somatório dos quadrados das amostras
		ENDC
	2.1. ZeraInt: { bcf PIR1,ADIF }
	2.2. Mostra: Mostra o proximo algarismo do número que está sendo apresentado ( PortC = PrxAlg );
	2.3. LeValAD: Copia o valor obtido pelo conversor AD para Amostra;
		2.3.1. W = ADRESL; { bsf STATUS,RP1 / movf ADRESL-0x80,w / bcf STATUS,RP1 }
		2.3.2. Amostra[0] = W; { movwf Amostra }
		2.3.3. Amostra[1] = ADRESH; { movf ADRESH,W / movWF Amostra+1 }
	2.4. Inverte o valor de B2 ( bomba de tensão ) { movlw 4 / xorwf PortB,F }
	2.5. CalcQuad: Quad = Amostra * Amostra;
		2.5.1. W = Amostra & 0x7F; //* Sete bits menos significativos da amostra
		2.5.2. Quad = W * ( Amostra >> 7 ) * 256;
		2.5.3. Quad += TabQuad [ W ];
		2.5.4. Quad += TabQuad [ ( Amostra >> 7 ) + 0x80 ] * 256;
	2.6. SomaAD: Soma += Amostra;
	2.7. SomaQuad: SQuad += Quad;
	2.8. IncConta: Conta++;
	2.9. TstConta: Se ( Conta == 4096 ): { btfss Conta+1,4 / goto FinalInt }
		2.9.1. SomaFn = Soma; 
		2.9.2. SQuadFn = Squad;
		2.9.3. Soma = Squad = 0;
		2.9.4. Conta = 0x8000 + 96; { movlw .96 / movwf Conta / movlw 0x80 / movwf Conta+1 }
	2.10. FimInt: restaura o contexto do programa interrompido
	```

Programa principal:
===================

1. Reset:
	```
	Cblock	
		CalZ:2		; Valor de calibração do zero
		ENDC
	1.1. IniPortas: Configura as portas A, B e C;
	1.2. IniAD: Configura o conversor AD;
	1.3. IniTmr: Configura o TMR para contar 1000 ciclos de instrução ( 0.2ms );
	1.4. IniLePgm: EEADRH = PagTabQuad;  EECON1 = 0x80;
	1.5. IniSoma: Soma = 0;
	1.6. IniConta: Conta = 96;
	1.7. IniNum: Numero = "CAL."
	1.8. IniInt: Configura interrupções;
	1.9. Calibra: 
		1.9.1. Espera até que o bit 15 de conta esteja com valor 1;
		1.9.2. Zera o bit 15 de Conta;
		1.9.3. SomaFN = SomaFN << 2;
		1.9.4. CalZ [ 0 ] = SomaFN [ 1 ];
		1.9.5. CalZ [ 1 ] = SomaFN [ 2 ];
	```

2. Cálculos: Repetidos indefinidamente!
	```
	Cblock
		Somadv64:2	; somatório das amostras dividido por 64;
		SQuadP:4	; cópia do somatório dos quadrados das amostras
		ValQ:4		; quadrado do valor RMS
		Valor:2		; valor a ser apresentado
		Quoc:2		; ValQ / Valor
		ENDC
	2.1. PegaParam: 
		2.1.1. Espera até que o bit 15 de conta esteja com valor 1;
		2.1.2. Zera o bit 15 de conta;
		2.1.3. SomaFN = SomaFN << 2;
		2.1.4. Somadv64 [ 0 ] = SomaFN [ 1 ];
		2.1.5. Somadv64 [ 1 ] = SomaFN [ 2 ];
		2.1.6. SQuadPr = SQuadFn;
	2.2. ApagaNeg: Apaga o Led "negativo"
	2.3. ChaveDC: Se a chave estiver na posição DC:
		2.3.1. Valor = Somadv64 - CalZ;
		2.3.2. Se deu pede emprestado:
			2.3.2.1. Complementa a dois o Valor;
			2.3.2.2. Acende o Led "negativo";
	2.4. ChaveRMS: Se a chave estiver na posição RMS:
		2.4.1. ValQ = Somadv64 * Somadv64;
		2.4.2. ValQ *= 128 / 125;
		2.4.3. ValQ = SQuadPr - ValQ;
		2.4.4. Valor = Raiz Quadrada ( ValQ );
			2.4.4.1. W = número do bit mais signif. de ValQ com valor um ( 0 a 31 );
			2.4.4.2. W = ( W + 1 ) / 2;
			2.4.4.3. Valor = ( 1 >> W ) - 1;
			2.4.4.4. Quoc = ValQ / Valor; //* divisão de 32 bits por 16 bits!
			2.4.4.4. Valor = ( Valor + Quoc ) / 2;
			2.4.4.5. Se ( ( Quoc != Valor ) && ( ( Quoc + 1 ) != Valor ) ) volta para 2.4.4.4.
	2.5. Escala: Valor = Valor * FatorEscala;
	2.6. ConvDec: Converte Valor para decimal e coloca a
		 representaçao em sete segmentos dos quatro algarismos em Número
	```

Alguns detalhamentos:
=====================

```
CalcQuad:
	movf	Amostra,w
	andlw	0x7F		; 2.5.1. W = Amostra & 0x7F;
	Clrf	Quad+1
	clrf	Quad+2		; Quad = 0;
	btfsc	Amostra+1,1	; if ( Amostra & 0x200 )
	addwf	QUAD+1,f	;    Quad += W * 256; //* nunca pode dar vai um!
	rlf	Quad+1,f
	rlf	Quad+2,f	; Quad *= 2;
	btfsc	Amostra+1,0	; if ( Amostra & 0x100 )
	addwf	Quad+1,f	;    Quad += W * 256;
	skpnc			; if ( vai um )
	incf	Quad+2,f	;    Quad += 0x10000;
	bcf	STATUS,C
	rlf	Quad+1,f
	rlf	Quad+2,f	; Quad *= 2;
	btfsc	Amostra,7	; if ( Amostra & 0x80 )
	addwf	Quad+1,f	;    Quad += W * 256;
	skpnc			; if ( vai um )
	incf	Quad+2,f	;    Quad += 0x10000;
				; 2.5.2. Quad = W * ( Amostra >> 7 ) * 256;
	bsf	Status,RP1	; banco 2
	movwf	EEADR-0x100	; EEADRH deve conter a parte alta do endereço da tabela
	bsf	Status,RP0	; banco 3
	bsf	EECON1-0x180,RD	; EECON1.EEPGD = 1!
	nop
	nop
	bcf	STATUS,RP0	; banco 2
	movf	EEDATA-0x100,w
;	bcf	STATUS,RP1	; banco 0: Não é necessário porque Quad é acessível no banco 2!
	movwf	QUAD
;	bsf	STATUS,RP1	; banco 2
	movf	EEDATH-0x100,w
;	bcf	STATUS,RP1	; banco 0: Não é necessário porque Quad e Amostra são acessíveis!
	addwf	QUAD+1,f
	skpnc
	incf	Quad+2,f	; 2.5.3. Quad += TabQuad [ W ];
	rlf	Amostra,w
	rlf	Amostra+1,w
	addlw	0x80
;	bsf	Status,RP1	; banco 2
	movwf	EEADR-0x100	; EEADRH deve conter a parte alta do endereço da tabela
	bsf	Status,RP0	; banco 3
	bsf	EECON1-0x180,RD	; EECON1.EEPGD = 1!
	nop
	nop
	bcf	STATUS,RP0	; banco 2
	movf	EEDATA-0x100,w
;	bcf	STATUS,RP1	; banco 0: Não é necessário porque Quad é acessível no banco 2!
	addwf	QUAD+1,f
	skpnc
	incf	Quad+2,f
;	bsf	STATUS,RP1	; banco 2
	movf	EEDATH-0x100,w
	bcf	STATUS,RP1	; banco 0
	addwf	QUAD+2,f	; 2.5.4. Quad += TabQuad [ ( Amostra * 2 ) >> 8 + 0x80 ];
```

```
SomaAD:	movf	Amostra,w
	addwf	Soma,f
	movf	Amostra+1,w
	skpnc
	addlw	1
	skpc	
	addwf	Soma+1,f
	skpnc
	incf	Soma+2,f
```

```
SomaQuad:
	movf	Quad,w
	addwf	SQuad,f
	movf	Quad+1,w
	skpnc
	addlw	1
	skpc
	addwf	SQuad+1,f
	movf	Quad+2,f
	skpnc
	addlw	1
	skpc
	addwf	Squad+2,f
	skpnc
	incf	Squad+3,f
```

```
PagTabQuad:	equ	7

	org	PagTabQuad * 0x100

Num:	=	0
	while	( Num < 0x80 )
	dw	num * num
Num:	+=	1
	endw
Num:	=	0
	while	( num < 8 )
	dw	num * num * .64
Num:	+=	1
	endw	
```

