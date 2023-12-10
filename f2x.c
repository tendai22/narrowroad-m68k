//
// f2x ... convert forth source program to *.X format
//

#include <stdio.h>
#include <inttypes.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

int main(int ac, char **av)
{
    FILE *fp, *op;
    uint16_t addr, start = 0x4000, d;
    int count, c, n;
    unsigned char *bp, *bptop, *htop;
    unsigned short buflen, bufsize;

    if (ac == 1) {
        fprintf(stderr, "usage: %s [-o outfile] files...\n", av[0]);
        exit(2);
    }
    if (ac > 3 && strcmp(av[1], "-o") == 0 && av[2]) {
        // outfile option
        if ((op = fopen(av[2], "w")) == 0) {
            fprintf(stderr, "cannot open outfile: %s\n", av[2]);
            exit(1);
        }
        av += 2;
        ac -= 2;
    } else {
        // put out to stdout
        op = stdout;
    }
    // do files
    int rest = bufsize = 60000;
    if((bptop = bp = malloc(bufsize)) == NULL) {
        fprintf(stderr, "cannot alloc buffer\n");
        fclose(op);
    }
    bp += 2;
    for (int i = 1; rest > 1 && i < ac; ++i) {
        if ((fp = fopen(av[i], "r")) == 0) {
            fprintf(stderr, "cannot open infile: %s\n", av[i]);
            fclose(op);
            exit(1);
        }
        n = fread(bp, sizeof(char), rest,  fp);
        if (n == 0) {
            // end of the file
            fclose(fp);
            continue;
        }
        // okay, got it
        bp += n;
        rest -= n;
    }
    n = bp - bptop;     // file size
    if (n & 1) {
        *bp++ = 0;  // dummy null byte, word alignment achieved
        n++;
    }
    bptop[0] = (n & 0xff00) / 256;
    bptop[1] = n & 0xff;
    // output a *.X file
    start = 0x4000;
    count = n;
    bp = bptop;
    htop = bp;
    int i;
    for (i = 0; i < count; i += 2) {
        if (i % 16 == 0) {
            fprintf(op, "=%04X", start + i);
            htop = bp;
        }
        d = ((unsigned short)bp[0]) * 256 + bp[1];
        fprintf(op, " %04X", d);
        bp += 2;
        if (i % 16 >= 14) {
#if 0
            fprintf(op, "  // ");
            for (int j = 0; j < 16; ++j) {
                c = (' ' <= htop[j] && htop[j] < 0x7f) ? htop[j] : '.'; 
                fputc(c, op);
            }
#endif
            fprintf(op, "\n");
        }
    }
#if 0
    if (i % 16 > 0) {
        fprintf(op, "  // ");
        for (int j = 0; j < 16; ++j) {
            c = (' ' <= htop[j] && htop[j] < 0x7f) ? htop[j] : '.'; 
            fputc(c, op);
        }
    }
#endif
    fprintf(op, "\n");
    fclose(op);
    return 0;
}
