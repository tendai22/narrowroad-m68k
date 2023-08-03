    /*.org   0x2000 dict_top */
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
    dc.w   do_exit
entry_001:
e_defgh:
    dc.b    5
    .ascii  "defgh"
    .align  2
    dc.w    entry_001
do_defgh:
    
    mov.w  #1,-(%a5)        /* a5 is DSP */
    mov.w  #2,-(%a5)
    mov.w  (%a5)+,%d0
    add.w  (%a5)+,%d0
    mov.w  %d0,-(%a5)
    jmp    do_exit
entry_end:
    .equ entry_head, entry_001
