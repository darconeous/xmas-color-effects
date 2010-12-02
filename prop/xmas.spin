{{
**      GE Color Effects Control Object
**      Version 0.2, 2010-12-02
**      by Robert Quattlebaum <darco@deepdarc.com>
**      
**      This object is public domain. You may use it as you see fit.
}}
CON
    CMD_LEN             = 26
    MAX_COLOR_VALUE     = $F
    MAX_HUE             = (MAX_COLOR_VALUE+1)*6-1

    DEFAULT_INTENSITY   = $CC
    MAX_INTENSITY       = $FF
    
    COLOR_MASK          = $FFF
    COLOR_BLACK         = $000
    COLOR_WHITE         = $DDD  ' Default controler uses this value for white
    COLOR_BLUE          = $F00
    COLOR_GREEN         = $0F0
    COLOR_RED           = $00F
    COLOR_CYAN          = COLOR_GREEN|COLOR_BLUE
    COLOR_MAGENTA       = COLOR_RED|COLOR_BLUE
    COLOR_YELLOW        = COLOR_RED|COLOR_GREEN

CON { These constants are needed only for the stand alone test mode. }
    _clkmode    = xtal1 + pll16x
    _xinfreq    = 5_000_000

VAR
    byte cog
    long command

PUB stand_alone_test | i,j
{{ Stand alone test. Used only when you run this object directly. }}
    start(12)
    set_standard_enum
    repeat
        i++
        repeat j from 0 to 49
            set_bulb(j,DEFAULT_INTENSITY,i+j)

PUB start(pin)
{{ Starts the cog for the object using the given pin index for output. }}
    ' Stop the object if it is already running
    stop
    
    ' Set up pin
    gecepin := |< pin
    
    ' Set the timing information
    period_10_us := (clkfreq/1_000_000) * 10
    
    ' Start the cog
    cog := cognew(@cog_init, @command) + 1
    
    ' Make sure the cog actually started
    ifnot cog
        abort -1
        
    return cog

PUB stop
{{ Stops the object. You must call start again before you can use this object. }}
    if cog
        cogstop(cog~ - 1)       ' cog variable is cleared by this statement
    command~

PUB set_standard_enum | i
{{ Performs the standard bulb enumeration for individual bulb control. }} 
    repeat i from 0 to 62
        set_bulb(i,DEFAULT_INTENSITY,COLOR_BLACK)

PUB flush
{{ Wait for any prior command to finish. }}
    repeat while command AND (cog > 0)
    
PUB send_raw_command(x)
{{ Sends a single command, consisting of the 26 least significant bits of x. }} 
    ' We use the most significant bit
    ' to help us determine when the command
    ' has been sent by the cog. This works
    ' because the command length is only 26
    ' bits, and the most significant bit won't
    ' be used otherwise.
    x |= constant(|<31)

    ' Wait for any previous command to finish. 
    flush

    ' Set the command. The cog will notice this
    ' and send it automatically, clearing
    ' the command variable when it is finished.
    command := x

PUB make_color_rgb(r,g,b)
{{ Helper function for converting discrete red, green, and blue values into a single 12 bit color value. }} 
    return (r&MAX_COLOR_VALUE)|((g&MAX_COLOR_VALUE)<<4)|((b&MAX_COLOR_VALUE)<<8)

PUB make_color_hue(hue)
{{ Helper function for creating a color based on a hue value. hue must be between 0 and MAX_HUE. }} 
    case (hue>>4)
        0:  hue &= MAX_COLOR_VALUE
            return make_color_rgb(MAX_COLOR_VALUE,hue,0)
        1:  hue &= MAX_COLOR_VALUE
            return make_color_rgb((MAX_COLOR_VALUE-hue),MAX_COLOR_VALUE,0)
        2:  hue &= MAX_COLOR_VALUE
            return make_color_rgb(0,MAX_COLOR_VALUE,hue)
        3:  hue &= MAX_COLOR_VALUE
            return make_color_rgb(0,(MAX_COLOR_VALUE-hue),MAX_COLOR_VALUE)
        4:  hue &= MAX_COLOR_VALUE
            return make_color_rgb(hue,0,MAX_COLOR_VALUE)
        5:  hue &= MAX_COLOR_VALUE
            return make_color_rgb(MAX_COLOR_VALUE,0,(MAX_COLOR_VALUE-hue))
    return 0

PUB set_bulb(bulb,intensity,color) | x
{{ Convenience function for setting the intensity and color for the specified bulb index. }}
    send_raw_command(((bulb&$3F)<<20)|((intensity&$FF)<<12)|(color&COLOR_MASK))

DAT { Cog Implementation }
            org

cog_init    or      dira, gecepin   ' Initialize output pin direction

loop        wrlong  zero,par        ' Clear out the command

:waitforcmd rdlong  current_command,par wz  ' Wait for command
    if_z    jmp     #:waitforcmd

            ' Load number of data bits
            mov     current_bit, #CMD_LEN

            ' Rotate the bits so that the next bit is at bit zero.
            rol     current_command, #(32-CMD_LEN)

            ' Set up next_cnt
            mov     next_cnt, period_10_us
            add     next_cnt, cnt

            ' Send start pulse
            or      outa, gecepin           ' Output high
            waitcnt next_cnt, period_10_us  ' Wait 10 uSeconds
            andn    outa, gecepin           ' Output low

:output_loop
            rol     current_command, #1 wc

    if_c    waitcnt next_cnt, period_10_us  ' Wait 10 uSeconds
            waitcnt next_cnt, period_10_us  ' Wait 10 uSeconds
            or      outa, gecepin           ' Output high
    if_nc   waitcnt next_cnt, period_10_us  ' Wait 10 uSeconds
            waitcnt next_cnt, period_10_us  ' Wait 10 uSeconds
            andn    outa, gecepin           ' Output low
        
            ' Decrement current_bit ; jump if not Zero
            djnz    current_bit,    #:output_loop

            ' Finish up the frame
            waitcnt     next_cnt, period_10_us  ' Wait 10 uSeconds
            waitcnt     next_cnt, period_10_us  ' Wait 10 uSeconds
            waitcnt     next_cnt, period_10_us  ' Wait 10 uSeconds

            ' Jump back to the start and wait for next command
            jmp     #loop

DAT { Constants }
period_10_us    long    0       ' Set at init time
gecepin         long    0       ' Set at init time
zero            long    0

DAT { Variables }
next_cnt        res     1
current_command res     1
current_bit     res     1