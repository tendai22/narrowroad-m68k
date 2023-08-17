    /*.org   0x2000 dict_top */
    .section DICT
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
entry_005:
e_pop:
    dc.b   3
    .ascii "pop"
    .align 2
    dc.w   entry_003
    /* short code word */
    add.w  #2,%a5
    jmp    do_next
entry_006:
e_plus:
    dc.b   1
    .ascii "+"
    .align 2
    dc.w   entry_005
    /* short code word */
    move.w  (%a5)+,%d0
    add.w   (%a5)+,%d0
    move.w  %d0,-(%a5)
    jmp    do_next
entry_004:
    dc.b   3
    .ascii "nop"
    .align 2
    dc.w  entry_006
do_nop:
    jmp   do_list
    dc.w  do_exit
entry_007:
e_dot:
    dc.b    1
    .ascii  "."
    .align  2
    dc.w    entry_004
    /* short code word */
    move.w  (%a5)+,%d0
    jsr     (do_putnum)
    jmp     do_next
e_cr:
entry_head:
    dc.b    2
    .ascii  "cr"
    .align  2
    dc.w    entry_007
    /* short code word */
    move.b  #13,%d0
    jsr     (putch)
    move.b  #10,%d0
    jsr     (putch)
    jmp     do_next
entry_end:
    dc.w  0,0,0
