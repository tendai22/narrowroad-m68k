#! /bin/sh
m68k-elf-objdump -D a.out |sed -n '
/^ *[0-9A-Fa-f][0-9A-Fa-f]*:/{
    s/^\([^	]*\)	\([^	]*\)	.*$/\1 \2/
    s/^ *\([0-9A-Fa-f][0-9A-Fa-f]*\): */=\1 /
    s/  *$//
    s/  */ /g
    p
}
'
