\ Bird Strike ROM
\
\ Zero page uses
jump           = &38        \ Ultimate jump destination
decompress_src = &50        \ Decompression source LSB/MSB
decompress_dst = &52        \ Decompression destination LSB/MSB
decompress_tmp = &54        \ Decompression temp workspace
decompress_ctr = &56        \ Decompression counter for user feedback
comline        = &F2        \ OS command line pointer

\ Stack
stack          = &100       \ Stack address

\ Build address
addr           = &8000      \ Sideways ROM/RAM

\ Relocation source and destination
relo           = &1400      \ Original load addres
game           = &1E00      \ Game start address

\ OS calls
osasci         = &FFE3      \ OSASCI
osnewl         = &FFE7      \ OSNEWL
oswrch         = &FFEE      \ OSWRCH
osbyte         = &FFF4      \ OSBYTE

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
	 CMP     #&03
	 BEQ     startup
	 CMP     #&09
	 BEQ     help
	 CMP     #&04
	 BEQ     skip \ unrecognised
	 PLA
	 RTS
	 
.startup
	 TYA
	 PHA
	 LDY     #&FF
	 
.suloop
	 INY
	 LDA     sutext,Y
	 JSR     oswrch
	 BNE     suloop
	 JSR     osnewl
	 JSR     osnewl
	 PLA
	 TAY
	 PLA
	 RTS
	 
.sutext
	 EQUS    "Bird Strike",&00
	 
.help
	 TYA
	 PHA
	 TXA
	 PHA
	 LDA      (comline), Y
	 CMP      #&0D          \ Plain *HELP?
	 BEQ      over          \ Skip to over
	 LDX      #&FF
	 DEY

.table_loop
	 INX
	 INY
	 LDA      table, X      \ Get current command table byte
	 CMP      (comline), Y  \ Compare with command line
	 BEQ      table_loop    \ Keep checking
	 CMP      #&FE          \ Not currently used
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
	 
.skip
	 JMP      unrecognised

.print_help
	 JSR      osnewl
	 LDX      #&FF
	
.help_loop                  \ Print the ROM title
     INX
	 LDA      title, X
	 JSR      osasci
	 BNE      help_loop
	 LDX      #&FF

.ver_loop                   \ Print the ROM version
	 INX
	 LDA      version, X
	 JSR      osasci
	 BNE      ver_loop
	 JSR      osnewl
	 LDX      #&FF
	 
.commands_loop              \ Print the ROM commands
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

\ On entry, X=&FF, Y=&00

.ctloop
	 INX
	 INY
	 
\ 1st loop X=&00, Y=&01 ((comline),0 is the *)

	 LDA      table, X      \ Get the current byte from the command table
	 BMI      found         \ end of string if A>=80, ie the jump address
	 LDA      (comline), Y  \ Get the current byte from the command line
	 CMP      #&2E			\ ASC"." - check for abbreviations
	 BNE      not_dot
	 LDA      table, X      \ Check we're not matching a dot with the end of the command
	 CMP      #&0D
	 BEQ      again         \ Try next command if so
	 
.skip_if_dot                \ Skip the rest of the current rom command
	 INX                    
	 LDA      table, X      
	 BMI      found         \ Jump to found when the jump address is encountered
	 BPL      skip_if_dot   \ Loop around until the table command is exhausted
	 
.not_dot
     AND      #&5F          \ Upper-case the comline
	 CMP      table, X      \ Compare with the command table
	 BEQ      ctloop        \ If matched keep testing

.again                      \ fetch next command in table
	 INX
	 LDA      table, X
	 BPL      again         \ Loop to skip the current jump address
	 CMP      #&FF          \ no more?
	 BEQ      out           \ none matched; exit
	 INX                    \ Skip the upper bit
	 LDY      stack         \ recover the comtable offset
	 JMP      ctloop        \ go again
	 
.out
.not_this_rom
	 PLA                    \ Restore everything...
	 TAX
	 PLA
	 TAY
	 PLA
	 RTS                    \ ... and return

.found
	 CMP      #&FF          \ Check for the end of the command table
	 BEQ      not_this_rom  \ If we've hit it, it's not for us
	 STA      jump+1        \ otherwise, put the LSB in jump...
	 INX
	 LDA      table, X
	 STA      jump          \ ...and the MSB in jump+1
	 JMP      (jump)        \ Then jump
	 
.table
	 EQUS     "BIRDS",&0D   \ &0D ensures that only *BIRDS matches, not *BIRDSTR etc
	 EQUB     instructions DIV 256
	 EQUB     instructions MOD 256
	 EQUB     &FF
	 	 
.commands
     EQUS     "  BIRDS"
	 EQUB     &00

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
	 \ VDU 23;10,32;0;0;0;
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
	 
	 \ Decompress the loading screen to MODE 7 screen memory
	 JSR     relocate

     \ Decompress the game to original load address
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
	 LDA     #&20
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
.srce
INCBIN "BIRDScmp"

\ The original game loading screen *SAVEd, compressed
\ and stored in ROM here
.loadsc
INCBIN "ldscrmp"

.end

SAVE "BirdStrike.rom", addr, end