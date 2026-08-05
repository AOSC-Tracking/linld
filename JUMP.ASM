;***************************************************************
;****** This file is distributed under GPL
;***************************************************************
                CPU	386

        group   DGROUP  _TEXT

        SEGMENT	_TEXT	ALIGN=1	public	use16	CLASS=CODE

;***************************************************************
;void set_sregs_jump_seg_ofs(u16 sr, u16 sp, u16 seg, u16 ofs);
;****** Never returns
;***************************************************************
        global  near
        _set_sregs_jump_seg_ofs:

                %arg    sreg:word,  \
                        stk:word,  \
                        jmpseg:word,  \
                        jmpofs:word   = PARAM_SIZE

                push    bp      ;TODO: kinda useless, isn't it?
		mov	bp,sp

              ;;mov     ax,[jmpseg]     ;Move data to CS segment var
              ;;mov     [seg2],ax       ;  we cannot use any other seg!
              ;;mov     ax,[jmpofs]     ;
              ;;mov     [ofs2],ax       ;
                mov     cx,[jmpofs]     ;Do NOT load in r32:
                mov     dx,[jmpseg]     ;  wrong order!

                mov     ax,[sreg]
                mov     sp,[stk]        ;Do not use [bp+n] after this...
                mov     ds,ax
                mov     es,ax
                mov     ss,ax
                mov     fs,ax
                mov     gs,ax

              ;;jmp     [dword ofs2]

                push	dx
                push	cx
                retf
; Data
;;ofs2            dw      ?
;;seg2            dw      ?

;        ends    _TEXT

        end

;###### END OF FILE ############################################
