#include <stdio.h>

int ishex(int c)
{
    return (('0' <= c && c <= '9') || ('a' <= c && c <= 'f'));
}

int tohex(int c)
{
    if ('0' <= c && c <= '9')
        return c - '0';
    if ('a' <= c && c <= 'f')
        return c - 'a' + 10;
    return 0;
}

int readchar(FILE *fp)
{
    int c, d, count = 0, skip = 0;
    d = 0;
    while ((c = fgetc(fp)) != EOF) {
        if (c == '=') {
            skip = 5;
        }
        if (skip-- > 0) {
            continue;
        }

        if (!ishex(c)) {
            continue;
        }
        // ishex char
        c = tohex(c);
        d *= 16;
        d |= c;
        if (++count >= 2) {
            //fprintf(stderr,"[%02X]\n", d);
            return d;
        }
        /* wait for 2nd character */
    }
    /* exit loop only of it is EOF */
    return EOF;
}

#define MAXENTRY 100
typedef unsigned short word_t;

static unsigned char buf[4096];
static word_t entries[MAXENTRY];
static int base, end, head;
static int max_entry;

static word_t get_word(word_t i)
{
    i -= base;
    return ((int)buf[i])*256 + buf[i + 1];
}

static char get_byte(word_t i)
{
    return buf[i - base];
}

static word_t prev_entry(word_t wp)
{
    int n = get_byte(wp);
    word_t w;
    n = (n + 2) / 2;    // word length
    /*fprintf(stderr, "%04X+2*%d\n", wp, n);*/
    w = get_word(wp + 2 * n);
    return w;
}

static void dump_entry(word_t begin, int size)
{
    int index = 0, i, nstr;
    //fprintf(stderr, "(%x,%x)\n", begin, begin + size);
    // parse string
    nstr = get_byte(begin + index);
    index++;
    printf("%04X    %d,\"", begin, nstr);
    for (i = 0; i < nstr; ++i) {
        printf("%c", get_byte(begin + index + i));
    }
    index = ((nstr + 2) / 2) * 2;
    printf("\"\n");
    printf("%04x    %04x (link)\n", begin + index, get_word(begin + index));
    index += 2;
    printf("%04x    %04x (code)\n", begin + index, get_word(begin + index));
    index += 2;
    for (i = index; i < size; i += 2) {
        printf("%04x    %04x\n", begin + i, get_word(begin + i));
    }
}

int main(int ac, char **av)
{
    int c, len;
    word_t w;
    unsigned char *p = &buf[0];
    while (p < &buf[4096] && ((c = readchar(stdin)) != EOF))
        *p++ = c;
    // get header addresses
    len = p - &buf[0];
    base = 0;
#if 0 
    for (int i = 0; i < len; i += 2) {
        if ((i % 16) == 0)
            fprintf(stderr,"%04X: ", i + 0x2000);
        w = get_word(i);
        fprintf(stderr,"%04X ", w);
        if (((i + 2) % 16) == 0)
            fprintf(stderr,"\n");
    }
#endif
    base = 0;
    base = get_word(0);
    end =  get_word(base + 2);
    head = get_word(base + 4);
    fprintf (stderr, "base = %x, end = %x, head = %x\n", base, end, head);
    // gather entry addresses
    int i;
    word_t wp = head;
    entries[0] = end;
    for (i = 1; base <= wp && i < MAXENTRY; ++i) {
        /*fprintf(stderr, "%04X:\n", wp);*/
        entries[i] = wp;
        wp = prev_entry(wp);
    }
    max_entry = i;
    // Now we get word address list, in reverse order
    // dump them
    for (i = max_entry - 1; 0 < i; --i) {
        wp = entries[i];
        /*fprintf (stderr, "%04X\n", wp);*/
        dump_entry(wp, entries[i - 1] - wp);
    }
}