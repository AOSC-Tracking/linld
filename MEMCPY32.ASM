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
;int _is_rm32();
;****** Return: AX=2 - it is a 386+ in virtual86 mode with vcpi
;******         AX=1 - it is a 386+ in real mode
;******         AX=0 - otherwise
;****** Uses:   Flags
;***************************************************************
        global  _is_rm32:near
        proc    _is_rm32 near

                pushf
                cli
; Check for oldies
                push    sp
                pop     ax
                cmp     ax,sp
                jne     @@bad   ;it is a 86/186, not a 286+
; Check for vm
                smsw    ax      ;SMSW cannot be trapped! :-)
                test    al,1	;MSW_PE

; We're in vm, this is 386+ (there is no vm in 286)
                jnz     check_vcpi

; We're in rm, chk for 386+
                push    ds dx
                push    0
                pop     ds
                mov     ax,offset excp6
		mov	dx,cs
                xchg    [06h*4  ],ax
                xchg    [06h*4+2],dx
               ;cmp     sp,sp           ;sets ZF - already done
                xchg    eax,eax         ;triggers excp6 on 286 - clears ZF
                mov     [06h*4  ],ax
                mov     [06h*4+2],dx
                pop     dx ds
                jnz     @@bad   ;it's a 286

; It's a 386 in real mode, chk for paging (crazy but possible)
                push    eax
                mov     eax,cr0
                shl     eax,1   ;CR0_PG to CF
                pop     eax
                jc      @@bad   ;CR0_PG was set - real mode paging
@@386rm:
                mov     ax,1
                popf
                ret
@@bad:          xor     ax,ax
                popf
                ret

;***************************************************************
;****** Helper int 6 handler: clears ZF, moves IP by 2 bytes
;***************************************************************
label   excp6 near
@@oldFlags      =       (word bp+6)
@@oldCS         =       (word bp+4)
@@oldIP         =       (word bp+2)
@@oldBP         =       (word bp+0)
@@Flags_ZF      =       0040h
                push	bp
		mov	bp,sp
                add     [@@oldIP],2
                and     [byte low @@oldFlags],not @@Flags_ZF
                pop     bp
                iret

;***************************************************************
;****** Helper: checks for vcpi
;***************************************************************
label   check_vcpi near
                push    dx
                push    ds
; Check whether it is safe to call 67h (we trust only known EMM managers)
                push    0
                pop     ds
                mov     ds,[word 67h*4+2]
                cmp     [dword 10+4],'0XXX'
                jne     @@no_vcpi
                cmp     [dword 10],'XMME'
                je      @@skip
        ; this also works (as told by <J.S.Peatfield@damtp.cambridge.ac.uk>)
                cmp     [dword 10],'QMME'
                jne     @@no_vcpi
@@skip:
; Check emm manager status and version
                mov     ah,40h          ; get status
                int     67h
                test    ah,ah
                jnz     @@no_vcpi
                mov     ah,46h          ; get version
                int     67h
                test    ah,ah
                jnz     @@no_vcpi
                cmp     al,40h          ; version must be >= 4.0
                jb      @@no_vcpi
; Check vcpi manager status
              ;;mov     ax,5A01h        ; ALLOCATE RAW PAGES
              ;;mov     bx,4
              ;;int     67h
              ;;test    ah,ah
              ;;jnz     @@no_vcpi
              ;;push    dx              ;$ save handle
                mov     ax,0DE00h       ; check for vcpi present
                int     67h
                test    ah,ah
                jz      @@386vcpi
              ;;pop     dx              ;$ handle
              ;;mov     ax,4500h        ; DEALLOCATE PAGES
              ;;int     67h
@@no_vcpi:
                xor     ax,ax
                jmp     @@ret
@@386vcpi:
                mov     ax,2
@@ret:
                pop     ds
                pop     dx
                popf
                ret

        endp    _is_rm32


;***************************************************************
;void memcpy32(u16 dstseg,u32 dstofs,u16 srcseg,u32 srcofs,u32 size);
;***************************************************************
;****** Uses:   Flags
;***************************************************************
        global  _memcpy32:near
        proc    _memcpy32 near

; rm32,imm16 helper
macro   addzx_e rm,i
        db      66h
        add     rm,i
        dw      0
endm
                arg     dstseg  :word,  \
                        dstofs  :dword, \
                        srcseg  :word,  \
                        srcofs  :dword, \
                        sz      :dword  = PARAM_SIZE

                local   GDTR    :pword, \
                        oldGDTR :pword  = TEMP_SIZE

;****** Init ***************************************************
                enter   TEMP_SIZE,0
                pushf
                cli
                push    es ds eax ecx esi edi
                sgdt    [oldGDTR]

;****** Load gdtr **********************************************
                mov     eax,cs
                shl     eax,4
                addzx_e ax,<offset GDT>
                mov     [word GDTR],0FFFFh      ;GDT limit
                mov     [dword GDTR+2],eax      ;GDT base
                lgdt    [GDTR]

;****** Go into pm *********************************************
                mov     eax,cr0
                or      al,01h          ;CR0_PE on
                mov     cr0,eax
                jmp     short $+2       ;*Required*!
                                        ;3+ NOPs also work fine (chkd on 386)
;****** Move data **********************************************
                mov     cx,0008h
                mov     ds,cx           ;base=0, lim = 4gb
                mov     es,cx           ;
                movzx   esi,[srcseg]
                shl     esi,4
                add     esi,[srcofs]
                movzx   edi,[dstseg]
                shl     edi,4
                add     edi,[dstofs]
                mov     ecx,[sz]
                cld
                cmp     esi,edi
                jae     @@do_copy
                add     esi,ecx         ;src<dst: we must do
                dec     esi             ;  copy backwards to avoid
                add     edi,ecx         ;  overwrite bug
                dec     edi             ;
                std                     ;
@@do_copy:
                db      66h     ;operand width override for ecx
                db      67h     ;address width override for esi/edi
            rep movsb
                cld

;****** Return to rm *******************************************
                and     al,0feh         ;CR0_PE off
                mov     cr0,eax         ;ds/es limits are *not* reset to 64kb
                                        ;  but who cares :-)
                jmp     short $+2

;****** Return *************************************************
@@ret:          lgdt    [oldGDTR]
                pop     edi esi ecx eax ds es
                popf
                leave
                ret

;****** Const data *********************************************
                org     $-8     ;save 8 bytes - they are unused anyway
;0000: unused
GDT             dd      ?,?
;0008: Data seg [0,FFFFFFFF]
                ;       lim_lo              base_lo
                dw      1111111111111111b,  0000000000000000b
                db      00000000b,10010010b,10001111b,00000000b
                ;       base_med  P  S D A  G ??l_hi  base_hi
                ;                  Pl E W    D
        endp    _memcpy32

        ends    _TEXT

        end

;###### END OF FILE ############################################
