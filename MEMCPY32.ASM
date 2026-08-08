;***************************************************************
;****** This file is distributed under GPL
;***************************************************************
                CPU	386

        group   DGROUP  _TEXT

        SEGMENT	_TEXT	ALIGN=1	public	use16	CLASS=CODE

;***************************************************************
;int _is_rm32();
;****** Return: AX=2 - it is a 386+ in virtual86 mode with vcpi
;******         AX=1 - it is a 386+ in real mode
;******         AX=0 - otherwise
;****** Uses:   Flags
;***************************************************************
        global  near
        _is_rm32:

                pushf
                cli
; Check for oldies
                push    sp
                pop     ax
                cmp     ax,sp
                jne     @@_is_rm32_bad   ;it is a 86/186, not a 286+
; Check for vm
                smsw    ax      ;SMSW cannot be trapped! :-)
                test    al,1	;MSW_PE

; We're in vm, this is 386+ (there is no vm in 286)
                jnz     check_vcpi

; We're in rm, chk for 386+
                push	ds
                push	dx
                push    WORD 0
                pop     ds
                mov     ax,excp6
		mov	dx,cs
                xchg    [06h*4  ],ax
                xchg    [06h*4+2],dx
               ;cmp     sp,sp           ;sets ZF - already done
                xchg    eax,eax         ;triggers excp6 on 286 - clears ZF
                mov     [06h*4  ],ax
                mov     [06h*4+2],dx
                pop	dx
                pop	ds
                jnz     @@_is_rm32_bad   ;it's a 286

; It's a 386 in real mode, chk for paging (crazy but possible)
                push    eax
                mov     eax,cr0
                shl     eax,1   ;CR0_PG to CF
                pop     eax
                jc      @@_is_rm32_bad   ;CR0_PG was set - real mode paging
@@_is_rm32_386rm:
                mov     ax,1
                popf
                retn
@@_is_rm32_bad:          xor     ax,ax
                popf
                retn

;***************************************************************
;****** Helper int 6 handler: clears ZF, moves IP by 2 bytes
;***************************************************************
excp6:
%DEFINE	oldFlags	(bp+6)
%DEFINE	oldCS	(bp+4)
%DEFINE	oldIP	(bp+2)
%DEFINE	oldBP	(bp+0)
Flags_ZF	EQU	0040h
                push	bp
		mov	bp,sp
                add     word [oldIP],2
                and     byte [oldFlags],~Flags_ZF
                pop     bp
                iret

;***************************************************************
;****** Helper: checks for vcpi
;***************************************************************
check_vcpi:
                push    dx
                push    ds
; Check whether it is safe to call 67h (we trust only known EMM managers)
                push    WORD 0
                pop     ds
                mov     ds,word [67h*4+2]
                cmp     dword [10+4],'0XXX'
                jne     @@_is_rm32_no_vcpi
                cmp     dword [10],'XMME'
                je      @@_is_rm32_skip
        ; this also works (as told by <J.S.Peatfield@damtp.cambridge.ac.uk>)
                cmp     dword [10],'QMME'
                jne     @@_is_rm32_no_vcpi
@@_is_rm32_skip:
; Check emm manager status and version
                mov     ah,40h          ; get status
                int     67h
                test    ah,ah
                jnz     @@_is_rm32_no_vcpi
                mov     ah,46h          ; get version
                int     67h
                test    ah,ah
                jnz     @@_is_rm32_no_vcpi
                cmp     al,40h          ; version must be >= 4.0
                jb      @@_is_rm32_no_vcpi
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
                jz      @@_is_rm32_386vcpi
              ;;pop     dx              ;$ handle
              ;;mov     ax,4500h        ; DEALLOCATE PAGES
              ;;int     67h
@@_is_rm32_no_vcpi:
                xor     ax,ax
                jmp     @@_is_rm32_ret
@@_is_rm32_386vcpi:
                mov     ax,2
@@_is_rm32_ret:
                pop     ds
                pop     dx
                popf
                retn



;***************************************************************
;void memcpy32(u16 dstseg,u32 dstofs,u16 srcseg,u32 srcofs,u32 size);
;***************************************************************
;****** Uses:   Flags
;***************************************************************
        global  near
        _memcpy32:

; rm32,imm16 helper
%MACRO	addzx_e	2-*
%DEFINE	%%rm	%1
%DEFINE	%%i	%2
        db      66h
        add     %%rm,%%i
        dw      0
%ENDMACRO

     %push   memcpy32_ctx                 ; save preprocessor context
     %stacksize flat                      ; 32-bit near call, use EBP
                %arg    dstseg:word,  \
                        dstofs:dword, \
                        srcseg:word,  \
                        srcofs:dword, \
                        sz:dword  = PARAM_SIZE
                %assign %$localsize 0
                %local   GDTR:word, GDTR_base:dword, oldGDTR:word, oldGDTR_base:dword

;****** Init ***************************************************
                enter   %$localsize,0
                pushf
                cli
                push	es
                push	ds
                push	eax
                push	ecx
                push	esi
                push	edi
                sgdt    [oldGDTR]

;****** Load gdtr **********************************************
                mov     eax,cs
                shl     eax,4
                addzx_e ax,GDT
                mov     word [GDTR],0FFFFh      ;GDT limit
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
                movzx   esi,word [srcseg]
                shl     esi,4
                add     esi,dword [srcofs]
                movzx   edi,word [dstseg]
                shl     edi,4
                add     edi,dword [dstofs]
                mov     ecx,dword [sz]
                cld
                cmp     esi,edi
                jae     @@_memcpy32_do_copy
                add     esi,ecx         ;src<dst: we must do
                dec     esi             ;  copy backwards to avoid
                add     edi,ecx         ;  overwrite bug
                dec     edi             ;
                std                     ;
@@_memcpy32_do_copy:
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
@@_memcpy32_ret:          lgdt    [oldGDTR]
                pop	edi
                pop	esi
                pop	ecx
                pop	eax
                pop	ds
                pop	es
                popf
                leave
                retn
%pop

;****** Const data *********************************************
align 8
;                org     $-8     ;save 8 bytes - they are unused anyway
;0000: unused
GDT             resd	1
;0008: Data seg [0,FFFFFFFF]
                ;       lim_lo              base_lo
                dw      1111111111111111b,  0000000000000000b
                db      00000000b,10010010b,10001111b,00000000b
                ;       base_med  P  S D A  G ??l_hi  base_hi
                ;                  Pl E W    D


        end

;###### END OF FILE ############################################
