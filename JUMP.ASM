;***************************************************************
;****** This file is distributed under GPL
;***************************************************************
                ideal
                %crefref
                %noincl
                %nomacs
                p386

        group   DGROUP  _TEXT
        assume  cs:DGROUP,ds:DGROUP

        segment _TEXT byte public use16 'CODE'

;***************************************************************
;void set_sregs_jump_seg_ofs(u16 sr, u16 sp, u16 seg, u16 ofs);
;****** Never returns
;***************************************************************
        global  _set_sregs_jump_seg_ofs:near
        proc    _set_sregs_jump_seg_ofs near

                arg     sreg    :word,  \
                        stk     :word,  \
                        jmpseg  :word,  \
                        jmpofs  :word   = PARAM_SIZE

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
		assume	nothing
		assume	cs:DGROUP

              ;;jmp     [dword ofs2]

                push    dx cx
                retf
; Data
;;ofs2            dw      ?
;;seg2            dw      ?
        endp    _set_sregs_jump_seg_ofs

        ends    _TEXT

        end

;###### END OF FILE ############################################
