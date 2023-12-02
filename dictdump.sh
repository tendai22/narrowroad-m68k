#!/bin/sh
#
# dict image
#
OBJFILE=a.out

m68k-elf-objdump --start-address=0x2000 -s "${OBJFILE}" |
sed '1,/Contents/d
s/^ \([0-9a-f][0-9a-f]*\) \([0-9a-f][0-9a-f]*\) \([0-9a-f][0-9a-f]*\) \([0-9a-f][0-9a-f]*\) \([0-9a-f][0-9a-f]*\) .*$/=\1\
  \2\
  \3\
  \4\
  \5/
s/^ \([0-9a-f][0-9a-f]*\) \([0-9a-f][0-9a-f]*\) \([0-9a-f][0-9a-f]*\) \([0-9a-f][0-9a-f]*\)      *.*$/=\1\
  \2\
  \3\
  \4/
s/^ \([0-9a-f][0-9a-f]*\) \([0-9a-f][0-9a-f]*\) \([0-9a-f][0-9a-f]*\)      *.*$/=\1\
  \2\
  \3/
s/^ \([0-9a-f][0-9a-f]*\) \([0-9a-f][0-9a-f]*\)          *.*$/=\1\
  \2/' |
sed '
s/  \([0-9a-f][0-9a-f]\)\([0-9a-f][0-9a-f]\)\([0-9a-f][0-9a-f]\)\([0-9a-f][0-9a-f]\)/  \1\
  \2\
  \3\
  \4/
s/  \([0-9a-f][0-9a-f]\)\([0-9a-f][0-9a-f]\)\([0-9a-f][0-9a-f]\)/  \1\
  \2\
  \3/
s/  \([0-9a-f][0-9a-f]\)\([0-9a-f][0-9a-f]\)/  \1\
  \2/
' > a.dict
#
# symbol table
#
m68k-elf-objdump -t "${OBJFILE}" |awk '
$3 !~ /\.text/ {  next; }
{ print $1, $5; }
' |sort |sed 's/^0000\([0-9a-f][0-9a-f][0-9a-f][0-9a-f]\) /\1 /' |
awk '{ printf "table[\"%s\"] = \"%s\"\n", $1, $2; }' > a.symbols
#
# generate final shell script, and ...
#
( cat <<"EOF"
./dictdump 2>/dev/null a.dict |
awk 'BEGIN {
EOF
cat a.symbols
cat <<"EOF"
}
$2 ~ /^[0-9][0-9]*,/ {
    head = $2
    sub("^[0-9][0-9]*,","### ", head)
    printf "\n%s\n",head
}
$3 ~ /(link)/ {
    print
    next
}
{   
    sym = table[$2];
    if (sym == "") {
        printf "%4s    %-8s %s %s\n",$1,$2,$3,""
    } else {
        printf "%4s    %-8s %s %s\n",$1,sym,$2,$3
    }
}'
EOF
) |sh # do it #> xxx.sh
