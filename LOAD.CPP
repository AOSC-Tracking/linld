// This file is distributed under GPL
//
// LINLD main() lives here

#include "crtl.h"
#include "common.h"

static void read_or_die(int fd, void *buf, u16 size, const char* msg=0) {
    u16 cnt = read(fd, buf, size);
    if(cnt != size) die(msg);
}

static char* read_cmdline_or_die(const char* fn, u16 maxsz, const char* msg) {
    int fd = open(fn, O_RDONLY|O_BINARY);
    if(fd == -1) die(msg);
    u32 size = lseek(fd,0,SEEK_END);
    if(s32(size)==-1L) die(msg);
    lseek(fd,0,SEEK_SET);
    if(size>=maxsz) die(msg);
    char *buf = malloc_or_die(size+1, msg); // +1 for '\0'
    read_or_die(fd, buf, size, msg);
    // Strip any trailing cr/lf
    char *p=buf+size;
    do {
        *p-- = '\0';
    } while(p>=buf && (*p=='\r' || *p=='\n'));
    // Replace all other cr/lfs with spaces
    while(p>=buf) {
        if(*p=='\r' || *p=='\n') *p=' ';
        p--;
    }
    return buf;
}

#ifdef DEBUG
// shows screen full of hearts and freeze
void hang() {
    asm {
        cli
        cld
        mov     cx,0b800h
        mov     es,cx
        xor     di,di
        mov     al,03h
        rep stosb
    }
z:  goto z;
}
#endif

// From linux kernel setup.S:
// wait until a20 really *is* enabled; it can take a fair amount of
// time on certain systems; Toshiba Tecras are known to have this
// problem.
static int check_a20() {
    volatile u8 far* addr0 = (volatile u8 far*)0x00000000L;
    volatile u8 far* addr1 = (volatile u8 far*)0xFFFF0010L;

    u16 i=0;
    int ok=0;
    while(--i) {
        cli();
        u8 sv0=*addr0;
        u8 sv1=*addr1;
        *addr0=0x55;
        *addr1=0xAA;
        barrier();
        if(*addr0==0x55) { ok=1; i=1; }
        *addr0=sv0;
        *addr1=sv1;
        sti();
    }

    return ok;
}

static u32 memtop() {
    u32 v = memtop_e801();
    if(!v) v = memtop_88();
    if(!v) v = memtop_cmos();

    // If reported mem is ridiculously low, presume
    // we had trouble detecting memory size
    if(v < 8*_1m) return 8*_1m;

    // Kernel can have trouble with initrd at very high addr:
    // limit mem top to 256m
    if(v > 0x10000000ul) return 0x10000000ul;
    return v;
}

/***************
    Memory layout assumed by kernel boot process
    --------------------------------------------
    Note: claims that kernel setup is relocatable are
    still not 100% valid:
    bzImage decompressing trashes 10000-8ffff range,
    so rm loader -> pm kernel info is lost if it was here...
    So I had to stick to 90000.

10000000+------------------------+  <- 256m
        |  initrd                |      initrd is at top of mem, but
        |                        |      not higher than 256m
        +------------------------+
        +------------------------+
        |  bzImage               |      bzImage is at 1m
        |                        |      VCPI/XMS/64k offset tricks used...
00100000+------------------------+  <- 1m
        |  video, BIOS etc       |      Do not use.
000A0000+------------------------+
        |  Reserved for BIOS     |      Do not use.  Reserved for BIOS EBDA.
0009A000+------------------------+  <- stack top for kernel rm code
        |  Cmdline               |
00098000+------------------------+  <- heap top for kernel rm code
        |  Kernel setup          |      The kernel real-mode code.
00090200+------------------------+
        |  Kernel boot sector    |      The kernel legacy boot sector.
00090000+------------------------+
        |  Zapped by ungzip      |      Historically zImages were loaded here
        | (zImage once was here) |      bzImages use this space for ungzipping
00010000+------------------------+
        |  Boot loader           |  <- Boot sector entry point 0000:7C00
00001000+------------------------+
        |  Reserved for MBR/BIOS |
00000800+------------------------+
        |  Typically used by MBR |
00000600+------------------------+
        |  BIOS use only         |
00000000+------------------------+
*/

