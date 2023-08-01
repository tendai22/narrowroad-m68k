/*
 *  loop.s ... simple infinite loop.
 */
/*  definitions */
 .equ ram,  0
 .equ start,  0x80

   .org     ram
    dc.l    0x1000
    dc.l    start
   .org     start
main:
    bra.b   main
