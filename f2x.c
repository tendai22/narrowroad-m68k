//
// f2x ... convert forth source program to *.X format
//

#include <stdio.h>
#include <inttypes.h>
#include <stdlib.h>
#include <string.h>

int main(int ac, char **av)
{
    FILE *fp, *op;
    uint16_t addr, start = 0x4000, d;
    int count, c;

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
    start = 0x4000;
    addr = start + 2;
    count = 0;
    for (int i = 1; i < ac; ++i) {
        if ((fp = fopen(av[i], "r")) == 0) {
            fprintf(stderr, "cannot open infile: %s\n", av[i]);
            fclose(op);
            exit(1);
        }
        while (1) {
            if ((c = fgetc(fp)) != EOF) {
                d = c;
                d <<= 8;
                d &= 0xff00;
            } else {
                if (count % 16 != 0) {
                    fprintf(op, "\n");
                }
                break;
            }

            if ((c = fgetc(fp)) != EOF) {
                d |= c;
            }
            if (count == 0) {
                fprintf(op, "=%04x\n", addr);
            }
            fprintf(op, " %04x", d);
            count += 2;
            if (count % 16 == 0) {
                fprintf(op, "\n");
            }
            if (c == EOF)
                break;
        }
        fclose(fp);
    }
    if (count > 0) {
        fprintf(op, "\n=%04x %04x\n", start, count);
    }
    fclose(op);
    return 0;
}
