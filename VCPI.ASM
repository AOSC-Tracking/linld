;***************************************************************
;****** This file is distributed under GPL
;***************************************************************
;VDPI init:
;Call  char* prepare_vcpi(void *pagebuf)  first to
;initialize paging tables needed for vm86.
;pagebuf needs to be 8k+4 bytes. Returns ptr to 1st unused byte.
;Then call  int get_vcpi_interface().  Returns 1 if ok, 0 if bad.
;
;VCPI use:
;u32* malloc_vcpi(u32 size)  - source in HIMEM.CPP
;  Returns ptr to mallocated zero-terminated list of 4k page addrs
;  Addresses are sorted in ascending order
;  Never fails (will die if not enough mem)
;void read2vcpi(int fd, u32* vp, u32 size,
;void* xfer_buf, u16 xfer_size)  - source in HIMEM.CPP
;  Reads opened fd data into malloc_vcpi'ed memory
;  Dies if file isn't exactly 'size' bytes long
;  Needs intermediate buffer of exactly Nx4k bytes
;void memcpy_vcpi(u32 dstofs,u16 srcseg,u16 srcofs)
;  copies 4k from conventional memory to VCPI
;void _vm2rm()
;  switches you from vm86 to plain real mode


                CPU	386

;****** Stuff for declaring descriptors
struc	descr
.limit:	resw	1
.base0:	resw	1
.base16:	resb	1
.type:	resb	1
.limit16:	resb	1
.base24:	resb	1
endstruc	;    descr
%MACRO  descriptor      7
%1:
  istruc descr
    at .limit,   dw (%5 & 0ffffh)
    at .base0,   dw %7
    at .base16,  db 0
    at .type,    db (%2 | %3 | %4)
    at .limit16, db ((%5 >> 16) | %6)
    at .base24,  db 0
  iend
%ENDMACRO
; decriptor types (bit0..4 of descr.type )
tss386_avail	EQU	09h
data_seg	EQU	00010000b   ; data segment
  expand_down	EQU	00000100b   ; =1 limit counts down from base
  writable	EQU	00000010b   ; =1 if write access allowed to data segment
code_seg	EQU	00011000b   ; code segment
  conforming	EQU	00000100b   ; =1 code can be accesses and executed at any PL
  readable	EQU	00000010b   ; =1 if code also can be read (cannot be ovwritten)
; privilege levels (bit5..6 of descr.type )
priv0	EQU	00000000b
priv1	EQU	00100000b
priv2	EQU	01000000b
priv3	EQU	01100000b
; segment present bit (bit7 of descr.type )
is_present	EQU	10000000b
not_present	EQU	00000000b
;definition of granularity ( bits6..7 in descr.limit16 )
gran_byte	EQU	00000000b
gran_page	EQU	10000000b  ; 4k granularity
use_16	EQU	00000000b
use_32	EQU	01000000b

;****** rm32,imm16 helpers
%MACRO	movzx_e	2
%DEFINE	%%rm	%1
%DEFINE	%%i	%2
        db      66h
        mov     %%rm,%%i
        dw      0
%ENDMACRO
%MACRO	addzx_e	2
%DEFINE	%%rm	%1
%DEFINE	%%i	%2
        db      66h
        add     %%rm,%%i
        dw      0
%ENDMACRO


        group   DGROUP  _TEXT _DATA

        SEGMENT	_DATA	ALIGN=1	public	use16	CLASS=DATA

tss             dd      0,0     ;enough, we'll never use it anyway

gdt:
gdt_null:     ;0000
istruc	descr
	dw	?
iend
gdt_vcpi:     ;0008
istruc	descr
	dw	?
iend
gdt_vcpi2:     ;0010
istruc	descr
	dw	?
iend
gdt_vcpi3:     ;0018
istruc	descr
	dw	?
