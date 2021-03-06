/*!	Christmas Light Control
**	By Robert Quattlebaum <darco@deepdarc.com>
**	Released November 27th, 2010
**
**	For more information,
**	see <http://www.deepdarc.com/2010/11/27/hacking-christmas-lights/>.
**
**	Originally intended for the ATTiny13, but should
**	be easily portable to other microcontrollers.
**
**	-----------------------------------------------------------------
**
**	This file was written by Robert Quattlebaum <darco@deepdarc.com>.
**
**	This work is provided as-is. Unless otherwise provided in writing,
**	Robert Quattlebaum makes no representations or warranties of any
**	kind concerning this work, express, implied, statutory or otherwise,
**	including without limitation warranties of title, merchantability,
**	fitness for a particular purpose, non infringement, or the absence
**	of latent or other defects, accuracy, or the present or absence of
**	errors, whether or not discoverable, all to the greatest extent
**	permissible under applicable law.
**
**	To the extent possible under law, Robert Quattlebaum has waived all
**	copyright and related or neighboring rights to this work. This work
**	is published from the United States.
**
**	I, Robert Quattlebaum, dedicate any and all copyright interest in
**	this work to the public domain. I make this dedication for the
**	benefit of the public at large and to the detriment of my heirs and
**	successors. I intend this dedication to be an overt act of
**	relinquishment in perpetuity of all present and future rights to
**	this code under copyright law. In jurisdictions where this is not
**	possible, I hereby release this code under the Creative Commons
**	Zero (CC0) license.
**
**	 * <http://creativecommons.org/publicdomain/zero/1.0/>
**
**	See <http://www.deepdarc.com/> for other cool stuff.
*/

#ifndef F_CPU
#define F_CPU	9.6*1000000 // 9.6 MHz, default for ATTINY13A
#endif

#include "xmas.h"
#include <avr/io.h>
#include <util/delay.h>

#define sbi(x,y)	x|=(1<<y)
#define cbi(x,y)	x&=~(1<<y)

#define XMAS_PIN	0
#define XMAS_PORT	PORTB
#define XMAS_DDR	DDRB

static void
xmas_begin() {
	sbi(XMAS_DDR,XMAS_PIN);
	sbi(XMAS_PORT,XMAS_PIN);
	_delay_us(10);
	cbi(XMAS_PORT,XMAS_PIN);
}

static void
xmas_one() {
	cbi(XMAS_PORT,XMAS_PIN);
	_delay_us(20);
	sbi(XMAS_PORT,XMAS_PIN);
	_delay_us(8);
	cbi(XMAS_PORT,XMAS_PIN);
}

static void
xmas_zero() {
	cbi(XMAS_PORT,XMAS_PIN);
	_delay_us(10);
	sbi(XMAS_PORT,XMAS_PIN);
	_delay_us(20);
	cbi(XMAS_PORT,XMAS_PIN);
}

static void
xmas_end() {
	cbi(XMAS_PORT,XMAS_PIN);
	_delay_us(30);
}

void
xmas_set_color(uint8_t led,uint8_t intensity,xmas_color_t color) {
	uint8_t i;
	xmas_begin();
	for(i=6;i;i--,(led<<=1))
		if(led&(1<<5))
			xmas_one();
		else
			xmas_zero();
	for(i=8;i;i--,(intensity<<=1))
		if(intensity&(1<<7))
			xmas_one();
		else
			xmas_zero();
	for(i=12;i;i--,(color<<=1))
		if(color&(1<<11))
			xmas_one();
		else
			xmas_zero();
	xmas_end();
}


xmas_color_t
xmas_color(uint8_t r,uint8_t g,uint8_t b) {
	return XMAS_COLOR(r,g,b);
}

xmas_color_t
xmas_color_hue(uint8_t h) {
	switch(h>>4) {
		case 0:	h-=0; return xmas_color(h,XMAS_CHANNEL_MAX,0);
		case 1:	h-=16; return xmas_color(XMAS_CHANNEL_MAX,(XMAS_CHANNEL_MAX-h),0);
		case 2:	h-=32; return xmas_color(XMAS_CHANNEL_MAX,0,h);
		case 3:	h-=48; return xmas_color((XMAS_CHANNEL_MAX-h),0,XMAS_CHANNEL_MAX);
		case 4:	h-=64; return xmas_color(0,h,XMAS_CHANNEL_MAX);
		case 5:	h-=80; return xmas_color(0,XMAS_CHANNEL_MAX,(XMAS_CHANNEL_MAX-h));
	}
}

