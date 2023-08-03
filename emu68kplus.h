/*
 * emu68kplus.h ... emu68kplus SBC hardware definitions
 */

#if !defined(__EMU68KPLUS_H)
#define __EMU68KPLUS_H
/*  definitions */
/* memory map */
 /*
 .equ ram,          0
 .equ start,        0x1000
 .equ end_ram,      0x10000
  */
 .equ uart_dreg,    0x800A0
 .equ uart_creg,    0x800A1
 .equ HALT_REG,     0x800A2
 .equ dbg_table,    0x80100
 /* UART CREG bit assign */
 .equ u3txif,       2
 .equ u3rxif,       1

/* line input buffer */
/*
 .equ linbuf,       0xf00
 .equ bufsiz,       64
*/
#endif //__EMU68KPLUS_H
