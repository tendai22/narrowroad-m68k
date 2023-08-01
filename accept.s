
.include "emu68kplus.h"
.include "zeropage.h"

/*
 * sample string
*/
str1:
    .ascii "sample string"
    dc.b  1,2,3
    .org      start
main:
    move.l  #linbuf, %a0
    move.l  #bufsiz, %d1
    jsr     (accept)
    jsr     (crlf)
    jsr     (putstr)
    jsr     (crlf)
    bra.b   main
/*
 * accept: line input (aka gets)
 * In:  %a0:  *buf
 *      %d1:  bufsiz
 * Out: %d0:  number of input chars
 */
accept:
    move.w  %a1,-(%a7)      /* push %a1 */
    move.w  %d2,-(%a7)      /* push %d2 */
    move.w  %a0,%a1         /* initialize ptr p(as %a1) */
    move.w  %d1,%d2
    move.w  #0,%d1
acceptl:
    cmp.w   %d1,%d2
    ble     acceptz         /* d1 == d2 -> branch
                             * d1 > d2  -> branch
                             * d1 < d2  -> skip
                             */
    jsr     (getch)
    cmp.b   #'\r',%d0       /* \r ? */
    beq     acceptz
    cmp.b   #'\n',%d0
    beq     acceptz
    /* ^H/DEL .. erase one char */
    cmp.b   #8,%d0
    beq     acceptdel
    cmp.b   #0x7f,%d0
    beq     acceptdel
    /* put it on the buffer */
    move.w  %d0,-(%a7)      /* push d0 */
    jsr     (putch)
    move.w  (%a7)+,%d0      /* pop d0 */
    move.b  %d0,(%a1,%d1)   /* buf[i] = c */
    add.w   #1,%d1             /* i++ */
    bra.b   acceptl   
acceptdel:
    cmp.w   #0,%d1
    ble     acceptl         /* if it is on the top, do nothing */
    sub.w   #1,%d1           /* --i */
    move.b  #8,%d0          /* puts("^H ^H"); */
    jsr     (putch)
    move.b  #' ',%d0
    jsr     (putch)
    move.b  #8,%d0
    jsr     (putch)
    bra.b   acceptl  
acceptz:
    /* return it */
    move.w  %d1,%d0
    move.w  (%a7)+,%d2
    move.w  (%a7)+,%a1
    rts
acceptz2:
    bra.B   acceptz2
/* end of accept loop */

/* putstr
 * in: %a0: *buf
 *     %d0: num of chars
 */
putstr:
    move.w  %a0,-(%sp)      /* push %a0 */
    move.w  %d1,-(%sp)      /* push %d1 */
    move.w  %d0,-(%sp)      /* push %d0 */
    move.w  %d0,%d1         /* use %d1 as counter */
putstrl:
    add.w   #-1,%d1          /* --%d1 */
    blt     putstre
    move.b  (%a0)+,%d0
    jsr     (putch)
    bra.b   putstrl
putstre:
    move.w  (%sp)+,%d0
    move.w  (%sp)+,%d1
    move.w  (%sp)+,%a0
    rts
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
 * crlf
 */
crlf:
    move.b  %d0,-(%sp)
    move.b  #'\r',%d0
    jsr     (putch)
    move.b  #'\n',%d0
    jsr   (putch)
    move.b  (%sp)+,%d0
    rts


    

