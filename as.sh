#! /bin/sh
b=`basename -s .s "$1"`
m68k-elf-as -o ${b}.o "$1" &&
m68k-elf-ld -T trip.ldscript ${b}.o &&
( m68k-elf-objdump --start-address=0x1000 --stop-address=0x1fff -D a.out | tee ${b}.list )
sh dictdump.sh > xx.ddump