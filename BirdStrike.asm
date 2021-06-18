\ Bird Strike ROM
\
\ TODO: Fix *HELP hang

\ Zero page uses
from    = &70
to      = &72
comline = &F2
jump    = &38

decompress_src = &50
decompress_dst = &52
decompress_tmp = &54
decompress_ctr = &56

\ Stack
stack   = &100

\ Build address
addr    = &8000        \ Sideways ROM/RAM

\ Relocation source and destination
srce    = addr + &400  \ Align with original load address for simplicity
relo    = &1200        \ Original load addres
game    = &1E00        \ Game start address
pages   = &1E          \ Number of pages to relocate
loadsc  = &AC00        \ Loading screen ROM address. Align with &7C00 for simplicity

\ OS calls
osasci  = &FFE3
osnewl  = $FFE7
oswrch  = $FFEE
osbyte  = &FFF4

org   addr

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
	 STY      stack

.ctloop
	 INX
	 INY
	 LDA      table, X
	 BMI      found         \ end of string?
	 LDA      (comline), Y
	 
	 CMP      #&2E			\ ASC"." - check for abbreviations
	 BNE      not_dot
	 
.skip_if_dot                \ Skip the rest of the current rom command	 
	 INX                    
	 LDA      table, X      
	 BMI      found         \ Jump to found when the jump address is encountered
	 BPL      skip_if_dot   \ Loop around until the table command is exhausted
	 
.not_dot
     AND      #&5F          \ was &DF
	 CMP      table, X      \ keep testing for matches
	 BEQ      ctloop

.again                      \ fetech next command in table
	 INX
	 LDA      table, X
	 BPL      again
	 CMP      #&FF          \ no more?
	 BEQ      out           \ none matched; exit
	 INX
	 LDY      stack
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

	 STA      jump+1
	 INX
	 LDA      table, X
	 STA      jump
	 JMP      (jump)
	 
.table
	 EQUS     "BIRDS",&0D  \ &0D ensures that only *BIRDS matches, not *BIRDSTR etc
	 EQUB     instructions DIV 256
	 EQUB     instructions MOD 256
	 EQUS     "BTEST",&0D   \ Test
	 EQUB     birds DIV 256
	 EQUB     birds MOD 256
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
	 
.vdu
	 LDA     vducalls, Y
	 JSR     oswrch
	 DEY
	 BPL     vdu
	 JMP     vdu_done
	 
.vducalls
	         \ 23;10,32;0;0;0;
     EQUB    &00,&00,&00,&00,&00,&00,&20,&0A,&00,&17
	 
.vdu_done
	 \ Set up from and to addresses
	 
	 LDY     #LO(loadsc)
     STY     decompress_src
     LDA     #HI(loadsc)
     STA     decompress_src+1

	 LDY     #&00
     STY     decompress_dst
     LDA     #&7C
     STA     decompress_dst+1
	 
	 
	 \ Relocate loading screen to MODE 7 screen memory
	 JSR     relocate

\ Relocate game to original load address
.birds
	 \ Set up from and to addresses	
     LDY     #LO(srce)
     STY     decompress_src
     LDA     #HI(srce)
     STA     decompress_src+1
	 LDY     #LO(relo)
     STY     decompress_dst
     LDA     #HI(relo)
     STA     decompress_dst+1
	 JSR     relocate
	 
	 \ Clear the counter
	 LDA     #&00
	 STA     &7FE5
	 STA     &7FE6
	 
	 \ Fix some copy-protection
	 LDA     #&01
	 STA     &5D
	 
	 \ Launch the game
	 JMP     game


.relocate
INCLUDE "trickys_decompactor.asm"


\ The original game binary compressed and stored in ROM
org srce
INCBIN "BIRDScmp"

\ The original game loading screen *SAVEd, compressed
\ and stored in ROM here
org loadsc
INCBIN "ldscrmp"

.end

SAVE "BirdStrike.rom", addr, end