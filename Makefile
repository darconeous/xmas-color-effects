
DEVICE=attiny13a

CC=avr-gcc -mmcu=$(DEVICE)
OBJCOPY=avr-objcopy
CFLAGS=-Os
AVRDUDE=avrdude -p ${DEVICE} -P usb
DFUPROGRAMMER=dfu-programmer

all: main.hex

clean:
	$(RM) main.o main.elf xmas.o main.hex

burn: main.hex
	$(AVRDUDE) -U flash:w:main.hex

main.o: main.c

xmas.o: xmas.c

main.elf: main.o xmas.o
	$(CC) -o main.elf main.o xmas.o
	avr-size main.elf

main.hex: main.elf
	$(OBJCOPY) -O ihex -R .eeprom -R .fuse -R .signature main.elf main.hex



