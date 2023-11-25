#! /bin/sh
m68k-elf-objdump -t a.out |
    awk '$5 ~ /^bp[0-9]/{ print $1 }' |
    sed 's/^0*\(....\)$/P\1/'