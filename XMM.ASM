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
;Get xmm driver addr or 0 if no xmm
;u32 get_xmm_driver()
;***************************************************************
        global  _get_xmm_driver:near
        proc    _get_xmm_driver near

                push    es bx

                mov     ax,4300h
                int     2fh
                cmp     al,80h
                jne     @@err
                mov     ax,4310h
                int     2fh
                mov     dx,es
                mov     ax,bx
                jmp     @@ret
@@err:
                xor     dx,dx
                xor     ax,ax
@@ret:
                pop     bx es
                ret
        endp    _get_xmm_driver


;***************************************************************
;u32 xmm_alloc(void* drv, u32 size)
;***************************************************************
        global  _xmm_alloc:near
        proc    _xmm_alloc near
                arg     drv     :dword, \
                        sz      :dword  = PARAM_SIZE

                push    bp
                mov     bp,sp

                push    ebx

                mov     ebx,[sz]        ;round up and convert to kb
                add     ebx,3ffh        ;
                shr     ebx,10          ;
                mov     dx,bx
                mov     ah,09h          ;allocate blk
                call    [drv]           ;
                test    ax,ax
                jz      @@err
                                        ;now: dx=handle of the blk
                mov     ah,0Ch          ;lock blk
                call    [drv]           ;
                test    ax,ax
                jz      @@err
                                        ;now: dx:bx=addr of blk
                mov     ax,bx
                jmp     @@ret
@@err:
                xor     dx,dx
                xor     ax,ax
@@ret:
                pop     ebx
                pop     bp
                ret
        endp    _xmm_alloc

        ends    _TEXT

        end

;###### END OF FILE ############################################
