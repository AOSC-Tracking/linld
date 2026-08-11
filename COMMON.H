// This file is distributed under GPL
//
// Common defs not belonging to CRTL

#define NL "\r\n"
#define VERSION_STR "0.97"

#if 0       // DEBUG
 #undef  NDEBUG
 #define DEBUG
 #define static
#else       // not DEBUG
 #define NDEBUG
 #undef  DEBUG
#endif

typedef unsigned long  u32; typedef signed long  s32;
typedef unsigned short u16; typedef signed short s16;
typedef unsigned char  u8;  typedef signed char  s8;

const u16 _16k = 16*1024u;
const u16 _32k = 32*1024u;
const u32 _64k = 64*1024ul;
const u32 _1m = 1024ul*1024ul;

const unsigned PAGE_BITS = 12;
const unsigned PAGE_SIZE = 1<<PAGE_BITS;
const unsigned PAGE_MASK = PAGE_SIZE-1;

// WARNING!
// BC 3.1 bug: seg() will generate incorrect code if inlined!
// replaced by _dirty_ hack for now
// u16 seg(const void far* p) { return FP_SEG(p); }
#ifdef __WATCOMC__
inline u16 seg(const void far* p) { return (unsigned)p; }
#else
inline u16 seg(const void far*) { return _DS; }
#endif

#ifdef __WATCOMC__
u16 GetSP();
#pragma aux GetSP = value[sp] modify[];
#else
u16 GetSP() { return _SP; }
#endif

#ifdef __WATCOMC__
void SetSP(u16 new_sp);
#pragma aux SetSP = "mov sp, ax" modify[] parm[ax];
#else
inline void SetSP(u16 new_sp) { _SP = new_sp; }
#endif

#ifdef __WATCOMC__
u16 GetCS(void);
#pragma aux GetCS = "mov ax, cs" value[ax] modify[ax];
#else
inline u16 GetCS(void) { return _CS; }
#endif

inline u16 ofs(const void far* p) { return FP_OFF(p); }

// External asm helpers
enum { BAD, R386, VCPI };
extern "C" int __cdecl is_rm32();
extern "C" void __cdecl memcpy32(u16,u32, u16,u32, u32);
extern "C" void set_sregs_jump_seg_ofs(u16 sr, u16 sp, u16 seg, u16 ofs);
extern u32 xmm_driver;
extern "C" u32 __cdecl get_xmm_driver();
extern "C" u32 __cdecl xmm_alloc(u32 drv, u32 size);
extern "C" u32 __cdecl memtop_e801();
extern "C" u32 __cdecl memtop_88();
extern "C" u32 __cdecl memtop_cmos();
extern "C" void __cdecl enable_a20_fast();
extern "C" void __cdecl enable_a20_kbd();
extern "C" void __cdecl enable_a20_xmm(u32 drv);
extern "C" int __cdecl get_vcpi_interface();
extern "C" char* __cdecl prepare_vcpi(void *pagebuf);
//extern "C" int call_pm_routine(void* f);
extern "C" void __cdecl memcpy_vcpi(u32 dstofs,u16 srcseg,u16 srcofs);
extern "C" void __cdecl vm2rm();
extern "C" void int15_88();

// C++ helpers
#ifdef DEBUG
extern "C" void hang();
#endif

u32 malloc_himem(u32 size, u32 fallback);
void read2himem(int fd, u32 high_ofs, u32 size, void* xfer_buf, u16 xfer_size);

u32* malloc_vcpi(u32 size);
void read2vcpi(int fd, u32* vp, u32 size, void* xfer_buf, u16 xfer_size);
