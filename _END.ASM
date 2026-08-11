;***************************************************************
;****** This file is distributed under GPL
;***************************************************************
                CPU	386

        SEGMENT	_TEXT	ALIGN=1	public	use16	CLASS=CODE
        global  _text_end
        _text_end:

        SEGMENT	_DATA	ALIGN=1	public	use16	CLASS=DATA
        global  _data_end
        _data_end:

        SEGMENT	_BSS	ALIGN=1	public	use16	CLASS=BSS
        global  _bss_end
        _bss_end:

        end

;###### END OF FILE ############################################