struct first1k_t {
                            // these two set by rm setup:
    u16     curr_curs;      // 0000 saved cursor position
    u16     ext_mem_size;   // 0002 extended memory size in Kb (from int 0x15 fn 0x88)
    u8      pad00[0x20-4];
                            // old-style cmdline (not used in LINLD (yet?))
    u16     cl_magic;       // 0020 commandline magic number (=0xA33F)
    u16     cl_ofs;         // 0022 commandline offset
    u8      pad10[0x80-0x24];
                            // these two set by rm setup:
    u8      hd0_disk_par[16]; // 0080 hd0-disk-parameter from intvector 0x41
    u8      hd1_disk_par[16]; // 0090 hd1-disk-parameter from intvector 0x46
    u8      pad20[0x01e0-0xa0];
                            // this is set by rm setup:
    u32     alt_mem_size;   // 01E0 extended memory size in Kb (from int 0x15 fn 0xe801)
    u8      pad28[0x01f1-0x1e4];

    u8      setup_sects;    // 01F1 The size of the setup in sectors
                            //      boot sector is NOT included here
    u16     ro_flag;        // 01F2 If set, the root is mounted readonly
    u16     syssize;        // 01F4 DO NOT USE - for bootsect.S use only:
                            //      size of pm part of kernel
                            //      (in 16 byte units, rounded up)
    u16     swap_dev;       // 01F6 DO NOT USE - obsolete
    u16     ram_size;       // 01F8 DO NOT USE - for bootsect.S use only:
                            //      if nonzero then kernel
                            //      (driver/block/ramdisk.c: rd_load())
                            //      will try to load the contents for the ramdisk
                            //      from the "root_dev" which MUST then have the
                            //      floppyMAJOR
                            //      The file-system on that floppy must be MINIX
                            //      If rd_load() succeeds it sets the root_dev
                            //      to the ramdisk for mounting it
    u16     vid_mode;       // 01FA Video mode control
    u16     root_dev;       // 01FC Default root device number
    u16     boot_flag;      // 01FE 0xAA55 magic number
    u16     jump;           // 0200 Jump instruction
    u32     header;         // 0202 Magic signature "HdrS"
    u16     version;        // 0206 Boot protocol version supported
    u16     realmode_switch_ofs; // 0208 Hook called just before rm->pm
    u16     realmode_switch_seg;
    u32     start_sys;      // 020C Points to kernel version string
    u8      type_of_loader; // 0210 Boot loader identifier
    u8      loadflags;      // 0211 Boot protocol option flags
    u16     setup_move_size;// 0212 Move to high memory size (used with hooks)
    u32     code32_start;   // 0214 Boot loader hook (see below)
    u32     initrd_buf;     // 0218 initrd load address (set by boot loader)
    u32     initrd_size;    // 021C initrd size (set by boot loader)
    u32     bootsect_kludge;// 0220 DO NOT USE - for bootsect.S use only
    u16     heap_end_ptr;   // 0224 Free memory after setup end
    u16     pad1;           // 0226 Unused
    u32     cmd_line_ptr;   // 0228 32-bit pointer to the kernel command line
    u8      pad30[0x400-0x22c]; // 022C
                            // 02D0 up to 32 20-byte mem info structs from
                            // int 0x15 fn 0xe820
}; //__attribute((packed));

#if sizeof(first1k_t)!=0x400
#error BUG: Bad first1k
#endif

const u32 HdrS = 'H' + ('d'<<8) + (u32('r')<<16) + (u32('S')<<24);

const char* kernel_name = "bzImage";
const char* initrd_name = 0;
const char* cmdline = "auto";
u16 vid_mode = 0;       // -3 = ask
                        // -2 = Extended VGA
                        // -1 = Normal VGA
                        //  n = as "n" was pressed
