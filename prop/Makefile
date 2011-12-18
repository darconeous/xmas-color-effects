
BSTC=bstc
BSTL=bstl

SPIN_LIBRARY_PATH?=~/propeller-library

CURL?=curl

YBOX2_ADDRESS?=172.30.96.91
YBOX2_USERNAME?=admin
YBOX2_PASSWORD?=bubba31337
YBOX2_BASEURL?=http://$(YBOX2_USERNAME):$(YBOX2_PASSWORD)@$(YBOX2_ADDRESS)/

BAUD_RATE?=19200

SERIAL_PORT?=/dev/tty.usbserial-pplu*

%.binary: %.spin
	$(BSTC) -L $(SPIN_LIBRARY_PATH) -b $<

%.load-ram: %.binary
	$(BSTL) $<

%.load-eeprom: %.binary
	$(BSTL) -p 3 $<

%.load-ybox2: %.binary
	$(CURL) --anyauth $(YBOX2_BASEURL)stage2.eeprom?boot -T $<

%.term: %.load-ram
	screen $(SERIAL_PORT) $(BAUD_RATE)

%.cu: %.load-ram
	# We do this weird sleep thing here so we can kill the terminal
	# easily with a CTRL-C. Without it, 'cu' eats the CTRL-C.
	sleep 100000 | cu -l $(SERIAL_PORT) -s $(BAUD_RATE)

all: main.binary

load-ram: main.load-ram

load-eeprom: main.load-eeprom

load-ybox2: main.load-ybox2

ybox2-bootloader:
	$(CURL) --anyauth $(YBOX2_BASEURL)reboot?bootloader

term: main.term

cu: main.cu

clean:
	$(RM) -f main.binary

###############################
# Dependencies listed below
#

main.binary: main.spin Fast_I2C_Driver.spin MD5.spin api_telnet_serial.spin auth_basic.spin auth_digest.spin base16.spin base64.spin driver_enc28j60.spin driver_socket.spin http.spin pause.spin qring.spin settings.spin subsys.spin xmas.spin xmas_ctrl.spin
