    /*.org   0 dict_top */
    .section DICT
dict:
    dc.w   dict
    dc.w   entry_end
    dc.w   entry_head
entry_000:
e_abc:
    dc.b    3
    .ascii  "abc"
    .align  2
    dc.w    0
do_abc:
    jmp     do_list
    dc.w    
    dc.w    do_lit
    dc.w    1
    dc.w    do_lit
    dc.w    2
    dc.w    do_add
    dc.w    do_exit
entry_001:
e_defgh:
    dc.b    5
    .ascii  "defgh"
    .align  2
    dc.w    entry_000
do_defgh:
    
    mov.w  #1,-(%a5)        /* a5 is DSP */
    mov.w  #2,-(%a5)
    mov.w  (%a5)+,%d0
    add.w  (%a5)+,%d0
    mov.w  %d0,-(%a5)
    jmp     do_next
entry_002:
e_test:
    dc.b    4
    .ascii  "test"
    .align  2
    dc.w    entry_001
do_test:
    jmp     do_list
    dc.w    
    dc.w    do_nop
    dc.w    do_abc
    dc.w    do_exit
entry_003:
e_pop:
    dc.b    3
    .ascii  "pop"
    .align  2
    dc.w    entry_002
do_pop:
    
    add.w   #2,%a5
    jmp     do_next
entry_004:
e_plus:
    dc.b    1
    .ascii  "+"
    .align  2
    dc.w    entry_003
do_plus:
    
    move.w  (%a5)+,%d0
    add.w   (%a5)+,%d0
    move.w  %d0,-(%a5)
    jmp     do_next
entry_005:
e_nop:
    dc.b    3
    .ascii  "nop"
    .align  2
    dc.w    entry_004
do_nop:
    jmp     do_list
    dc.w    do_exit
entry_006:
e_period:
    dc.b    1
    .ascii  "."
    .align  2
    dc.w    entry_005
do_period:
    
    move.w  (%a5)+,%d0
    jsr     (do_putnum)
    jmp     do_next
entry_007:
e_cr:
    dc.b    2
    .ascii  "cr"
    .align  2
    dc.w    entry_006
do_cr:
    
    move.b  #13,%d0
    jsr     (putch)
    move.b  #10,%d0
    jsr     (putch)
    jmp     do_next
entry_008:
e_atfetch:
    dc.b    1
    .ascii  "@"
    .align  2
    dc.w    entry_007
do_atfetch:
    
    move.w  (%a5),%a0
    move.w  (%a0),%d0
    move.w  %d0,(%a5)
    jmp     do_next
entry_009:
e_exclamation:
    dc.b    1
    .ascii  "!"
    .align  2
    dc.w    entry_008
do_exclamation:
    
    move.w  (%a5)+,%a0
    move.w  (%a5)+,%d0
    move.w  %d0,(%a0)
    jmp     do_next
entry_end:
    .equ entry_head, entry_009
