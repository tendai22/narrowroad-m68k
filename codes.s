.include "emu68kplus.h"

/*    .equ    code_top, 0x1000
    .equ    dict_top, 0x2000
    .equ    ram_end, 0x10000
*/
    .section VECTOR_TABLE
    dc.l    sp_end          /* 0: Initial SP */
    dc.l    start           /* 1: Initial PC */
    dc.l    do_exception    /* 2: Access fault */
    dc.l    do_buserror     /* 3: Address Error */
    dc.l    do_exception    /* 4: Illegal Instruction */
    dc.l    do_divbyzero    /* 5: Divide by Zero */

/*
 * code segment
 */
    .section CODES
code_top:
ram_top:

    .section BUFFER
linbuf:
    .space 128
linbufend:
wordbuf:
    .space 128

    .section VARIABLE
    .global __base
__base:
    dc.w   10

    .section STACK
stack_bottom:
    .space 256
dsp_end:
    .space 256
rsp_end:
    .space 256
sp_end:

/*
 * Forth interpreter initialize
 */
    .section CODE
buserror_str:
    dc.b    9
    .ascii  "bus error "
exception_str:
    dc.b     9
    .ascii  "exception "
divbyzero_str:
    dc.b    14
    .ascii  "divide by zero "
do_divbyzero:
    move.l  #divbyzero_str,%a0
    bra     do_exception_message
do_buserror:
    move.l  #buserror_str,%a0
    bra     do_exception_message
do_exception:
    /* exception ... rewind SP, IP, DSP, RSP */
    move.l  #exception_str,%a0
do_exception_message:
    jsr     (putstr)
    jsr     (bl)
    add.l   #2,%a7
    move.l  (%a7),%a0         /* access address */
    move.l  %a0,%d0
    jsr     (puthex8) 
    jsr     (crlf)
    /* falling down to start */
start:
    /* virtual Forth machine registers */
    |.define IP a6
    |.define DSP a5
    |.define RSP a4
initial_point:
    move.l   #sp_end,%a7       /* set stack pointer */
    move.l   #dsp_end,%a5        /* set DSP */
    move.l   #rsp_end,%a4       /* set RSP */

/*
 * outer interpreter 
 */
outer:
outer1:
    /* stack underflow check */
    cmp.l  #dsp_end,%a5
    ble    outer1_1
outer_uerr:
    /* underflow, rest dsp */
    move.l  #dsp_end,%a5
    move.l  #underflow_str,%a0
    jsr     (putstr)
    jsr     (crlf)
outer1_1:
    /* main loop */
    jsr    (dump_stack)
    move.b  #93,%d0             /* ']' as a prompt */
    jsr    (putch)
    /* line input */
    move.l  #linbuf,%a0         /* &linbuf[0] */
    move.l  #64,%d1
/*outer2:*/
    jsr     (accept)
    jsr     (crlf)
    /*
     * %d0, number of input char
     */
    and.l   %d0,%d0
    beq     outer1               /* re getline */
/*
 * do_number
 */
    move.l  #linbuf,%a0         /* &linbuf[0] */
    move.l  %d0,%d1             /* number of input string */
outer3:
    /* parsing loop */
    /* In: %a0 ... input string,
     *     %d1 ... (rest) number of characters(length of input string)
     */
outer4:
    /* at first, get a word */
    /* In: %a0 ... input string,
     *     %d1 ... number of input characters(length of input string)
     *     %a1 ... destination buffer, [0]: length, [1...]: characters
     *     %d2 ... max number of destination buffer
     */
    move.l  #wordbuf,%a1
    move.w  #32,%d2
    jsr    (do_word)
     * Out: %a0 .. next position in input string
     *     %a1 ... next position in destination buffer
     *     %d1 ... rest number of input characters (or zero)
     *     %d2 ... rest number of destination buffer
     *     %d0 ... result flag, return number of copied characters
     */
    and.l    %d0,%d0
    bne      outer6
    /* no words gotten, check end-of-data? */
    and.l    %d1,%d1
    beq      outer1  /* get next line */
    bra      outer3  /* process rest characters */
