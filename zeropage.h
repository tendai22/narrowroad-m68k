/*
 * zeropage.h ... emu68kplus vectors
 */
#if !defined(__ZEROPAGE_H)
#define __ZEROPAGE_H
    .org      ram
    dc.l    end_ram     /* end_ram, SP value*/
    dc.l    start       /* initial code, PC value */
    .align 16
#endif //__ZEROPAGE_H
