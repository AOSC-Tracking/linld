;***************************************************************
;****** This file is distributed under GPL
;***************************************************************
                CPU	386

        group   DGROUP  _TEXT

        SEGMENT	_TEXT	ALIGN=1	public	use16	CLASS=CODE

;***************************************************************
;u32 memtop_88()
;***************************************************************
        global  near
        _memtop_88:

                mov     ah,88h
                int     15h             ;ax=kbs above 1m
                jnc     @@_memtop_88_ok            ;  error: cf=1 or ax=0
                xor     ax,ax           ;
@@_memtop_88_ok:
                xor     dx,dx
                test    ax,ax           ;happens on big mem systems
                jz      @@_memtop_88_ret
               ;add     ax,400h         ;account for 1024 low kb
               ;adc     dx,0
                add     ah,4h           ;account for 1024 low kb
                adc     dx,dx           ;  (optimized to death)
                shld    dx,ax,10        ;multiply by 1024
                shl     ax,10           ;  (kbytes -> bytes)
@@_memtop_88_ret:
                retn


;***************************************************************
;u32 memtop_e801()
;***************************************************************
        global  near
        _memtop_e801:

                push	cx
                push	bx
                stc                     ;fix to work around buggy
                xor     cx,cx           ;  BIOSes which dont clear/set
                xor     dx,dx           ;  carry on pass/error of
                mov     ax,0E801h
                int     15h
                jc      @@_memtop_e801_err
                test    cx,cx           ;kludge to handle BIOSes
                jnz     @@_memtop_e801_use_cxdx      ;  which report their extended
                test    dx,dx           ;  memory in AX/BX rather than
                jnz     @@_memtop_e801_use_cxdx      ;  CX/DX.  The spec I have read
@@_memtop_e801_use_axbx:     mov     dx,bx           ;  seems to indicate AX/BX
                jmp     @@_memtop_e801_end_kludge    ;  are more reasonable anyway...
@@_memtop_e801_use_cxdx:     mov     ax,cx
@@_memtop_e801_end_kludge:                   ;now: dx=64k units above 16m
                                ;     ax=1k units above 1m below 16m (max 3c00h)
                test    dx,dx
                jz      @@_memtop_e801_less16m
                xor     ax,ax           ;ignore info on low 16M (assume full)
               ;add     dx,100h         ;account for low 16M
                inc     dh              ;account for low 16M (optimized)
                jmp     @@_memtop_e801_ret
@@_memtop_e801_less16m:                              ;dx=0 here, ax=kbs above 1m
               ;add     ax,400h         ;account for 1024 low kb
                add     ah,4h           ;account for 1024 low kb (optimized)
                shld    dx,ax,10        ;multiply by 1024
                shl     ax,10           ;  (kbytes -> bytes)
                jmp     @@_memtop_e801_ret
@@_memtop_e801_err:
                xor     dx,dx
                xor     ax,ax
@@_memtop_e801_ret:
                pop	bx
                pop	cx
                retn


;***************************************************************
;u32 memtop_cmos()
;***************************************************************
        global  near
        _memtop_cmos:

                pushf
                cli

                mov     al,18h          ; read bytes 17-18 from CMOS
                out     070h,al
                call    @@_memtop_cmos_ret   ;io delay
                in      al,071h
                mov     ah,al           ; 18 is hi
                mov     al,17h
                call    @@_memtop_cmos_ret   ;io delay
                out     070h,al
                call    @@_memtop_cmos_ret   ;io delay
                in      al,071h         ; 17 is lo

                popf

		xor     dx,dx
               ;add     ax,400h         ;account for 1024 low kb
               ;adc     dx,0
                add     ah,4h           ;account for 1024 low kb (optimized)
                adc     dx,dx
                shld    dx,ax,10        ;multiply by 1024
                shl     ax,10           ;  (kbytes -> bytes)
@@_memtop_cmos_ret:
                retn


        end

;###### END OF FILE ############################################
