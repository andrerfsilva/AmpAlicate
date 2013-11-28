SomaFN:		3 posições

SQuadFN:	4 posições

amostraAD:	2 posições


IntTimer:
	;

IntAD:	;Passará o valor da conversão AD para a variável amostraAD
	MOVF	amostraAD, w
	ADDWF	SomaFN, f
	MOVF	amostraAD+1, w
	SKPNC	
	ADDLW	1
	SKPC
	ADDWF	SOMAFN+1, f
	SKPNC
	INCF	SOMAFN+2, f
	