iend
descriptor      gdt_abs ,(data_seg+writable),priv0,is_present,0fffffh,(gran_page+use_32),0
;Note: code/data segs must be flagged use16 (i.e. use ip/sp, not eip/esp)
;Note: base addrs will be fixed up in prepare_vcpi()
descriptor      gdt_code,(code_seg+readable),priv0,is_present,0fffffh,(gran_page+use_16),0
descriptor      gdt_data,(data_seg+writable),priv0,is_present,0fffffh,(gran_page+use_16),0
descriptor      gdt_tss ,tss386_avail       ,priv0,is_present,0ffh   ,gran_byte         ,tss
%DEFINE	SEL_VCPI	(gdt_vcpi - gdt_null)
%DEFINE	SEL_TSS	(gdt_tss  - gdt_null)
%DEFINE	SEL_ABS	(gdt_abs  - gdt_null)
%DEFINE	SEL_CODE	(gdt_code - gdt_null)
%DEFINE	SEL_DATA	(gdt_data - gdt_null)

gdtr:
gdt_lim         dw      0ffffh
gdt_base        dw      gdt,0
idtr:
idt_lim         dw      03ffh   ;we won't enable ints,
idt_base        dd      0       ;  so let's leave it the same as for rm

;Note: layout dictated by vcpi api, don't rearrange!
sw2pm_params:
;Note: base addrs will be fixed up in prepare_vcpi()
sw2pm_cr3       resd	1
sw2pm_gdtr_ptr  dw      gdtr,0
sw2pm_idtr_ptr  dw      idtr,0
sw2pm_ldtr      dw      0       ;we don't need it
sw2pm_tr        dw      SEL_TSS ;vcpi thinks we need it... can't set to 0
sw2pm_jumpaddr  resd	1
                dw      SEL_CODE

;Pagedir/page0 addrs: linear, seg:0 and cs:ofs
pagedir_laddr   resd	1
page0_laddr     resd	1
;;pagedir_seg     dw      ?
;;page0_seg       dw      ?
pagedir_ofs     resw	1
page0_ofs       resw	1

vcpi_pm_entry   resd	1
                dw      SEL_VCPI

saved_ss_sp:
saved_sp        resw	1
saved_ss        resw	1




        SEGMENT	_TEXT	ALIGN=1	public	use16	CLASS=CODE

;***************************************************************
;char* prepare_vcpi(void *pagebuf);
;****** Return: AX=>first unused byte in pagebuf
;****** Uses:   Flags
;***************************************************************
        global  _prepare_vcpi
        _prepare_vcpi:

                %arg    pgbuf:word   = PARAM_SIZE

                push    bp
                mov     bp,sp
                push	es
                push	eax
                push	ebx

                mov     ebx,cs
                shl     ebx,4           ;ebx = linear addr of CS

;Calculate pagedir/page0 addrs, initialize cr3 and pagedir[0]
                movzx   eax,[WORD pgbuf]
                add     eax,ebx
                add     eax,0FFFh
                and     ax,0F000h   ;eax = 4k aligned linear addr of pagebuf
                mov     [page0_laddr],eax
                add     eax,1000h
                mov     [pagedir_laddr],eax
                        ;page directory will use only one entry (4 bytes):
                        ;cr3 => pagedir => page0  => ########
                        ;      (1 entry)  (1024   => #  4M  #
                        ;                 entries)=> # page #
                        ;                         => ########
                mov     [sw2pm_cr3],eax
                sub     eax,ebx         ;ax = offset in CS of pagedir
                mov     [pagedir_ofs],ax
                sub     ah,10h  ;ax-=1000
                mov     [page0_ofs],ax
                mov     eax,[page0_laddr] ;;
              ;;mov     eax,[pagedir_laddr]
                shr     eax,4
              ;;mov     [pagedir_seg],ax
              ;;dec     ah      ;ax-=0100
              ;;mov     [page0_seg],ax

                mov     es,ax           ;es:0->page0,es:1000h->pagedir
                shl     eax,4           ;eax=page0 linear addr
                mov     al,3            ;add present+writable bits
                mov     [es:1000h],eax  ;stuff it into pagedir[0]

; Fix up base of some gdt descriptors
; Note: 'add [dword xx.base0],ebx' actually updates 24 bit quantity!
; Do NOT replace with mov!
                add     [dword gdt_base],ebx
                add     [dword sw2pm_gdtr_ptr],ebx
                add     [dword sw2pm_idtr_ptr],ebx
                add     [dword gdt_code + descr.base0],ebx ; [dword gdt_code.base0]
                add     [dword gdt_data + descr.base0],ebx ; [dword gdt_data.base0]
                add     [dword gdt_tss  + descr.base0],ebx ; [dword gdt_tss.base0]