u16 rm_size=0;
u8* rm_buf=0;
u32 pm_size=0;
u32 pm_buf=0;
u32 initrd_size=0;
u32 initrd_target_addr=0;
u32* pm_bufv=0;
u32 initrd_buf=0;
u32* initrd_bufv=0;

char vcpi=0;
u32 xmm_driver=0;
u32 saved15;

// Called from inside kernel just before rm->pm
// _loadds _saveregs: done by hand
static void far last_ditch() {
    cli();  // we start doing *really* destructive things to DOS/BIOS
            // it means: do not even try to enable ints
            // or call BIOS services after this
    asm {
        push    ds
        push    cs
        pop     ds
        pusha
    }
    if(vcpi==0) {
        // Move kernel
        memcpy32(
            0, _1m,         // dst seg,ofs
            0, pm_buf,      // src seg,ofs
            pm_size         // size
        );
        // Move initrd
        if(initrd_buf != initrd_target_addr) {
            memcpy32(
                0, initrd_target_addr,  // dst seg,ofs
                0, initrd_buf,          // src seg,ofs
                initrd_size             // size
            );
        }
    } else { //vcpi
        vm2rm();
        // Move kernel
        // 'Gathering' copy in chunks of PAGE_SIZE
        // No risk of overlapping: kernel is copied from above to 1m mark
        u32* p=pm_bufv;
        u32 dst=_1m;
        while(*p) {
            memcpy32(
                0, dst,         // dst seg,ofs
                0, *p++,        // src seg,ofs
                PAGE_SIZE       // size
            );
            dst+=PAGE_SIZE;
        }
        // Move initrd
        if(initrd_target_addr) {
            // This is tricky: copy initrd backwards to reduce
            // risk of overlapping: use the fact that initrd is copied
            // to the very top of ram
            // (overlapping still can happen with more than 256mb ram)
            // (generic solution for this overwrite problem, anyone?)
            p=initrd_bufv;
            dst=initrd_target_addr;
            while(*p) { p++; dst+=PAGE_SIZE; }
            do {
                p--; dst-=PAGE_SIZE;
                memcpy32(
                    0, dst,         // dst seg,ofs
                    0, *p,          // src seg,ofs
                    PAGE_SIZE       // size
                );
            } while(dst!=initrd_target_addr);
        }
    }
    asm {
        popa
        pop     ds
    }
}

static void syntax() {
    die("Syntax:" NL
        "LINLD [image=<file>] [initrd=<file>] [vga=vgamode] [cl=<kernel cmdline>]" NL
        "vgamode: ask,extended,normal or dec/oct/hex number" NL
        "Defaults:" NL
        "\timage=bzImage" NL
        "\tinitrd=(nothing)" NL
        "\tcl=auto" NL
        "\tvga=0" NL
        "Use quotes: \"cl=...\" if you need spaces in cmdline" NL
        "Use cl=@filename to take cmdline from file"
    );
}

