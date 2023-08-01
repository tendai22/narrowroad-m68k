/*
 * number.s ... number input conversion (ASCII to binary)
 */

.include "emu68kplus.h"

    .equ    code_top, 0x1000
    .equ    ram_end, 0x10000

    .org    0
    dc.l    end_ram
    dc.l    start
/*
 * code segment
 */
    .org    code_top
    .equ    code_top,  ram_top
    .equ    dict,  code_top + 0x1000
    .equ    linbuf,    dict_top + 0x1000

    .equ    sp_end,     ram_end
    .equ    end_sp,     sp_end
    .equ    rsp_end,    sp_end - 256
    .equ    end_rsp,    rsp_end
    .equ    dsp_end,    rsp_end - 256

/*
 * Forth interpreter initialize
 */
start:
/* virtual Forth machine registers */
    |.define IP a6
    |.define SP a5
    |.define RP a4
    move.l   #end_ram,%a7       /* set stack pointer */
    move.l   #end_sp,%a5        /* set SP */
    move.l   #end_rsp,%a4       /* set RSP */
    jmp      testnumber
/*
 * strings
 */

halt_message:
    dc.b    4
    .string  "halt"
    .align 2
/*
 * do_system ... halt the interpreter
 */
do_system:
    move.l   #halt_message,%a0
    jsr      (putstr)
do_system0:
    bra.b    do_system0         /* infinite loop
  
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
 * putstr
 * in: %a0: buf[0] ... n,length, buf[1]..[n] body of str
 */
putstr:
    move.w  %a0,-(%sp)      /* push %a0 */
    move.w  %d1,-(%sp)      /* push %d1 */
    move.w  %d0,-(%sp)      /* push %d0 */
    move.b  (%a0)+,%d1      /* use %d1 as counter */
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
 * inner interpreter
 */
do_exec:
    move.l   #next_addr,%a6  /* initialize IP (as return address) */
    move.w   #do_test,%a0
    jmp      (%a0)
next_addr:
    bra.b    next_addr
do_list:                        /* %a0 points to the code of the word, 
                                 * where it has address of 'do_list' */
    move.w  %a6,-(%a4)          /* push IP */
    move.w  %a0,%a6             /* address points to the code area of new word
                                 * IP now points to the address of the first pointer */
    add.w   #4,%a6              /* IP points the first token address
                                 * the size of `jmp do_list` is 4 bytes
                                 */
    jmp     do_next
do_exit:
    move.w  (%a4)+,%a6          /* pop IP from RSP */
    move.w  (%a6),%a0
    add.w   #2,%a6
    jmp     (%a0)
do_next:
    move.w  (%a6),%a0             /* 3 instructions equivalent to jmp  (%a6)+ */
    add.w   #2,%a6
    jmp     (%a0)               /* exec next token */
/* virtual machine instruction */
do_lit:
    move.w  (%a6)+,%d0          /* next word to %d0, immediate operand of 'do_lit' */
    move.w   %d0,-(%a5)         /* push it to Data Stack */
    bra.b   do_next
/* do_add */
do_add:
    move.l  (%a5)+,%d0          /* POP to %d0 */
    add.w   (%a5)+,%d0          /* POP and add to %d0 */
    move.l  %d0,-(%a5)          /* PUSH it to DS */
    bra.b   do_next
/* do_code */
do_code:
    move.l  #do_cexit,-(%a7)    /* return address */
    move.l  %a4,-(%a7)          /* save %a4(RSP), %a5(DSP), %a6(IP) */
    move.l  %a5,-(%a7)
    move.w  %a6,-(%a7)
    add.w   #2,%a0              /* next of the word, top of machine code */
    move.w  %a0,-(%a7)
    rts                         /* jmp %a0+2 */
do_cexit:
    move.w  (%a7)+,%a6
    move.w  (%a7)+,%a5
    move.w  (%a7)+,%a4
    bra.b   do_next

testnumber:
   /*
    * do_number
    * In: %a0 ... input string,
    *     %d1 ... max number of characters(length of input string)
    * Out: %a0 .. next position in input string
    *     %d1 ... rest number of characters (or zero)
    *     %d2: converted do_number
    *     %d0 ... validity flag, Zero: value of %d2 is valid, Non-Zero: not valid
    */

    move.l  #buffer,%a0
    add.l   #1,%a0
    move.b  buffer,%d1
loop:
    cmp.w   #0,%d1
    beq     loop
tnum11:
    jsr     (testnum1)
    bra     loop

testnum1:
    jsr     (do_number)
    and.l   %d0,%d0
    bne     tnum12
    move.l  %d2,%d0
    jsr     (puthex4)
    bra     tnum13
tnum12:
    move.b  #38,%d0             /* '&' */
    jsr     (putch)
tnum13:
    move.b  #32,%d0
    jmp     (putch)             /* crlf */

/*
 * tonumber
 * In: %d0  ... character
 * Out: %d0 ... result number (positive), not-a-numer (negative)
 */

__base:   dc.w  16

tonumber:
    cmp.b   #96,%d0
    bmi     tonumber0
    sub.b   #32,%d0
tonumber0:
    sub.b   #48,%d0         /* %0 - '0' */
    bmi     tonumber_bad
    cmp.b   #10,%d0
    bmi     tonumber1       /* branch if '0' - '9' */    
    /* %d0 > '9' */
    sub.b   #17,%d0         /* %0 - 'A' */
    bmi     tonumber_bad
    add.b   #10,%d0         /* %0 == 10--15 */