outer6:
    /* now gotten a word, find and execute */
    /* in: %a0 ... a word pointer
     *     %a1 ... 'HEAD', top of the dictionary entry
     */
    move.l   %a0,-(%a7)          /* push %a0 */
    move.w   %d1,-(%a7)          /* push %d1 */
    move.w   %d2,-(%a7)
    move.l   #wordbuf,%a0
    /*
    move.w   (%a0),%d2
    and.w    #255,%d2
    mulu.w   #256,%d0
    or.w     %d2,%d0
    move.w   %d0,(%a0)*/          /* set number of chars to wordbuf[0] */
    move.l   #0x2004,%a1
    move.w   (%a1),%a1           /* set HEAD to %a1 */
    jsr      (do_find)
    /* out: %a0 .. addr (top) of found entry, or zero if not found
     *      %a1 .. addr of CFR of found entry 
     */
    move.l   %a0,%d0
    and.l    %d0,%d0
    beq      outer5
do_exec:
    move.l   #next_addr,%a6     /* initialize IP (as return address) */
    move.l   %a1,%a0            /* jump to CFR of the entry */
    jmp      (%a0)
next_addr:
    dc.w     next_addr2
outer5:
    /* word not found, try to convert a number */
    /* In: %a0 ... input string, (wordbuf)
     *     %d1 ... (rest) number of characters(length of input string)
     */
    move.l  #wordbuf,%a0
    move.b  (%a0)+,%d1
    and.w   #255,%d1
    /* In: %a0 ... input string,
     *     %d1 ... max number of characters(length of input string)
     */
    jsr     (do_number)
    /* Out: %a0 .. next position in input string
     *     %d1 ... rest number of characters (or zero)
     *     %d2: converted do_number
     *     %d0 ... validity flag, Zero: value of %d2 is valid, Non-Zero: not valid
     */
    and.l   %d0,%d0
    bne     outer7
    /* get a number, push it */
    move.w  %d2,-(%a5)          /* put a number to DSP */
    bra     next_addr2
next_addr2:
    /* restore input linbuf, and rest size */
    /* now the entry execution finished */
    /* rewind stack */
    move.w   (%a7)+,%d2
    move.w   (%a7)+,%d1
    move.l   (%a7)+,%a0
    jmp      outer3
    /* error message */
notfound_str:
    dc.b     11
    .ascii  "not found\r\n"
outer7:
    /* rewind stack */
    move.w   (%a7)+,%d2
    move.w   (%a7)+,%d1
    move.l   (%a7)+,%a0
    /* not found error */
    jsr     (crlf)
    move.l  #wordbuf,%a0
    jsr     (putstr)
    jsr     (bl) 
    move.l  #notfound_str,%a0
    jsr     (putstr)
    /* dispose linbuf content, re-getline */
    bra     outer1
    /* end of word/number process, go to rest of linbuf */

/* stack dump */
dump_stack:
    move.l   %a0,-(%a7)
    move.l   %a1,-(%a7)
    move.w   %d0,-(%a7)
    move.l   #dsp_end,%a0   /* end of stack */
    move.l   %a5,%a1        /* top of stack */
dump_s1:
    cmp.l    %a0,%a1
    beq      dump_se
    move.w   -(%a0),%d0
    jsr      (puthex4)
    jsr      (bl)
    bra      dump_s1
dump_se:
    move.w   (%a7)+,%d0
    move.l   (%a7)+,%a1
    move.l   (%a7)+,%a0
    rts


/*
 * strings
 */
underflow_str:
    dc.b    9
    .ascii  "underflow"
    .align  2
halt_message:
    dc.b    4
    .ascii  "halt"
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
    .global  putch
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
    .global putstr
putstr:
    move.w  %a0,-(%sp)      /* push %a0 */
    move.w  %d1,-(%sp)      /* push %d1 */
    move.w  %d0,-(%sp)      /* push %d0 */
    move.b  (%a0)+,%d1      /* use %d1 as counter */
    and.w   #0xff,%d1
