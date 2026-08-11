// This file is distributed under GPL
//
// Bare bones of C runtime library

#include "CRTL.H"
#include "COMMON.H"

int strlen(const char* s) {
    if(!s) return 0;
    const char* p=s;
    while(*p) p++;
    return p-s;
}

int strncmp(const char* a,const char* b,int sz) {
    typedef unsigned char uchar;
    while(sz--) {
        int x = uchar(*a++);
        int y = x - uchar(*b++);
        if(y) return y;
        if(!x) return 0;    // found '\0' in both strs at once
    }
    return 0;
}

static char crlf[] = { '\r', '\n' };

void puts(const char* s) {
    write(1,s,strlen(s));
    write(1,crlf,2);
}

unsigned char* heap_top = (unsigned char*)&bss_end;

// Note: you can free/resize last allocated block(s)
// by altering heap_top. Be careful though...
// Note: we zero out allocated block like calloc()
void* malloc(unsigned sz) {
    if(unsigned(GetSP()) < unsigned(heap_top)
    || unsigned(GetSP())-unsigned(heap_top) < sz+MIN_STACK
    || sz>MAX_MALLOC    // guards against overflows
    ) {
        puts("malloc() failure");
        return 0;
    }
    void* p = heap_top;
    while(sz--)
        *heap_top++ = '\0';
    return p;
}

char may_exit = 1;

int die(const char* msg) {
    if(msg && msg[0]) puts(msg);
    if(may_exit==0) {
        puts("High mem corrupted - not exiting to DOS");
        cli();
z:      goto z;
    }
    exit(1);
    return 0;
}

char* malloc_or_die(unsigned size, const char* msg) {
    void* p = malloc(size);
    if(!p) die(msg);
    return (char*)p;
}

int _argc;
const char** _argv;

void parse_cmdline() {
    int cnt = *(unsigned char*)0x80;
    if(cnt>0x7e) cnt=0x7e;
    char* p = (char*)0x81;
    p[cnt]='\0';
    //If you want to lowercase entire command line:
    //while( (*p = tolower(*p))!=0 ) p++;
    //p = (char*)0x81;

    _argc=1;
    _argv = (const char**)malloc_or_die(64*sizeof(_argv[0]));
    _argv[0]=0;
    while(1) {
        // skip spaces
        while(*p==' ') *p++ = '\0';
        if(!*p) break;
//        //argv[] bounds check
//        if( _argc >= sizeof(_argv)/sizeof(_argv[0]) ) break; //

        // process new argv[]
        char delim=' ';
        if(*p == '"') {
            delim='"';
            if(!*++p) break; //skip over '"'
        }
        _argv[_argc++]=p;
        while(*p != delim)
            if(!*p++) goto brk;
        *p=' ';     //this forces end of current argv if delim was '"'
    }
brk:
    // done by malloc: _argv[_argc]=0;
    heap_top = (unsigned char*)(_argv+_argc+1);
}

unsigned long strtoul(const char *s, char ** /*endptr*/, int radix) {
    unsigned long v=0;
    char n;
    if(s) {
        if(radix==0) {
            radix=10;
            if(s[0]=='0') {
                radix=8;
                s++;
                if(s[0]=='x' || s[0]=='X') {
                    radix=16;
                    s++;
                }
            }
        }
        while( isalnum(n=toupper(*s)) ) {
            n -= '0'; if(n>9) n = n+'0'-'A'+10;
            if(n >= radix) break;
            v = v*radix + n;
            s++;
        }
        //not used yet: if(endptr) *endptr=s;
    }
    return v;
}

#ifdef __BORLANDC__
void exit(int n) {
    asm {
        mov     al,byte ptr n
        mov     ah,0x4c
        int     0x21
    }
}

int open(const char* name, int flags) {
    asm {
        mov     al,byte ptr flags
        mov     dx,name
        mov     ah,0x3d
        int     0x21
        jnc     ok
        sbb     ax,ax   // ax=-1
    }
ok:
    return _AX;
}

int read(int fd, void* data, int sz) {
    asm {
        mov     cx,sz
        mov     bx,fd
        mov     dx,data
        mov     ah,0x3f
        int     0x21
        jnc     ok
        sbb     ax,ax   // ax=-1
    }
ok:
    return _AX;
}

int write(int fd, const void* data, int sz) {
    asm {
        mov     cx,sz
        xor     ax,ax
        jcxz    ok
        mov     bx,fd
        mov     dx,data
        mov     ah,0x40
        int     0x21
        jnc     ok
        sbb     ax,ax   // ax=-1
    }
ok:
    return _AX;
}

long lseek(int fd, long sz, int dir) {
    asm {
        mov     dx,word ptr sz
        mov     cx,word ptr sz+2
        mov     bx,fd
        mov     al,byte ptr dir
        mov     ah,0x42
        int     0x21
        jnc     ok
        sbb     ax,ax   // dx:ax=-1
        mov     dx,ax   //
    }
ok:
    return long(MK_FP(_DX,_AX));
}
#endif
