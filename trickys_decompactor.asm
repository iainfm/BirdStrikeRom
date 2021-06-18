\ Relocation decompression loop
\ Decompaction code by 'Tricky' - http://www.retrosoftware.co.uk/forum/viewtopic.php?f=73&t=999

	ldx #0                  ; (zp,x) will be used to access (zp,0)
	stx      decompress_ctr
	
.for
	lda decompress_ctr  ; progress counter
	
	 \ TODO: Progress counter - needs modified to work with decompressor
	 
	 \ PHA                \ Save A
	 PHA                \ Save A
	 LSR     A          \ Divide by 16 to get MSB
	 LSR     A          \ Max MSB should be 4 (16k ROM) or 8 (32k rom)
	 LSR     A          \ So no need to worry about hexifying it
	 LSR     A          
	 \ ORA     #&30       \ ASC"0"
	 SED                \ Decimal processing
	 CMP     #&0A       \ Compare with 10
	 ADC     #&30       \ Add 30+1
	 CLD                \ Clear decimal flag
	 STA     &7FE5      \ Write to M7 screen memory
	 PLA                \ Restore A
	 AND     #&0F       \ Get LSB
	 SED                \ Decimal processing
	 CMP     #&0A       \ Compare with 10
	 ADC     #&30       \ Add 30+1
	 CLD                \ Clear decimal flag
	 STA     &7FE6      \ Write to M7 screen memory
     \ PLA	
	
	lda (decompress_src,x)  ; next control byte
	beq done                ; 0 signals end of decompression
	bpl copy_raw            ; msb=0 means just copy this many bytes from source
	clc
	adc #&80 + 2            ; flip msb, then add 2, we wont request 0 or 1 as that wouldn't save anything
	sta decompress_tmp      ; count of bytes to copy (>= 2)
	ldy #1                  ; byte after control is offset
	lda (decompress_src),y  ; offset from current src - 256
	tay
	
		lda decompress_src  ; advance src past the control byte and offset
		clc
		adc #2
		sta decompress_src
		bcc pg1
		inc decompress_src+1
	.pg1
	
.copy_previous              ; copy tmp bytes from dst - 256 + offset

	dec decompress_dst+1    ; -256
	lda (decompress_dst),y  ; +y
	inc decompress_dst+1    ; +256
	sta (decompress_dst,x)  ; +0
	
		inc decompress_dst  ; INC dst (used for both src of copy (-256) and dst)
		bne pg2
		inc decompress_dst+1
		inc decompress_ctr
	.pg2
	
	dec decompress_tmp      ; count down bytes to copy
	bne copy_previous
	beq for                 ; after copying, go back for next control byte

.copy_raw

	tay                     ; bytes to copy from src
.copy
	
		inc decompress_src  ; INC src (1st time past control byte)
		bne pg3
		inc decompress_src+1
	.pg3
	
	dey
	bmi for
	lda (decompress_src,x)  ; copy bytes
	sta (decompress_dst,x)
	
		inc decompress_dst  ; INC dst
		bne pg4
		inc decompress_dst+1
	.pg4
	
	bne copy                ; rest of bytes ; #1 replace with jmp if wrapping back to &0000 is required

.done
	 RTS