putstrl:
    beq     putstre
    move.b  (%a0)+,%d0
    jsr     (putch)
    add.w   #-1,%d1          /* --%d1 */
    bra.b   putstrl
putstre:
    move.w  (%sp)+,%d0
    move.w  (%sp)+,%d1
    move.w  (%sp)+,%a0
    rts
/*
 * puthex8
 */
puthex8:
    swap    %d0
    jsr     (puthex4)
    swap    %d0
    /* falling down puthex4 */
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
    move.w  %d0,-(%a7)
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
    move.w  (%a7)+,%d0
    rts
/*
 * safe routines 
 */
puthex4_safe:
    move.l  %d0,-(%a7)
    jsr     (puthex4)
    move.l  (%a7)+,%d0
    rts
puthex2_safe:
    move.l  %d0,-(%a7)
    jsr     (puthex2)
    move.l  (%a7)+,%d0
    rts
bl_safe:
    move.l  %d0,-(%a7)
    jsr     (bl)
    move.l  (%a7)+,%d0
    rts
putch_safe:
    move.l  %d0,-(%a7)
    jsr     (putch)
    move.l  (%a7)+,%d0
    rts
/*
 * putnum:
 * In: %d0  input value to be printed
 */
    .global do_putnum
do_putnum:
putnum:
    move.l  %d0,-(%a7)
    move.l  %d1,-(%a7)
    move.l  %d2,-(%a7)
    move.l  %d3,-(%a7)
    move.l  %d4,-(%a7)
    move.l  %a0,-(%a7)
    eor.l   %d4,%d4
    /* chech minus or plus */
    cmp.w   #0,%d0
    bpl     putnum1
    beq     putnum1
    neg.w   %d0
    and.w   %d0,%d0
    beq     putnum1
    move.l  %d0,%d1
    move.b  #45,%d0         /* '-' */
    jsr     (putch)
    move.l  %d1,%d0
putnum1:
    move.w  __base,%d1
    move.l  #linbufend,%a0
putnum3:
    /* divide __base, and print the reminder */
    divu.w  %d1,%d0     /* reminder: upper16, quotient:lower16 */
    /* convert one digit to ASCII */
    swap    %d0
    move.l  %d0,%d2
    and.w   #0xf,%d0
    sub.b   #10,%d0
    bcs     putnum11
    /* 10-15 */
    add.b   #('A'-'0'-10),%d0
putnum11:
    add.b   #('0'+10),%d0
    /* store a disit ASCII to putnumbuf[--i] */
    move.b  %d0,-(%a0)  /* put digit ASCII to putnumbuf[--p] */
    move.l  %d2,%d0
    swap    %d0
    and.l   #65535,%d0
    bne     putnum3        /* quit if it is zero */
    /* ok, convertion is over, print it now */
putnum4:
    move.b  (%a0)+,%d0
    jsr     (putch)
    cmp.l   #linbufend,%a0
    bne     putnum4
putnum_e:
    move.l  (%a7)+,%a0
    move.l  (%a7)+,%d4
    move.l  (%a7)+,%d3
    move.l  (%a7)+,%d2
    move.l  (%a7)+,%d1
    move.l  (%a7)+,%d0
    rts

/*
 * put1digit:  put one digit of %d0
 */
put1digit:
    move.l  %d0,-(%a7)
    cmp.w   #10,%d0
    bge     put1digit1
    /* 0 -- 9 */
    add.b   #48,%d0
    bra     put1digit2
put1digit1:
    /* 10 or more */
    add.b   #55,%d0
put1digit2:
    jsr     (putch)
    move.l  (%a7)+,%d0
    rts
/*
 * crlf, bl
 */
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
 * TYPEB
 */
/* do_typeb_sub:
 * IN: %a0 ... addr
 */
    .global typeb_sub
typeb_sub:
    move.l  %d0,-(%a7)
typeb_sub1:
    move.b  (%a0)+,%d0
    jsr     (putch)
    cmp.b   #' ',%d0
    bne     typeb_sub1
    move.l  (%a7)+,%d0
    rts