int main() {
    // Believe it or not - this enables A20
    // on my box! Must be DOS in HMA...   -vda
    puts("LINLD v" VERSION_STR);

    switch(is_rm32()) {
        default:
            die("I need 386+ CPU in real mode or under VCPI manager");
        case R386:
#ifdef DEBUG
            puts("CPU in rm");
#endif
            xmm_driver = get_xmm_driver();
            break;
        case VCPI:
#ifdef DEBUG
            puts("CPU in vm");
#endif
            vcpi=1;
            heap_top = prepare_vcpi(malloc_or_die(8*1024+4));
            get_vcpi_interface() || die("VCPI: low 640k: need 1:1 mapping");
            break;
    }

    // C runtime lib init. TODO: zero out bss - not needed yet!

    parse_cmdline();
    int argc = _argc;
    const char** argv = _argv;

    // Parse command line

    if(argc<2) syntax();
#define STRNCMP(a,b) strncmp((a),(b),sizeof(b)-1)
    {for(int i=1;i<argc;i++) {
        if(STRNCMP(argv[i],"image=") == 0) {
            kernel_name=argv[i]+6;
        }
        else if(STRNCMP(argv[i],"initrd=") == 0) {
            initrd_name=argv[i]+7;
        }
        else if(STRNCMP(argv[i],"cl=@") == 0) {
            cmdline=read_cmdline_or_die(argv[i]+4,PAGE_SIZE-1,"Error reading cl=@file");
            puts("Kernel command line:");
            puts(cmdline);
        }
        else if(STRNCMP(argv[i],"cl=") == 0) {
            cmdline=argv[i]+3;
        }
        else if(strcmp(argv[i],"vga=ask") == 0) {
            vid_mode = -3;
        }
        else if(strcmp(argv[i],"vga=extended") == 0) {
            vid_mode = -2;
        }
        else if(strcmp(argv[i],"vga=normal") == 0) {
            vid_mode = -1;
        }
        else if(STRNCMP(argv[i],"vga=") == 0) {
            vid_mode = strtoul(argv[i]+4);
        }
        else
            syntax();
    }}
#undef STRNCMP

    // Check and enable A20 if needed

    if(!check_a20()) {
        enable_a20_fast(); //puts("A20 fast");
        if(!check_a20()) {
            enable_a20_kbd(); //puts("A20 kbd");
            if(!check_a20()) {
                if(xmm_driver) {
                    enable_a20_xmm(xmm_driver); //puts("A20 xmm");
                }
                if(!check_a20()) die("Can't enable A20");
            }
        }
    }

    // Open kernel, read first kb, check it

    rm_buf = malloc_or_die(_32k, "Can't allocate rm buf");
    // Do not use malloc below until heap_top adjustment (see <*>)
    int fd = open(kernel_name, O_RDONLY|O_BINARY);
    if(fd == -1) die("Can't open kernel file");
    u32 image_size = lseek(fd,0,SEEK_END);
    if(s32(image_size)==-1L) die("Can't seek kernel file");
    lseek(fd,0,SEEK_SET);
    read_or_die(fd, rm_buf, 0x400, "Can't read first kb");

    struct first1k_t* first1k = (first1k_t*)rm_buf;
    // new kernels never need: if(!first1k->setup_sects) first1k->setup_sects=4;
    rm_size = 0x200*(first1k->setup_sects+1); // 0th sector is not counted there
    if(rm_size>_32k)
        die("rm_size is too big");
    heap_top = rm_buf+rm_size;  // <*>

    if(first1k->boot_flag != 0xAA55)
        die("No boot signature (55,AA). It's not a kernel");
    if(first1k->header != HdrS)
        die("No 'HdrS' signature (kernel is too old)");
    if(first1k->version < 0x202)
        die("Loader protocol version is less than 2.02 (kernel is too old)");
    if(!(first1k->loadflags & 0x01))
        die("I can't load bzImages low");

    // Read remaining rm loader

    read_or_die(fd, rm_buf+0x400, rm_size-0x400, "Can't read rm loader");

    // Tell rm loader some info

    first1k->vid_mode = vid_mode;
    first1k->cmd_line_ptr = 0x98000;
    first1k->type_of_loader = 0xff; // kernel do not know us (yet :-)
    // * will be called just before rm -> pm
    first1k->realmode_switch_ofs = ofs(last_ditch);
    first1k->realmode_switch_seg = seg(last_ditch);
    // * offset limit of the setup heap
    //   heap_end_ptr appears to be relative to the start of setup (ofs 0x0200)
    first1k->heap_end_ptr = _32k-0x0200;
    first1k->loadflags |= 0x80; // says to rm loader it's ok to use heap
    // * if we will ever stop moving ourself to 0x90000
    //   we must say setup.S how much to move
    //first1k->setup_move_size = _32k;

    // Read remaining kernel (pm part)
    // Try to load kernel high, maybe even blindly storing it
    // in unallocated memory as a last resort

    u16 xfer_size = _16k;
    u8* xfer_buf = malloc_or_die(xfer_size, "Can't allocate xfer buf");
    pm_size = image_size-rm_size;
  //// assume 2:1 decompression ratio
  //if(_1m+pm_size*2 > memtop()) {
  //    die("Low memory: kernel may not fit into high mem")
  //}
    if(vcpi==0) {
        pm_buf = malloc_himem(pm_size, _1m+_64k);
        read2himem(fd, pm_buf, pm_size, xfer_buf, xfer_size);
    } else {
        pm_bufv = malloc_vcpi(pm_size);
        read2vcpi(fd, pm_bufv, pm_size, xfer_buf, xfer_size);
    }

    // Read initrd if needed

    if(initrd_name) {
        int fd = open(initrd_name, O_RDONLY|O_BINARY);
        if(fd == -1) die("Can't open initrd file");
        initrd_size = lseek(fd,0,SEEK_END);
        if(s32(initrd_size)==-1L) die("Can't seek initrd file");
        lseek(fd,0,SEEK_SET);
        initrd_target_addr = (memtop()-initrd_size) & (~PAGE_MASK);
      //not needed: kernel detects this and drops initrd
      //// assume 2:1 decompression ratio
      //if(_1m+pm_size*2 > initrd_target_addr) {
      //    die("Low memory: kernel may overlap with initrd")
      //}
        if(vcpi==0) {
            initrd_buf = malloc_himem(initrd_size, initrd_target_addr);
            read2himem(fd, initrd_buf, initrd_size, xfer_buf, xfer_size);
        } else {
            initrd_bufv = malloc_vcpi(initrd_size);
            read2vcpi(fd, initrd_bufv, initrd_size, xfer_buf, xfer_size);
        }
        first1k->initrd_buf  = initrd_target_addr;
        first1k->initrd_size = initrd_size;
    }

    // Shrink stack: we won't need much of it now and have no malloc() plans
    // BTW: bc31 don't have any clue what is 'common subexpression elimination'
    // (bad idea, can trash cmdline: _SP=0x100;)
    if(_SP>u16(heap_top)+0x100) _SP=u16(heap_top)+0x100;
    if( u16(_CS)+(u16(_SP)>>4) >= 0x9000 ) {
        // Oops! We can stomp on our toes... better stop now
        die("Loaded too close to 9000:0");
    }

#ifdef DEBUG
    // Replace int 3 vector: you can place int 3 (0xCC)
    // into rm loader to track how far it gets...

    ((u32 far*)0) [3] = (u32)hang;
#endif

    cli(); // we start doing destructive things to DOS

    // Hook on int15 to work around fn 88 DOS breakage
    saved15 = ((u32 far*)0) [0x15];
    ((u32 far*)0) [0x15] = (u32)(void far*)int15_88;

    // Move rm loader & commandline to 0x90000
    if(vcpi==0) {
        memcpy32(
            0x9000,0,
            seg(rm_buf),ofs(rm_buf),
            rm_size //_32k
        );
        memcpy32(
            0x9800,0,
            seg(cmdline),ofs(cmdline),
            strlen(cmdline)+1
        );
    } else { //vcpi
        u32 dst=0x90000;
        u16 pos=ofs(rm_buf);
        u16 cnt=(rm_size+PAGE_SIZE-1)/PAGE_SIZE;
        while(cnt--) {
            memcpy_vcpi(dst,seg(rm_buf),pos);
            dst+=PAGE_SIZE;
            pos+=PAGE_SIZE;
        }
        // overkill: copy PAGE_SIZE bytes
        memcpy_vcpi(0x98000,seg(cmdline),ofs(cmdline));
    }

    // Jump to kernel rm code
    set_sregs_jump_seg_ofs(
        0x9000,     //sregs
        0xA000,     //sp
        0x9020,0    //cs,ip
    );

    // Let compiler be happy
    return 0;
}
