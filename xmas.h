/*!	Christmas Light Control Header
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

#ifndef __XMAS_H__
#define __XMAS_H__	1

#include <stdint.h>

#define XMAS_LIGHT_COUNT		(50)
#define XMAS_CHANNEL_MAX		(0xF)
#define XMAS_DEFAULT_INTENSITY	(0xCC)
#define XMAS_HUE_MAX			((XMAS_CHANNEL_MAX+1)*6-1)

#define XMAS_COLOR(r,g,b)	((r)+((g)<<4)+((b)<<8))

#define XMAS_COLOR_WHITE	XMAS_COLOR(XMAS_CHANNEL_MAX,XMAS_CHANNEL_MAX,XMAS_CHANNEL_MAX)
#define XMAS_COLOR_BLACK	XMAS_COLOR(0,0,0)
#define XMAS_COLOR_RED		XMAS_COLOR(XMAS_CHANNEL_MAX,0,0)
#define XMAS_COLOR_GREEN	XMAS_COLOR(0,XMAS_CHANNEL_MAX,0)
#define XMAS_COLOR_BLUE		XMAS_COLOR(0,0,XMAS_CHANNEL_MAX)
#define XMAS_COLOR_CYAN		XMAS_COLOR(0,XMAS_CHANNEL_MAX,XMAS_CHANNEL_MAX)
#define XMAS_COLOR_MAGENTA	XMAS_COLOR(XMAS_CHANNEL_MAX,0,XMAS_CHANNEL_MAX)
#define XMAS_COLOR_YELLOW	XMAS_COLOR(XMAS_CHANNEL_MAX,XMAS_CHANNEL_MAX,0)

typedef uint16_t xmas_color_t;

extern void xmas_set_color(uint8_t led,uint8_t intensity,xmas_color_t color);
extern xmas_color_t xmas_color(uint8_t r,uint8_t g,uint8_t b);
extern xmas_color_t xmas_color_hue(uint8_t h);

static inline void
xmas_fill_color(uint8_t begin,uint8_t count,uint8_t intensity,xmas_color_t color)
{
	while(count--)
		xmas_set_color(begin++,intensity,color);
}


#endif // #ifndef __XMAS_H__
