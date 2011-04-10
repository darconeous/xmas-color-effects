
BSTC=bstc
BSTL=bstl

SPIN_LIBRARY_PATH="/Users/darco/Projects/spin-lib"

%.binary: %.spin
	$(BSTC) -L $(SPIN_LIBRARY_PATH) -b $<

%.loadram: %.binary
	$(BSTL) $<

%.loadeeprom: %.binary
	$(BSTL) -p 3 $<

all: main.binary

loadram: main.loadram

loadeeprom: main.loadeeprom

clean:
	$(RM) main.binary