/*
 * inner interpreter
 */
    .global do_list
do_list:                        /* %a0 points to the code of the word, 
                                 * where it has address of 'do_list' */
    move.w  %a6,-(%a4)          /* push IP */
    move.w  %a0,%a6             /* address points to the code area of new word
                                 * IP now points to the address of the first pointer */
    add.w   #6,%a6              /* IP points the first token address
                                 * the size of `jmp do_list` is 4 bytes
                                 */
    jmp     do_next

    .global do_exit
do_exit:
    move.w  (%a4)+,%a6          /* pop IP from RSP */
    move.w  (%a6),%a0
    add.w   #2,%a6
    jmp     (%a0)
    .global do_next
do_next:
    move.w  (%a6),%d0           /* 3 instructions equivalent to jmp  (%a6)+ */
    and.w   #0x3fff,%d0         /* clear precedence info */
    move.w  %d0,%a0
    /* jsr     (dump_entry)*/        /* for debugging */
    add.w   #2,%a6
    jmp     (%a0)               /* exec next token */

/* virtual machine instruction */
    .global do_lit
do_lit:
    move.w  (%a6)+,%d0          /* next word to %d0, immediate operand of 'do_lit' */
    move.w   %d0,-(%a5)         /* push it to Data Stack */
    bra.b   do_next
/* do_add */
    .global do_add
do_add:
    move.w  (%a5)+,%d0          /* POP to %d0 */
    add.w   (%a5)+,%d0          /* POP and add to %d0 */
    move.w  %d0,-(%a5)          /* PUSH it to DS */
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
/* branch */
    .global do_bne
do_bne:
    move.w  (%a5)+,%d0
    and.w   %d0,%d0
    bne.w   do_bra
    add.w   #2,%a6
    bra.w   do_next

    .global do_bra
do_bra:
    add.w   (%a6)+,%a6
    bra.w   do_next

    .global true_str
true_str:
    dc.b    4
    .ascii  "true"
    .align  2
    .global false_str
false_str:
    dc.b    5
    .ascii  "false"
    .align  2
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
    /* trailing space on the buffer */
    move.b  #' ',(%a1,%d1)
    add.w   #1,%d1
    /* return it */
    move.w  %d1,%d0
    move.w  (%a7)+,%d2
    move.w  (%a7)+,%a1
    rts
acceptz2:
    bra.B   acceptz2
/* end of accept loop */

/*
 * tonumber
 * In: %d0  ... character
 * Out: %d0 ... result number (positive), not-a-numer (negative)
 */
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
     *     bit1: data valid flag
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

/*
 * do_word
 * In: %a0 ... input string,
 *     %a1 ... destination buffer, [0]: length, [1...]: characters
 *     %d1 ... number of input characters(length of input string)
 *     %d2 ... max number of destination buffer
 * Out: %a0 .. next position in input string
 *     %a1 ... next position in destination buffer
 *     %d1 ... rest number of input characters (or zero)
 *     %d2 ... rest number of destination buffer
 *     %d0 ... result flag, return number of copied characters
 */

    .global do_word
do_word:
    move.l  %a2,-(%a7)      /* push %a2 */
    move.w  %d3,-(%a7)      /* push %d3 */
    /*
     * %d4 bit1: data vaild flag
     * %a2 saved top of destination buffer 
     * %d1 number of input chars (rest chars)
     * %d2 number of rest destionation chars
     */
    move.l  %a1,%a2         /* %a2, saved top of destination buffer */
    add.l   #1,%a1          /* %a1 points to top of dest buffer */
    sub.l   #1,%d2          /* decrement one from dest counter */
do_word1:
    and.l   %d1,%d1         /* check if zero */
    beq     do_word3
    /* skip previous space characters */
    move.b  (%a0),%d0
    cmp.b   #32,%d0
    bne     do_word2
    add.l   #1,%a0
    sub.l   #1,%d1
    bra     do_word1
    /* ok now we have reached the first non-space char */
