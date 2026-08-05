;***************************************************************
;****** This file is distributed under GPL
;***************************************************************
                CPU	386

        group   DGROUP  _TEXT _DATA _BSS

        SEGMENT	_TEXT	ALIGN=1	public	use16	CLASS=CODE

                RESB     100h
        global  byte
        ..start:
        _text_start:
                EXTERN   _main
                call    NEAR _main
                mov     ah,4ch
                int     21h

        SEGMENT	_DATA	ALIGN=1	public	use16	CLASS=DATA
        global  byte
        _data_start:

        SEGMENT	_BSS	ALIGN=1	public	use16	CLASS=BSS
        global  byte
        _bss_start:

        end

;###### END OF FILE ############################################
