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
    /*move.b  (dbg_table+2),%d0*/
    jsr     (putch)
    jsr     (getch)
    /*move.b  %d0,(dbg_table+3)*/
    bra.b   main
/*
 *  putch ... put one char from %d0
 */
putch:
    move.w    %d0,-(%a7)          /*  push %d0 */
putch1:
    move.b  (uart_creg),%d0
    and.b   #u3txif,%d0
    beq.b    putch1
    /*  now TXBUF be ready */
    move.w     (%a7)+,%d0         /*  pop %d0 */
    move.b  %d0,(uart_dreg)
    rts
/*
 * getch ... get one char in %d0
 */
getch:
    move.b (uart_creg),%d0
    and.b  #u3rxif,%d0
    beq.b  getch
    /* now RXRDY */
    move.b  (uart_dreg),%d0
    rts
