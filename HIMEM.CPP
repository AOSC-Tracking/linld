// This file is distributed under GPL
//
// High mem handling routines
// C++ part of VCPI madness is here

#include "crtl.h"
#include "common.h"

// Returns physical addr of allocated himem chunk
// Never fails (will use fallback if not enough mem/no xmm)
// TODO: with proper cleanup it is possible to exit to DOS
// even after XMM alloc - do dealloc, then exit...
// don't forget to clean up the mess then, especially
// XMM handle which is lost inside xmm_alloc()...
// (don't drop fallback: use it if no XMM driver detected)
u32 malloc_himem(u32 size, u32 fallback) {
    may_exit = 0;       // die() won't return to DOS
    if(xmm_driver) {
        u32 v = xmm_alloc(xmm_driver, size);
        if(v) return v;
    }
    return fallback;
}

void read2himem(int fd, u32 high_ofs, u32 remaining,
    void* xfer_buf, u16 xfer_size
) {
    while(1) {
        u16 size = read(fd, xfer_buf, xfer_size);
        if(s16(size) == -1) die("Read error");
        if(!size) {
            if(remaining) die("File is shorter than file size?!");
            break;
        }
        remaining -= size;
        if(s32(remaining) < 0) // too many bytes read?!
            die("File is longer than file size?!");
        memcpy32(0, high_ofs, seg(xfer_buf), ofs(xfer_buf), size);
        high_ofs += size;
    }
}

// Dunno how efficient is it, but it works
static void sort(u32* v, int size) {
    {for(int start=0;start<size-1;start++) {
        u32 min=v[start]; int pos=start;
        {for(int i=start+1;i<size;i++) {
            if(min>v[i]) {
                min=v[i]; pos=i;
            }
        }}
        u32 t = v[start];
        v[start] = v[pos];
        v[pos] = t;
    }}
}

// Returns ptr to mallocated zero-terminated list of physical page addrs
// Never fails (will die if not enough mem)
// Addresses are sorted in ascending order
u32* malloc_vcpi(u32 size) {
    may_exit = 0;       // die() won't return to DOS
    u16 cnt = (size+PAGE_SIZE-1)/PAGE_SIZE;
    u32* buf = (u32*)malloc_or_die((cnt+1)*sizeof(u32),"malloc_vcpi() failure");
    // our malloc zeroes allocated mem: buf[cnt]=0;
    // Allocate pages, storing addrs in addrbuf
    {for(int i=0;i<cnt;i++) {
        u32 v;
        asm {
                db      66h
                xor     dx,dx
                mov     ax,0DE04h
                int     67h
                db      66h
                mov     [word ptr v],dx
        }
        if(!v) die("malloc_vcpi() failure");
        buf[i] = v;
    }}
    // Sanitize addresses: ascending sort
    sort(buf,cnt);
    return buf;
}

// Reads opened fd data into malloc_vcpi'ed memory
// Dies if file isn't exactly 'size' bytes long
// Needs intermediate buffer of exactly Nx4k bytes
void read2vcpi(int fd, u32* vp, u32 remaining,
    void* xfer_buf, u16 xfer_size
) {
#ifdef DEBUG
    if(xfer_size & PAGE_MASK) die("Bad xfer_size");
#endif
    while(1) {
        // May be replaced by read_exact()
        u16 size = read(fd, xfer_buf, xfer_size);
        if(s16(size) == -1) die("Read error");
        if(!size) {
            if(remaining) die("File is shorter than file size?!");
            break;
        }
        remaining -= size;
        if(s32(remaining) < 0) // too many bytes read?!
            die("File is longer than file size?!");
        if(size!=xfer_size && remaining) die("Incomplete read");
        size = (size+PAGE_SIZE-1)/PAGE_SIZE;
        u16 pos = ofs(xfer_buf);
        while(size--) {
            if(!*vp) die("VCPI buf is too small");
            memcpy_vcpi(*vp++, seg(xfer_buf), pos);
            pos+=PAGE_SIZE;
        }
    }
}

// We don't need this under DOS ?
// Well, use if you see "incomplete read"
/*
static u16 read_exact(int fd, void* data, int rem) {
    u16 size = 0;
    do {
        u16 n = read(fd, data, rem);
        if(s16(n) == -1) return -1;
        size += n; rem -= n; ((char*&)data) += n;
        if(!size) return 0;
    } while(rem);
    return size;
}
*/

/*
void free_vcpi(u32* p) {
    //u32* p=buf;
    while(1) {
        u32 v = *p++;
        if(!v) break;
        asm {
                db      66h
                mov     dx,[word ptr v]
                mov     ax,0DE05h
                int     67h
                dec     [gcnt]
        }
    };
    //free(buf);
}
*/
