#
#
#
NAME=narrowroad
OBJDUMP=m68k-elf-objdump
LD=m68k-elf-ld
AS=m68k-elf-as
RM=rm -f

OBJS=$(NAME).o codes.o dict.o
LISTS=$(NAME).dict $(NAME).list $(NAME).X

.s.o:
	$(AS) -o $*.o $*.s

all: $(NAME).X

a.out:  $(OBJS)
	$(LD) -T trip.ldscript $(OBJS)

$(NAME).list:  a.out
	$(OBJDUMP) --start-address=0x1000 --stop-address=0x1fff -D a.out |tee $(NAME).list

$(NAME).dict: a.out
	sh dictdump.sh > $(NAME).dict 

$(NAME).X: a.out
	sh dump.sh > $(NAME).X

dict.s:  base.dict
	sh makedict.sh $*.dict > dict.s

clean: $(OBJS) $(LISTS)
	$(RM) $(OBJS) $(LISTS)
