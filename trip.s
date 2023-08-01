/*  */
/*  Trip.s ... follow Chuck's travel. */
/*  */
/*  */
/*  definitions */
 .equ ram,  0
 .equ start,  0x80
 .equ uart_dreg,  0x800A0
 .equ uart_creg,  0x800A1
 .equ HALT_REG,   0x800A2
 .equ dbg_port,  0x80100
 .equ u3txif,  2
 .equ u3rxif,  1


 .org      ram
    dc.l    0x1000
    dc.l    start
 .org      start
main:
    move.w  #0x0080,%a0
    move.w  #0x0024,%d0
    jsr     (dodump)
halt_loop:
    move.b  %d0, (HALT_REG)
    bra.b   halt_loop
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
/*
 * kbhit
 * Ret: Z: not ready, NZ: ready
 */
 kbhit:
    move.b  (uart_creg),%d0
    and.b   #u3rxif,%d0         /* bit0, 0: not ready, 1: ready */
    rts
/*
 * memclr loop
 *  %d0: data (low 8 bit)
 *  %a0: start ptr
 *  %d1: rest counter
 */
memclr:
    move.b  #'A',%d0
    jsr     (putch)
    move.b  #0,%d0
    move.w  #0x400,%a0
    move.w  #0x500,%a1
    move.w  %a1,%d1
    sub.w   %a0,%d1         /* d1 - a0 -> d1 */
memclr1:
    beq.b   memclr2         /* if %d1 is zero, jump to end */
    move.b  %d0,(%a0)+
    sub.w   #1,%d1          /* dec %d1 */
    bra.b   memclr1
memclr2:
    move.b  %d0,(dbg_port+11)  /* halt instruction */
    bra.b   memclr
/*
 * dodump
 * hex dump a region of RAM storage
 * %a0: begin address
 * %d0: count
 */
dodump:
    move.w  %a1,-(%a7)      /* push %a1 */
    move.w  %d1,-(%a7)      /* push %d1 */
    move.w  %d0,%d1         /* %d1: loop counter */
    move.w  %a0,%a1         /* %a1: address pointer */
    move.w  %a0,%d0
    and.w  #0xfffe,%d0     /* address should be even */
    move.w  %d0,%a1
    and.w   #0xfff0,%d0        /* %d0: actual start address */
    /* type initial address */
    move.w  %d0,(dbg_port+2)
    jsr     (puthex4)
    move.b  #':',%d0
    jsr     (putch)
    jsr     (bl)            /* type a blank */
    /* check skip words */
dodump1:
    /* prefix five spaces */
    move.b  %d0,(dbg_port)
    move.w  %a1,%d0
    and.w   #0xf,%d0         /* %d1 = %a1 & 0xf, skip count */
dodump2:
    beq.b   dodump3         /* if zero, end of five spaces */
    /* five spaces */
    jsr     (bl)
    jsr     (bl)
    jsr     (bl)
    jsr     (bl)
    jsr     (bl)
    sub.w   #2,%d0
    bge.b   dodump2
dodump3:
    /* check loop counter */
    and.w   %d1,%d1         /* check loop counter */
    beq.b   dodump4
    /* word dump loop */
    move.w  %a1,%d0
    and.w   #0xf,%d0
    bne.b   dodump5         /* skip typing address */
    /* type address */
    move.w  %a1,%d0
    jsr     (puthex4)
    move.b  #':',%d0
    jsr     (putch)
    jsr     (bl)
dodump5:
    /* put word */
    move.w  (%a1),%d0
    jsr     (puthex4)
    jsr     (bl)
    add.w   #2,%a1
    /* check eol */
    move.w  %a1,%d0
    and.w   #0xf,%d0
    bne.b   dodump6     /* to tail check */
    /* put crlf */
    jsr     (crlf)
dodump6:
    sub.w   #2,%d1
    bge.b   dodump3
dodump4:
    /* all dump over, closing process */
    move.w  %a1,%d0
    and.b   #0xf,%d0
    beq.w   dodumpx
    /* do crlf if address %15 != 0 */
    jsr     (crlf)
dodumpx:
    /* pop registers */
    move.w  (%a7)+,%d1      /* pop %d1 */
    move.w  (%a7)+,%a1      /* pop %a1 */
    rts
/*
 * puthex4 .. print 4 digit hex
 * IN: %d0
 */
puthex4:
    move.w  %d0,-(%a7)      /* push %d0 */
    ror.w   #8,%d0
    jsr     (puthex2)           /* type upper byte */
    move.w  (%a7)+,%d0      /* pop %d1 */
    jsr     (puthex2)           /* type lower byte */
    rts
puthex2:
    move.w  %d0,-(%a7)      /* push %d0 */
    lsr.w   #4,%d0
    jsr     (puthex1)
    move.w  (%a7)+,%d0
    jsr     (puthex1)
    rts
puthex1:
    and.w   #0xf,%d0
    sub.b   #10,%d0
    bcs     puthex11
    /* 10-15 */
    add.b   #('A'-'0'-10),%d0
/*    bra.b   puthex12*/
puthex11:
    add.b   #('0'+10),%d0
puthex12:
    jsr     (putch)
    rts
crlf:
    move.w  %d0,-(%a7)      /* push %d0 */
    move.b  #'\r',%d0
    jsr     (putch)
    move.b  #'\n',%d0
putone:
    jsr     (putch)
    move.w  (%a7)+,%d0      /* pop %d0 */
    rts
bl:
    move.w  %d0,-(%a7)      /* push %d0 */
    move.b  #' ',%d0
    bra.b   putone
/*
 * 
/* end */ 

