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
;u32 memtop_88()
;***************************************************************
        global  _memtop_88:near
        proc    _memtop_88 near

                mov     ah,88h
                int     15h             ;ax=kbs above 1m
                jnc     @@ok            ;  error: cf=1 or ax=0
                xor     ax,ax           ;
@@ok:
                xor     dx,dx
                test    ax,ax           ;happens on big mem systems
                jz      @@ret
               ;add     ax,400h         ;account for 1024 low kb
               ;adc     dx,0
                add     ah,4h           ;account for 1024 low kb
                adc     dx,dx           ;  (optimized to death)
                shld    dx,ax,10        ;multiply by 1024
                shl     ax,10           ;  (kbytes -> bytes)
@@ret:
                ret
        endp    _memtop_88


;***************************************************************
;u32 memtop_e801()
;***************************************************************
        global  _memtop_e801:near
        proc    _memtop_e801 near

                push    cx bx
                stc                     ;fix to work around buggy
                xor     cx,cx           ;  BIOSes which dont clear/set
                xor     dx,dx           ;  carry on pass/error of
                mov     ax,0E801h
                int     15h
                jc      @@err
                test    cx,cx           ;kludge to handle BIOSes
                jnz     @@use_cxdx      ;  which report their extended
                test    dx,dx           ;  memory in AX/BX rather than
                jnz     @@use_cxdx      ;  CX/DX.  The spec I have read
@@use_axbx:     mov     dx,bx           ;  seems to indicate AX/BX
                jmp     @@end_kludge    ;  are more reasonable anyway...
@@use_cxdx:     mov     ax,cx
@@end_kludge:                   ;now: dx=64k units above 16m
                                ;     ax=1k units above 1m below 16m (max 3c00h)
                test    dx,dx
                jz      @@less16m
                xor     ax,ax           ;ignore info on low 16M (assume full)
               ;add     dx,100h         ;account for low 16M
                inc     dh              ;account for low 16M (optimized)
                jmp     @@ret
@@less16m:                              ;dx=0 here, ax=kbs above 1m
               ;add     ax,400h         ;account for 1024 low kb
                add     ah,4h           ;account for 1024 low kb (optimized)
                shld    dx,ax,10        ;multiply by 1024
                shl     ax,10           ;  (kbytes -> bytes)
                jmp     @@ret
@@err:
                xor     dx,dx
                xor     ax,ax
@@ret:
                pop     bx cx
                ret
        endp    _memtop_e801


;***************************************************************
;u32 memtop_cmos()
;***************************************************************
        global  _memtop_cmos:near
        proc    _memtop_cmos near

                pushf
                cli

                mov     al,18h          ; read bytes 17-18 from CMOS
                out     070h,al
                call    @@ret   ;io delay
                in      al,071h
                mov     ah,al           ; 18 is hi
                mov     al,17h
                call    @@ret   ;io delay
                out     070h,al
                call    @@ret   ;io delay
                in      al,071h         ; 17 is lo

                popf

		xor     dx,dx
               ;add     ax,400h         ;account for 1024 low kb
               ;adc     dx,0
                add     ah,4h           ;account for 1024 low kb (optimized)
                adc     dx,dx
                shld    dx,ax,10        ;multiply by 1024
                shl     ax,10           ;  (kbytes -> bytes)
@@ret:
                ret
        endp    _memtop_cmos

        ends    _TEXT

        end

;###### END OF FILE ############################################
