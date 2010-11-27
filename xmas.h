/*!	Christmas Light Control Header
**	By Robert Quattlebaum <darco@deepdarc.com>
**	Released November 27th, 2010
**
**	For more information,
**	see <http://www.deepdarc.com/2010/11/27/hacking-christmas-lights/>.
**
**	Originally intended for the ATTiny13, but should
**	be easily portable to other microcontrollers.
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
