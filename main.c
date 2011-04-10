/*!	Alternative Christmas Light Controller
**	By Robert Quattlebaum <darco@deepdarc.com>
**	Released November 27th, 2010
**
**	For more information,
**	see <http://www.deepdarc.com/2010/11/27/hacking-christmas-lights/>.
**
**	Originally intended for the ATTiny13, but should
**	be easily portable to other microcontrollers.
*/

#ifndef F_CPU
#define F_CPU	9.6*1000000 // 9.6 MHz, default for ATTINY13A
#endif

#include <stdint.h>
#include <stdbool.h>
#include <avr/io.h>
#include <util/delay.h>
#include "xmas.h"

#define XMAS_PROGRAM_OFF			255
#define XMAS_PROGRAM_RAINBOW		1
#define XMAS_PROGRAM_DOUBLE_RAINBOW	2
#define XMAS_PROGRAM_NOW_PLAYING	3
#define XMAS_PROGRAM_SIMPLE_COLOR_CYCLE	4

#define sbi(x,y)	x|=(1<<y)
#define cbi(x,y)	x&=~(1<<y)

static uint8_t i;	// Used as a general purpose loop counter
static uint16_t c;
static uint8_t xmas_program;

#if defined(XMAS_PROGRAM_SIMPLE_COLOR_CYCLE)
static void
update_simple_color_cycle()
{
	xmas_fill_color(
		i,
		XMAS_LIGHT_COUNT,
		XMAS_DEFAULT_INTENSITY,
		xmas_color_hue((c/8)%(XMAS_HUE_MAX+1))
	);
	c++;
}
#endif // #if defined(XMAS_PROGRAM_SIMPLE_COLOR_CYCLE)

#if defined(XMAS_PROGRAM_RAINBOW)
static void
update_rainbow()
{
	for(i=0;i<XMAS_LIGHT_COUNT;i++) {
		xmas_set_color(
			i,
			XMAS_DEFAULT_INTENSITY,
			xmas_color_hue((i+c)%(XMAS_HUE_MAX+1))
		);
	}
	c++;
}
#endif // #if defined(XMAS_PROGRAM_RAINBOW)

#if defined(XMAS_PROGRAM_DOUBLE_RAINBOW)
/*	Bulbs must be enumerated for individual addressing
**	for this program to work properly.
*/
static void
update_double_rainbow()
{
	for(i=0;i<XMAS_LIGHT_COUNT/2;i++) {
		xmas_color_t color = xmas_color_hue((i+c)%(XMAS_HUE_MAX+1));
		xmas_set_color(
			i,
			XMAS_DEFAULT_INTENSITY,
			color
		);
		xmas_set_color(
			XMAS_LIGHT_COUNT-1-i,
			XMAS_DEFAULT_INTENSITY,
			color
		);
	}
	c++;
}
#endif // #if defined(XMAS_PROGRAM_DOUBLE_RAINBOW)

#if defined(XMAS_PROGRAM_NOW_PLAYING)
/*	This program is supposed to look like the
**	old chaser lights that were around the borders
**	of signs. It requires that the bulbs not
**	already be enumerated to work properly.
*/
void
update_now_playing()
{
	static const xmas_color_t color = XMAS_COLOR(15,7,2);
	static const uint8_t increment = 2;
	static const uint8_t upper_limit = XMAS_DEFAULT_INTENSITY/2/increment*increment;
	
	for(c=0;c<upper_limit;c+=increment) {
		xmas_set_color(0,XMAS_DEFAULT_INTENSITY/2+c,color);
		xmas_set_color(1,XMAS_DEFAULT_INTENSITY/2-c,color);
	}
	for(c=upper_limit;c!=0;c-=increment) {
		xmas_set_color(0,XMAS_DEFAULT_INTENSITY/2+c,color);
		xmas_set_color(1,XMAS_DEFAULT_INTENSITY/2-c,color);
	}
	for(c=0;c<upper_limit;c+=increment) {
		xmas_set_color(1,XMAS_DEFAULT_INTENSITY/2+c,color);
		xmas_set_color(0,XMAS_DEFAULT_INTENSITY/2-c,color);
	}
	for(c=upper_limit;c!=0;c-=increment) {
		xmas_set_color(1,XMAS_DEFAULT_INTENSITY/2+c,color);
		xmas_set_color(0,XMAS_DEFAULT_INTENSITY/2-c,color);
	}
}
#endif // #if defined(XMAS_PROGRAM_NOW_PLAYING)

int
main(void)
{
	// Enumerate the bulbs in the string
	// for individual addressing.
	xmas_fill_color(
		0,
		XMAS_LIGHT_COUNT,
		0,
		XMAS_COLOR_BLACK
	);
//	xmas_program = XMAS_PROGRAM_NOW_PLAYING;
	while(1) {
		switch(xmas_program) {
			default:
#if defined(XMAS_PROGRAM_RAINBOW)
			case XMAS_PROGRAM_RAINBOW:
				update_rainbow();
				break;
#endif
#if defined(XMAS_PROGRAM_DOUBLE_RAINBOW)
			case XMAS_PROGRAM_DOUBLE_RAINBOW:
				update_double_rainbow();
				break;
#endif
#if defined(XMAS_PROGRAM_NOW_PLAYING)
			case XMAS_PROGRAM_NOW_PLAYING:
				update_now_playing();
				break;
#endif
#if defined(XMAS_PROGRAM_SIMPLE_COLOR_CYCLE)
			case XMAS_PROGRAM_SIMPLE_COLOR_CYCLE:
				update_simple_color_cycle();
				break;
#endif
			case XMAS_PROGRAM_OFF:
				break;
		}
	}
}
