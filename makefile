#
#
#
NAME=narrowroad
OBJDUMP=m68k-elf-objdump
LD=m68k-elf-ld
AS=m68k-elf-as
RM=rm -f

OBJS=codes.o dict.o
LISTS=$(NAME).dict $(NAME).list $(NAME).X
TMPS=dict.s a.dict a.out a.symbols codes.list dict.list

.s.o:
	$(AS) -a=$*.list -o $*.o $*.s

.f.X:
	./f2x -o $*.X $*.f

all: $(NAME).X bp.X $(NAME).dict $(NAME).list forth.X

a.out:  $(OBJS)
	$(LD) -T trip.ldscript $(OBJS)

$(NAME).list:  a.out
	$(OBJDUMP) --start-address=0x1000 --stop-address=0x1fff -D a.out |tee $(NAME).list

$(NAME).dict: a.out dictdump
	sh dictdump.sh > $(NAME).dict 

$(NAME).X: a.out
	sh dump.sh > $(NAME).X

bp.X: a.out
	sh extract_bp.sh > bp.X

forth.X: forth.f
	./f2x -o forth.X forth.f

dict.s:  base.dict makedict.sh
	sh makedict.sh > dict.s

dictdump: dictdump.c
	cc -o dictdump dictdump.c

clean:
	$(RM) $(OBJS) $(LISTS)