do_word2:
    /* check if next char is available */
    and.l   %d1,%d1         /* source exhaused */
    beq     do_word3
    and.l   %d2,%d2         /* destination filled */
    beq     do_word4
    /* last char is minus, rewind it, and return */
    move.b  (%a0)+,%d0
    and.b   #255,%d0
    move.b  %d0,(%a1)+
    cmp.b   #32,%d0
    beq     do_word5
    sub.l   #1,%d1
    sub.l   #1,%d2
    bra     do_word2
do_word5:
    /* find another non-space char */
    sub.l   #1,%a0
    sub.l   #1,%a1
do_word3:
    /* finalize if source is exhausted */
do_word4:
    /* finalize if destination is exhausted */
    /* finalize destination buffer */
    /* set the number to top of destination buffer */
    move.l  %a1,%d0
    sub.l   %a2,%d0         /* %d0: number of copied chars */
    sub.b   #1,%d0
    move.b  %d0,(%a2)       /* set number of destination buffer characters */
    /* now %d0 has the number of copied character */
    move.w  (%a7)+,%d3      /* pop %d3 */
    move.l  (%a7)+,%a2      /* pop %a2 */
    rts

/*
 * do_same
 * In: %a0, %a1 ... strings
 * Out: %d0: Zero ... match, NZ .. not same
 */
do_same:
    move.w  %d1,-(%a7)      /* push %d1 */
    move.w  %a1,-(%a7)
    move.w  %a0,-(%a7)
do_same0:
    move.b  (%a0),%d0
    and.w   #0x1f,%d0       /* upper 3bit ignored in comparison */
    add.b   #2,%d0
    lsr     #1,%d0          /* (%d0 + 2) / 2 */
    /* first word comparison */
    move.w  (%a0)+,%d1
    sub.w   (%a1)+,%d1
    and.w   #0x1fff,%d1
    bne     do_same1        /* exit with Non-Zero */
    add.b   #-1,%d0
    beq     do_same1
do_same2:
    move.w  (%a0)+,%d1
    sub.w   (%a1)+,%d1
    bne     do_same1        /* exit with Non-Zero */
    add.b   #-1,%d0
    bne     do_same2        /* loop to next char */
    /* Zero if all compares are equal */
do_same1:
    move.w  (%a7)+,%a0
    move.w  (%a7)+,%a1
    move.w  (%a7)+,%d1
    rts

/*
 * do_find
 * in: %a0 ... a word pointer
 *     %a1 ... 'HEAD', top of the dictionary entry
 * out: %a0 .. addr (top) of found entry, or zero if not found
 *      %a1 .. addr of CFR of found entry 
 */
do_find:
    move.w  %d0,-(%a7)
find0:
    jsr     do_same
    cmp.b   #0,%d0
    beq     find1
    /* get the next entry top */
    eor.w   #0,%d0         /* clear D0 wordly */
    move.b  (%a1),%d0
    and.b   #0x1f,%d0
    add.b   #2,%d0
    lsr     #1,%d0
    add.w   %d0,%d0     /* word offset to byte offset */
    add.w   %d0,%a1
    move.w  (%a1),%d0   /* %d0 now points to next entry top */
    and.w   #0xbfff,%d0 /* test %d0 (next ptr value) */
    move.w  %d0,%a1     /* clear precedence flag bits */   
    bne     find0
    /* find an entry */
find1:
    move.w  %a1,%a0
    move.b  (%a0),%d0
    and.w   #0x1f,%d0
    lsr     #1,%d0
    add.b   #1,%d0
    lsl     #1,%d0
    add.w   %d0,%a1
    add.w   #2,%a1      /* skip PTR */
    move.w  (%a7)+,%d0
    rts
sample:
    jmp     do_list
/*
 * dump_entry ... debugging entry dump
 * IN: %a0 ... CFA in the entry
 */
dump_entry:
    move.l  %a0,-(%a7)
    move.w  %a6,%d0
    jsr     (puthex4)
    jsr     (bl)
    move.w  %a0,%d0
    jsr     (puthex4)
    jsr     (crlf)
    move.l  (%a7)+,%a0
    rts

