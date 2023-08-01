/*  definitions */
 .equ ram,  0
 .equ start,  0x80
 .equ uart_dreg,  0x800A0
 .equ uart_creg,  0x800A1
 .equ HALT_REG,   0x800A2
 .equ dbg_table,  0x80100
 .equ u3txif,  2
 .equ u3rxif,  1


 .org      ram
    dc.l    0x1000
    dc.l    start
 .org      start
main:
    move.b  (uart_creg),%d0
    and.b   #u3txif,%d0
    beq.b    main
