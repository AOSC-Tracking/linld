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
;void enable_a20_kbd();
;***************************************************************
        global  _enable_a20_kbd:near
        proc    _enable_a20_kbd near

                push    ax
                call    @@empty_8042
                mov     al,0D1h         ; command write
                out     64h,al
                call    @@empty_8042
                mov     al,0DFh         ; A20 on
                out     60h,al
                call    @@empty_8042
                pop     ax
                ret

; This routine checks that the keyboard command queue is empty
; (after emptying the output buffers)
; Some machines have delusions that the keyboard buffer is always full
; with no keyboard attached...
; If there is no keyboard controller, we will usually get 0xff
; to all the reads.  With each IO taking a microsecond and
; a timeout of 100,000 iterations, this can take about half a
; second ("delay" == out to port 0x80). That should be ok,
; and should also be plenty of time for a real keyboard controller
; to empty.

@@empty_8042:
                push    cx
                xor     cx,cx           ; 64K iterations
@@loop:
                call    @@delay         ; 8042 status port
                in      al,64h          ; output buffer?
                test    al,1            ;
                jz      @@no_output
                call    @@delay         ; yes: read it
                in      al,60h          ;
                jmp     @@cont          ;
@@no_output:
                test    al,2            ; is input buffer full?
                jz      @@break         ; no - break loop
@@cont:
                loop    @@loop
@@break:
                pop     cx
                ret

@@delay:        out     80h,al
                ret
        endp    _enable_a20_kbd


;***************************************************************
;void enable_a20_fast();
;***************************************************************
        global  _enable_a20_fast:near
        proc    _enable_a20_fast near

; You must preserve the other bits here. Otherwise embarrasing things
; like laptops powering off on boot happen. Corrected version by Kira
; Brown from Linux 2.2
                push    ax
                in      al,92h  ;
                or      al,02h  ; "fast A20" version
                out     92h,al  ; some chips have only this
                pop     ax
                ret
        endp    _enable_a20_fast


;***************************************************************
;void enable_a20_xmm(u32 drv);
;***************************************************************
        global  _enable_a20_xmm:near
        proc    _enable_a20_xmm near

                arg     drv     :dword  = PARAM_SIZE

                push    bp
                mov     bp,sp
                push    ax bx
                mov     ah,03h          ;global enable a20
                call    [drv]           ;
                mov     ah,05h          ;local enable a20
                call    [drv]           ;
                pop     bx ax
                ret
        endp    _enable_a20_xmm

        ends    _TEXT

        end

;###### END OF FILE ############################################
