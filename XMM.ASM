;***************************************************************
;****** This file is distributed under GPL
;***************************************************************
                CPU	386

        group   DGROUP  _TEXT

        SEGMENT	_TEXT	ALIGN=1	public	use16	CLASS=CODE

;***************************************************************
;Get xmm driver addr or 0 if no xmm
;u32 get_xmm_driver()
;***************************************************************
        global  _get_xmm_driver
        _get_xmm_driver:

                push	es
                push	bx

                mov     ax,4300h
                int     2fh
                cmp     al,80h
                jne     @@_get_xmm_driver_err
                mov     ax,4310h
                int     2fh
                mov     dx,es
                mov     ax,bx
                jmp     @@_get_xmm_driver_ret
@@_get_xmm_driver_err:
                xor     dx,dx
                xor     ax,ax
@@_get_xmm_driver_ret:
                pop	bx
                pop	es
                retn


;***************************************************************
;u32 xmm_alloc(void* drv, u32 size)
;***************************************************************
        global  _xmm_alloc
        _xmm_alloc:
                %arg    drv:dword, \
                        sz:dword = PARAM_SIZE

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
                jz      @@_xmm_alloc_err
                                        ;now: dx=handle of the blk
                mov     ah,0Ch          ;lock blk
                call    [drv]           ;
                test    ax,ax
                jz      @@_xmm_alloc_err
                                        ;now: dx:bx=addr of blk
                mov     ax,bx
                jmp     @@_xmm_alloc_ret
@@_xmm_alloc_err:
                xor     dx,dx
                xor     ax,ax
@@_xmm_alloc_ret:
                pop     ebx
                pop     bp
                retn


        end

;###### END OF FILE ############################################
