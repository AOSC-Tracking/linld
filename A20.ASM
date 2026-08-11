;***************************************************************
;****** This file is distributed under GPL
;***************************************************************
                CPU	386

        group   DGROUP  _TEXT

        SEGMENT	_TEXT	ALIGN=1	public	use16	CLASS=CODE

;***************************************************************
;void enable_a20_kbd();
;***************************************************************
        global  _enable_a20_kbd
        _enable_a20_kbd:

                push    ax
                call    @@_enable_a20_kbd_empty_8042
                mov     al,0D1h         ; command write
                out     64h,al
                call    @@_enable_a20_kbd_empty_8042
                mov     al,0DFh         ; A20 on
                out     60h,al
                call    @@_enable_a20_kbd_empty_8042
                pop     ax
                retn

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

@@_enable_a20_kbd_empty_8042:
                push    cx
                xor     cx,cx           ; 64K iterations
@@_enable_a20_kbd_loop:
                call    @@_enable_a20_kbd_delay         ; 8042 status port
                in      al,64h          ; output buffer?
                test    al,1            ;
                jz      @@_enable_a20_kbd_no_output
                call    @@_enable_a20_kbd_delay         ; yes: read it
                in      al,60h          ;
                jmp     @@_enable_a20_kbd_cont          ;
@@_enable_a20_kbd_no_output:
                test    al,2            ; is input buffer full?
                jz      @@_enable_a20_kbd_break         ; no - break loop
@@_enable_a20_kbd_cont:
                loop    @@_enable_a20_kbd_loop
@@_enable_a20_kbd_break:
                pop     cx
                retn

@@_enable_a20_kbd_delay:        out     80h,al
                retn


;***************************************************************
;void enable_a20_fast();
;***************************************************************
        global  _enable_a20_fast
        _enable_a20_fast:

; You must preserve the other bits here. Otherwise embarrasing things
; like laptops powering off on boot happen. Corrected version by Kira
; Brown from Linux 2.2
                push    ax
                in      al,92h  ;
                or      al,02h  ; "fast A20" version
                out     92h,al  ; some chips have only this
                pop     ax
                retn


;***************************************************************
;void enable_a20_xmm(u32 drv);
;***************************************************************
        global  _enable_a20_xmm
        _enable_a20_xmm:

                %arg     drv:dword  = PARAM_SIZE

                push    bp
                mov     bp,sp
                push	ax
                push	bx
                mov     ah,03h          ;global enable a20
                call    [drv]           ;
                mov     ah,05h          ;local enable a20
                call    [drv]           ;
                pop	bx
                pop	ax
                retn


        end

;###### END OF FILE ############################################
