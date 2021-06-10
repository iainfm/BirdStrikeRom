\ Bird Strike ROM
\
\ Zero page uses
from    = &70
to      = &72


\ Relocation source and destination
addr    = &8000        \ ROM build address
srce    = addr + &400  \ Align with original load address for simplicity
relo    = &1400        \ Original load addres
game    = &1E00        \ Game start address
pages   = &1D          \ Number of pages to relocate
loadsc  = &AC00        \ Loading screen ROM address. Align with &7C00 for simplicity

\ OS calls
osasci  = &FFE3
osnewl  = $FFE7
oswrch  = $FFEE
osbyte  = &FFF4

\ ROM things
comline = &F2

org addr

\ ROM header based on Bruce Smith's code
.romstart
     EQUB    &00
	 EQUW    &00
	 JMP     service
	 EQUB    &82
	 EQUB    offset MOD 256
	 EQUB    &01
	 
.title
     EQUS    "Bird Strike"
	 EQUB    &00
	 
.version
     EQUS    " 1.00"
	 EQUB    &00
	 
.offset
     EQUB    &00
	 EQUS    "(C) A.E. Frigaard & I.F. McLaren"
	 EQUB    &00
	 
.service
     PHA
	 CMP     #&09
	 BEQ     help
	 CMP     #&04
	 BEQ     unrecognised
	 PLA
	 RTS
	 
.help
	 TYA
	 PHA
	 TXA
	 PHA
	 LDA      (comline), Y
	 CMP      #&0D
	 BEQ      over
	 LDX      #&FF
	 DEY

.table_loop
	 INX
	 INY
	 LDA      table, X
	 CMP      (comline), Y
	 BEQ      table_loop
	 CMP      #&FE
	 BEQ      details
	 PLA
	 TAX
	 PLA
	 TAY
	 JMP      return
	
.over
	 JSR      print_help
	 PLA
	 TAX
	 PLA
	 TAY
	 
.return
	 PLA
	 RTS

.print_help
	 JSR      osnewl
	 LDX      #&FF
	
.help_loop
     INX
	 LDA      title, X
	 JSR      osasci
	 BNE      help_loop
	 
	 LDX      #&FF

.ver_loop
	 INX
	 LDA      version, X
	 JSR      osasci
	 BNE      ver_loop
	 JSR      osnewl
	 
	 LDX      #&FF
	 
.commands_loop
	 INX
	 LDA      commands, X
	 JSR      osasci
	 BNE      commands_loop
	 JSR      osnewl
	 LDX      #&FF
	 RTS

.details
	 JSR      print_help
	 LDX      #&FF
	 
.detail_loop
	 INX
	 LDA      commands, X
	 JSR      osasci
	 BNE      detail_loop
	 JSR      osnewl
	 PLA
	 TAX
	 PLA
	 TAY
	 PLA
	 RTS
	
.unrecognised
	 TYA
	 PHA
	 TXA
	 PHA
	 LDX      #&FF
	 DEY
	 STY      &100

.ctloop
	 INX
	 INY
	 LDA      table, X
	 BMI      found
	 CMP      (comline), Y
	 BEQ       ctloop

.again
	 INX
	 LDA      table, X
	 BPL      again
	 CMP      #&FF
	 BEQ      out
	 INX
	 LDY      &100
	 JMP      ctloop
	 
.out
.not_this_rom
	 PLA
	 TAX
	 PLA
	 TAY
	 PLA
	 RTS

.found
	 CMP      #&FF
	 BEQ      not_this_rom
	 STA      &39
	 INX
	 LDA      table, X
	 STA      &38
	 JMP      (&38)
	 
.table
	 EQUS     "BIRDS"
	 EQUB     instructions DIV 256
	 EQUB     instructions MOD 256
	 EQUB     &FF
	 	 
.commands
     EQUS     "  BIRDS"
	 EQUB     $00

\ Game relocation code

.instructions
     \ Select tape filing system
	 \ Probably not required for all games
     LDA     #&8C
	 JSR     osbyte
	 
	 \ Change to MODE 7
     LDA     #&16
	 JSR     oswrch
	 LDA     #&07
	 JSR     oswrch
	 
	 \ Disable the cursor
	 LDY     #&0A
	 
\ Relocate loading screen to MODE 7 screen memory
.vdu
	 LDA     vducalls, Y
	 JSR     oswrch
	 DEY
	 BPL     vdu
	 JMP     vdu_done
	 
.vducalls
     EQUB    &00,&00,&00,&00,&00,&00,&20,&0A,&00,&17
	 
.vdu_done
	 \ Set up from and to addresses
     LDY     #&00
	 STY     from
	 LDA     #HI(loadsc)
	 STA     from+1
	 STY     to
	 LDA     #&7C    \ MODE 7 screen address
	 STA     to+1
	 LDX     #&03    \ 3 pages is sufficient
	 JSR     relocate
	 \ JMP     found \ remove this

\ Relocate game to original load address
.birds
	 \ Set up from and to addresses
     LDY     #&00
     STY     from
     LDA     #HI(srce)
     STA     from+1

     STY     to
     LDA     #HI(relo)
     STA     to+1

     LDX     #pages
	 JSR     relocate
	 JMP     game

\ Relocation loop
.relocate
.loop
     LDA     (from),Y
     STA     (to),Y
     INY
     BNE     loop
     INC     from+1
     INC     to+1
     DEX
     BNE     loop
	 RTS


\ The original game binary stored in ROM and
\ copied to &1400 when launched
org srce
INCBIN "BIRDS"

org loadsc
INCBIN "loadsc"

.end

SAVE "BirdStrike.rom", addr, end