; Return
                pop	ebx
                pop	eax
                pop	es
                mov     ax,[pagedir_ofs]
                add     ax,4
                pop     bp
                retn


;***************************************************************
;int get_vcpi_interface();
;****** Return: AX=1 - page mapping for low 640k is 1:1
;******         AX=0 - otherwise (it's bad)
;****** Uses:   Flags
;***************************************************************
        global  _get_vcpi_interface
        _get_vcpi_interface:

                push	ebx
                push	si
                push	di

; Get and save VCPI pm interface
                mov     si,gdt_vcpi      ;DS:DI => 3 GDT entries for VCPI
                mov     di,[page0_ofs]          ;ES:DI => page0
                mov     ax,0DE01h               ;get vcpi pm interface
                int     67h
                mov     [vcpi_pm_entry],ebx

; Check that mapping for low 640k is 1:1
                mov     si,[page0_ofs]
                xor     bx,bx
                cld
@@_get_vcpi_interface_map_chk:
                lodsd
                shr     eax,12
                cmp     ax,bx
                jne     @@_get_vcpi_interface_bad
                inc     bx
                cmp     ax,((640*1024) >> 12)-1
                jne     @@_get_vcpi_interface_map_chk
; Return
@@_get_vcpi_interface_ok:
                mov     ax,1
                jmp     @@_get_vcpi_interface_ret
@@_get_vcpi_interface_bad:
                xor     ax,ax
@@_get_vcpi_interface_ret:
                pop	di
                pop	si
                pop	ebx
                retn


;***************************************************************
;void memcpy_vcpi(u32 dstofs,u16 srcseg,u16 srcofs);
;***************************************************************
;****** Copies PAGE_SIZE bytes
;****** Uses:   Flags
;***************************************************************
        global  _memcpy_vcpi
        _memcpy_vcpi:

              %arg    dstofs:dword, \
                      srcseg:word,  \
                      srcofs:word   = PARAM_SIZE

                push    bp
                mov     bp,sp

; Note: bp points to std stack frame now. bp will be passed to
; pm routine. This allows params to be passed on stack
                pushad
                push    do_memcpy_vcpi
                call    call_pm_routine ; Call pm copy routine via vcpi pm
                pop     ax
                popad

                pop     bp
                retn

struc	pm_regs
.$$retaddr:	resw	1
.$$f:	resw	1
.$$edi:	resd	1
.$$esi:	resd	1
.$$ebp:	resd	1
.$$esp:	resd	1
.$$ebx:	resd	1
.$$edx:	resd	1
.$$ecx:	resd	1
.$$eax:	resd	1
endstruc

;***************************************************************
;****** Helper: goes into 16bit pm and calls routine (addr on stk)
;***************************************************************
call_pm_routine:
                mov     bp,sp           ; ss:bp => struct pm_regs

                xor     ax,ax           ; IRET stack for return to vm
                push	ax           ;   (9 dwords)
                push	gs
                push	ax           ;
                push	fs
                push	ax           ;
                push	ds
                push	ax           ;
                push	es
                push	ax           ;
                push	ss
                push    ebp             ; esp
                pushfd                  ; eflags: IF saved here
                push	ax           ;
                push	cs
                push    ax              ;\eip
                push    @@_memcpy_vcpi_vm_ret ;/

                cli
              ;;mov     [saved_xx],xx   ;use if your vcpi trashes bp/etc

                movzx_e word [sw2pm_jumpaddr],@@_memcpy_vcpi_pm_entry
               ;mov     [word sw2pm_jumpaddr+4],SEL_CODE
                mov     esi,cs
                shl     esi,4
                addzx_e si,sw2pm_params
                mov     ax,0DE0Ch       ; vcpi: switch to pm
                int     67h
@@_memcpy_vcpi_pm_entry:
; Now we are in 16-bit protected mode
                mov     ax,SEL_DATA
                mov     ss,ax
              ;;mov     ds,ax
              ;;mov     es,ax
              ;;mov     fs,ax
              ;;mov     gs,ax

              ;;mov     xx,[saved_xx]   ;use if your vcpi trashes bp/etc
                lea     sp,[bp-9*4]     ;else we can do this trick with bp

; Call the routine (bp points to params on stack if any)
                mov     ax,[bp + pm_regs.$$f]   ; ss:bp => struct pm_regs
                mov     bp,word [bp + pm_regs.$$ebp]    ;ss:bp => params
                call    ax

; Ok, let's return to vm
                cli     ; to be safe
                clts    ;
                push    SEL_ABS         ; vcpi wants ds=all_addrspace
                pop     ds              ;
                mov     ax,0DE0Ch       ; maybe we need whole eax?
                call far [cs:vcpi_pm_entry]
@@_memcpy_vcpi_vm_ret:
; Now we are in vm86 mode. Sregs, esp, eflags (IF) restored from IRET stack
                retn

;***************************************************************
;****** Helper: This is where real copy is done
;***************************************************************
do_memcpy_vcpi:

; Note: ss:bp => params
; Move data
                mov     cx,SEL_ABS
                mov     ds,cx
                mov     es,cx

        ; Set up target addr:
        ; replace page mapping for page at 0 so
        ; that it points to dstofs
                mov     esi,[cs:page0_laddr]
                mov     eax,[dstofs]
                mov     al,03h          ; writeable, present
                xchg    [esi],eax       ; replace page0[0]
               ;push    eax             ;X we'll need to restore mapping...
                mov     ecx,cr3         ; reload TLB cache
                mov     cr3,ecx         ;
                xor     edi,edi         ;es:edi => remapped page

        ; Set up source addr
                movzx   esi,WORD [srcseg]
                shl     esi,4
                movzx   ecx,WORD [srcofs]
                add     esi,ecx

        ; Do copying
                mov     cx,4096/2
                cld
;;              cmp     esi,edi
;;              jae     @@do_copy
;;              add     esi,ecx         ;src<dst: we must do
;;              dec     esi             ;  copy backwards to avoid
;;              add     edi,ecx         ;  overwrite bug
;;              dec     edi             ;
;;              std                     ;
;;@@do_copy:
                db      67h     ;address width override for esi/edi
            rep movsw
;;              cld

        ; Restore page mapping for page at 0
               ;pop     eax             ;X
                mov     esi,[cs:page0_laddr]
                mov     [esi],eax       ; restore page0[0]
                mov     ecx,cr3         ; reload TLB cache
                mov     cr3,ecx         ;
; Return
@@_memcpy_vcpi_ret:          retn



;***************************************************************
;void _vm2rm();
;***************************************************************
;****** Uses:   Flags
;***************************************************************
        global  _vm2rm
        _vm2rm:

              ;;pushf
              ;;cli
              ;;pushad
                push    cs      ;*
                push    ds
                mov     [saved_ss],ss
                mov     [saved_sp],sp

                movzx_e word [sw2pm_jumpaddr],@@_vm2rm_pm_entry
               ;mov     [word sw2pm_jumpaddr+4],SEL_CODE
                mov     esi,cs
                shl     esi,4
                addzx_e si,sw2pm_params
                mov     ax,0DE0Ch       ; vcpi: switch to pm
                int     67h
; Now we are in 16-bit protected mode
@@_vm2rm_pm_entry:
                mov     ax,SEL_DATA     ; load data sregs with limit >=64k
                mov     ds,ax           ;   or you may get limit violations
                mov     ss,ax           ;   later in rm
                mov     es,ax           ;   (actually I prefer 4gig limits :-)
                mov     fs,ax           ;
                mov     gs,ax           ;

; Black magic here
                mov     eax,cr0
                and     eax,7ffffffeh   ; clear PG,P bits
                mov     cr0,eax         ; look mommy, we're in rm now!
              ;;jmp     short $+2
              ;;xor     eax,eax
                mov     cr3,eax         ; flush TLB cache

; Now we are in rm, but not yet: have to restore sregs:
                lss     sp,[saved_ss_sp]; SS
                pop     ds              ; DS
               ;push    cs      ;* done earlier
                push    @@_vm2rm_next
                retf                    ; CS
@@_vm2rm_next:
              ;;popad
              ;;popf
                retn             ; We don't care much about rest (ES/FS/GS)


        end

;###### END OF FILE ############################################
