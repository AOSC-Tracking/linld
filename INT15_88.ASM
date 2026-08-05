;***************************************************************
;****** This file is distributed under GPL
;***************************************************************
                CPU	386

        group   DGROUP  _TEXT _DATA


        SEGMENT	_DATA	ALIGN=1	public	use16	CLASS=DATA

        extern  _saved15



        SEGMENT	_TEXT	ALIGN=1	public	use16	CLASS=CODE

;***************************************************************
;void int15_88();
;***************************************************************
        global  near
        _int15_88:

                cmp     ah,88h
                je      @@_int15_88_do88
                jmp     [_saved15]
@@_int15_88_do88:
                pushf
                call    [_saved15]
                test    ax,ax
                jnz     @@_int15_88_ret

;****** Read extended mem size (CMOS bytes 17h,18h (lo,hi))
                mov     al,18h
                out     70h,al
                call    @@_int15_88_iodelay
                in      al,71h
                mov     ah,al
                mov     al,17h
                call    @@_int15_88_iodelay
                out     70h,al
                call    @@_int15_88_iodelay
                in      al,71h
@@_int15_88_ret:
                iret
@@_int15_88_iodelay:	retn


        end

;###### END OF FILE ############################################
