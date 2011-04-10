
BSTC=bstc

SPIN_LIBRARY_PATH="/Users/darco/Projects/spin-lib"

%.binary: %.spin
	$(BSTC) -L $(SPIN_LIBRARY_PATH) -b $<

all: main.binary


