#! /bin/sh

# makedic.sh ... generate Forth Dictionary assembler source file
SRC="base.dict"

#org
ORG=`cat "$SRC" |sed -n '/^[     ]*org/{
    s/^[     ]*org[     ][  ]*\([^  ][^     ]*\).*$/\1/p
    q
}'`
case "$ORG" in
'')   echo "no org directive, abort">&2; exit 2;;
esac
# prefix
cat <<EOF
    /*.org   $ORG dict_top */
    .section DICT
dict:
    dc.w   dict
    .global here_addr
here_addr:
    dc.w  entry_end
    .global last_addr
last_addr:
    dc.w  entry_head
tail_addr:
    dc.w  entry_end

    /* extern word cfa's */
    .global do_word
    .global do_accept
EOF
# dict definitions
cat ${SRC} |awk '#
BEGIN {
    nels = 0;
    prev_link = "0"
}
{
    # uncomment
    sub(/[  ]*\/\/.*$/, "", $0);
}
/^word / || /^code /{
    mode = $1
    str = name = $2
    precedence = 0
    if (NF > 2) {
        if ($4 ~ /immediate/) {
            precedence = 32
            name = $3
        } else if ($3 ~ /immediate/) {
            precedence = 32
        } else if ($3 ~ /level2/) {
            precedence = 64
        } else {
            name = $3
        }
    }
    len = length(str);
    body = ""
    #len = 0;
    next;
}
/endword/ || /endcode/ {
    flag = ($0 ~ /word/);
    x = len % 2
    #printf "/* len = %d, len % 2 == %d */\n", len, x 
    if (len % 2 == 0) {
        str = str " "
    }
    print ""
    printf "entry_%03d:\n", nels;
    printf "e_%s:\n", name
    printf "    dc.b    %d\n", len + 128 + precedence
    printf "    .ascii  \"%s\"\n", str
    printf "    .align  2\n"
    printf "    dc.w    %s\n", prev_link
    printf "do_%s:\n", name
    if (flag) {
        printf "    jmp     do_list\n"
    }
    # print body
    n = split(body, a, /\|/)
    for (i in a) {
        w = a[i];
        if (w ~ /^$/) {
            continue
        }
        if (mode ~ /^code/) {
            print w
            continue
        }
        s = w
        if (s ~ /^#/) {
            # string
            #print "/* str = " s " */"
            ss = substr(s, 2)
            s = "    dc.w    " ss;
        } else if (s ~ /^L_/) {
            if (s !~ /:$/) {
                s = "    dc.w    " s " - 2 - ."
            }
        } else if (s ~ /^[a-zA-Z][a-zA-Z0-9]*/) {
            s = "    dc.w    do_" s;
        } else {
            s = "    dc.w    " s;
        }
        print s
    }
    if (flag == 1) {
        print "    dc.w    do_exit"
    } else {
        print "    jmp     do_next"
    }
    prev_link = sprintf("entry_%03d", nels);
    nels++;
    next
}
{
    s = $0
    if (mode ~ /^code/) {
        body = body "|" s;
        next
    }
    sub(/^[     ][  ]*/, "", s);
    if (s ~ /^[   ][  ]*$/) {
        next
    }
    # split
    if (s ~ /^lit[  ]/ || s ~ /^bra[  ]/ || s ~ /^bne[  ]/ || s ~ /^beq[    ]/) {
        n= split(s, b, /[     ]*/)
        s = b[1]
        ope = b[2]
        if (s ~ /^bra$/ || s ~ /^bne$/ || s ~ /^beq$/) {
            ope = "L_" ope
        }
        body = body "|" s "|" ope;
    } else if (s ~ /:$/) {
        body = body "|L_" s
    } else { 
        body = body "|" s;
    }
}
END {
    print ""
    print "entry_end:"
    printf "    .equ entry_head, entry_%03d\n", --nels
}
'