tonumber1:
    /* now get a number */
    cmp.w   (__base),%d0   /* %d0 - __base */
    bmi     tonumbere       /* branch if %d0 < #__base */
tonumber_bad:
    eor.l   %d0,%d0
    add.l   #-1,%d0         /* %d0 becomes -1 */
    rts
    /* now get a number */
tonumbere:
    and.l   #255,%d0
    rts

/*
 * do_number
 * In: %a0 ... input string,
 *     %d1 ... max number of characters(length of input string)
 * Out: %a0 .. next position in input string
 *     %d1 ... rest number of characters (or zero)
 *     %d2: converted do_number
 *     %d0 ... validity flag, Zero: value of %d2 is valid, Non-Zero: not valid
 */
do_number:
    move.w  %d3,-(%a7)      /* push %d3 */
    move.w  %d4,-(%a7)      /* push %d4 */
    /*
     * %d4 bit0: minus flag,
     *     bit1: data vaild flag
     * %d3 __base
     * %d2 accumulator
     * %d1 number of chars (rest chars)
     */
    eor.l   %d4,%d4         /* clear %d4 flags */
    move.w  (__base),%d3
    and.l   #65535,%d3      /* %d3 as __base */
    eor.l   %d2,%d2         /* clear accumulator */
do_num1:
    and.l   %d1,%d1         /* check if zero */
    beq     do_num_e
    /* skip previous space characters */
    move.b  (%a0),%d0
    cmp.b   #32,%d0
    bne     do_num2
    add.l   #1,%a0
    sub.l   #1,%d1
    bra     do_num1
    /* ok now we have reached the first non-space char */
do_num2:
    cmp.b   #45,%d0         /* minus char? */
    bne     do_num3
    /* minus char */
    or.w    #1,%d4          /* set %d4 minus flag */
    add.l   #1,%a0
    sub.l   #1,%d1
    /* check if next char is available */
    and.l   %d1,%d1
    bne     do_num3
    /* last char is minus, rewind it, and return */
    sub.l   #1,%a0
    add.l   #1,%d1
    bra     do_num_e
    /* gather digits */
do_num3:
    and.l   %d1,%d1
    beq     do_num_e
    move.b  (%a0)+,%d0
    sub.l   #1,%d1    
    jsr     (tonumber)
    and.l   %d0,%d0
    bmi     do_num5
    /* accumulate it */
    mulu    %d3,%d2
    add.w   %d0,%d2         /* %d2 = %d2 * (base) + %d0 */
    /* set valid flag */
    or.w    #2,%d4
    bra     do_num3
do_num5:
    /* first non digit char */
    /* rewind it */
    sub.l   #1,%a0
    add.l   #1,%d1
    /* falling down to do_num_e */
do_num_e:
    /* check valid number */
    move.l  %d4,%d0
    and.l   #2,%d0
    bne     do_num_e2
    /* invalid number */
    eor.l   %d0,%d0
    sub.l   #1,%d0
    bra     do_num_e4
    rts
do_num_e2:
    /* valid char */
    move.l  %d4,%d0
    and.l   #1,%d0           /* check minus flag */
    beq     do_num_e3
    neg     %d2
do_num_e3:
    /* ok, now return */
    eor.l   %d0,%d0
do_num_e4:
    move.w  (%a7)+,%d4
    move.w  (%a7)+,%d3
    rts

/* NUMBER subroutine */
buffer:
    dc.b   7
    .ascii  " 2e 4e "

 /*
  * dictionary
  */

    .org   0x2000 /*dict_top */
dict:
    dc.w   dict
    dc.w   entry_end
    dc.w   entry_head

entry_000:  /* entry "abc" */
e_abc:
    dc.b   3        /* name length. strlen("abc") +1 (if length is even) */
    .ascii "abc"
    .align 2
    dc.w   0        /* 0 means "no more entries we have" so top (the last one for searching) */
do_abc:
    jmp   do_list  /* machine language subroutine address */
    /* entry address list, execute them by 'do_list' subroutine */
    dc.w   do_lit
    dc.w   1
    dc.w   do_lit
    dc.w   2
    dc.w   do_add
    dc.w   do_exit
entry_001:  /* entry "defgh" */
e_defgh:
    dc.b   5
    .ascii "defgh"
    .align 2
    dc.w   entry_000
do_defgh:
    jmp    do_code
    mov.w  #1,-(%a5)        /* a5 is DSP */
    mov.w  #2,-(%a5)
    mov.w  (%a5)+,%d0
    add.w  (%a5)+,%d0
    mov.w  %d0,-(%a5)
    bra.w  do_cexit
entry_002:  /* entry "'", do_lit */
    dc.b   1
    .ascii "'"
    .align 2
    dc.w   entry_001
    dc.w   do_lit
entry_003:
e_test:
    dc.b   4
    .ascii "test"
    .align 2
    dc.w   entry_002
do_test:
    jmp    do_list
    dc.w   do_nop
    dc.w   do_abc
    dc.w   do_exit
entry_004:
entry_head:
    dc.b   3
    .ascii "nop"
    .align 2
    dc.w  entry_003
do_nop:
    jmp   do_list
    dc.w  do_exit
entry_end:
    dc.w  0,0,0
