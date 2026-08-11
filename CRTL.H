// This file is distributed under GPL
//
// Bare bones of C runtime library

#define asm _asm

#ifdef __WATCOMC__
#include <i86.h>
#else
#define MK_FP(seg,ofs) ((void _seg *)(seg) + (void near *)(ofs))
#define FP_SEG(fp)     ((unsigned) (void _seg*) (void far*)(fp))
#define FP_OFF(fp)     ((unsigned) (fp))
#endif

const unsigned MIN_STACK = 0x400;
const unsigned MAX_MALLOC = 0xF000;

const int O_RDONLY = 0;     // for open()
const int O_BINARY = 0;

const int SEEK_SET = 0;     // for lseek()
const int SEEK_CUR = 1;
const int SEEK_END = 2;

extern char text_start; extern char text_end;
extern char data_start; extern char data_end;
extern char bss_start;  extern char bss_end;
extern unsigned char* heap_top;
extern int _argc;
//extern const char* _argv[];
extern const char** _argv;

void parse_cmdline();
int strlen(const char* s);
int strncmp(const char* a,const char* b,int sz);
int open(const char* name, int flags);
void exit(int n);
int read(int fd, void* data, int sz);
int write(int fd, const void* data, int sz);
long lseek(int fd, long sz, int dir);
void* malloc(unsigned sz);
void puts(const char* s);
unsigned long strtoul(const char *s, char **endptr=0, int radix=0);

#ifdef __WATCOMC__
#pragma aux exit = \
  "mov ah,0x4c" \
  "int 0x21" \
  modify [ah] parm [al];

#pragma aux open = \
  "mov ah,0x3d" \
  "int 0x21" \
  "jnc ok" \
  "sbb ax,ax" \
  "ok: " \
  modify [ax ah] parm [al] [dx] value [ax];

#pragma aux read = \
  "mov ah,0x3f" \
  "int 0x21" \
  "jnc ok" \
  "sbb ax,ax" \
  "ok: " \
  modify [ax ah] parm [bx] [dx] [cx] value [ax];

#pragma aux write = \
  "xor ax,ax" \
  "jcxz ok" \
  "mov ah,0x40" \
  "int 0x21" \
  "jnc ok" \
  "sbb ax,ax" \
  "ok: " \
  modify [ax ah] parm [bx] [dx] [cx] value [ax];

#pragma aux lseek = \
  "mov ah,0x42" \
  "int 0x21" \
  "jnc ok" \
  "sbb ax,ax" \
  "mov dx,ax" \
  "ok: " \
  modify [ax ah] parm [bx] [dx cx] [al] value [dx ax];
#endif

inline int strcmp(const char* a,const char* b) {
    return strncmp(a,b,unsigned(~1)-1);
}

inline int isalnum(char c) {
    return (c>='0' && c<='9')
        || (c>='A' && c<='Z')
        || (c>='a' && c<='z')
    ;
}

inline char toupper(char c) {
    if(c>='a' && c<='z') return c+('A'-'a');
    return c;
}

inline char tolower(char c) {
    if(c>='A' && c<='Z') return c+('a'-'A');
    return c;
}

// Extensions
//static void barrier() {}
//static void cli() { asm { cli } }
//static void sti() { asm { sti } }
#define barrier() do {} while(0)
#define cli() do { asm { cli } } while(0)
#define sti() do { asm { sti } } while(0)
#define int3() do { asm { db 0xcc } } while(0)
#define nop() do { asm { db 0x90 } } while(0)
extern char may_exit;
int die(const char* msg=0);
char* malloc_or_die(unsigned size, const char* msg=0);
