#! /bin/sh
m68k-elf-objdump -t a.out |
    awk '$5 ~ /^bp[0-9]/{ print $1,$5 }
         $5 ~ /^q[qr][0-9]/{ print $1,$5 } ' |tee xx|
    sed 's/^0*\(....\) b.*/P\1/
        s/^0*\(....\) qq.*/Q\1/
        s/^0*\(....\) qr.*/R\1/'