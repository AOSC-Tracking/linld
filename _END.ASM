;***************************************************************
;****** This file is distributed under GPL
;***************************************************************
                CPU	386

        SEGMENT	_TEXT	ALIGN=1	public	use16	CLASS=CODE
        global  byte
        _text_end:

        SEGMENT	_DATA	ALIGN=1	public	use16	CLASS=DATA
        global  byte
        _data_end:

        SEGMENT	_BSS	ALIGN=1	public	use16	CLASS=BSS
        global  byte
        _bss_end:

        end

;###### END OF FILE ############################################
