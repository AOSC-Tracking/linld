;***************************************************************
;****** This file is distributed under GPL
;***************************************************************
                ideal
                %crefref
                %noincl
                %nomacs
                p386

        group   DGROUP  _TEXT,_DATA
        assume  cs:DGROUP


        segment _DATA byte public use16 'DATA'

        global  _saved15:dword

        ends    _DATA


        segment _TEXT byte public use16 'CODE'

;***************************************************************
;void int15_88();
;***************************************************************
        global  _int15_88:near
        proc    _int15_88 near

                cmp     ah,88h
                je      @@do88
                jmp     [_saved15]
@@do88:
                pushf
                call    [_saved15]
                test    ax,ax
                jnz     @@ret

;****** Read extended mem size (CMOS bytes 17h,18h (lo,hi))
                mov     al,18h
                out     70h,al
                call    @@iodelay
                in      al,71h
                mov     ah,al
                mov     al,17h
                call    @@iodelay
                out     70h,al
                call    @@iodelay
                in      al,71h
@@ret:
                iret
@@iodelay:	retn
        endp    _int15_88

        ends    _TEXT

        end

;###### END OF FILE ############################################
