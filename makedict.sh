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
    dc.w   entry_end
    dc.w   entry_head
EOF
# dict definitions
cat ${SRC} |awk '#
BEGIN {
    nels = 0;
    prev_link = "0"
}
/^word/ || /^code/{
    str = name = $2
    if (NF > 2) {
        name = $3
    }
    n = length(str);
    #print n, str
    body = ""
    i = 0;
    
    next;
}
/endword/ || /endcode/ {
    flag = ($0 ~ /word/);
    printf "entry_%03d:\n", nels;
    printf "e_%s:\n", name
    printf "    dc.b    %d\n", n
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
        s = a[i];

        if (flag == 1) {
            if (s ~ /^[a-zA-Z][a-zA-Z0-9]*/) {
                s = "dc.w    do_" s;
            } else {
                s = "dc.w    " s;
            }
        }
        print "    " s
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
    sub(/^[     ][  ]*/, "", $0);
    if ($0 ~ /^[   ][  ]*$/) {
        next
    }
    body = body "|" $0;
}
END {
    print "entry_end:"
    printf "    .equ entry_head, entry_%03d\n", --nels
}
'
