obj
  pause : "pause"
CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000
var
  byte cog
  long command
pub start | i,j
  init(12)
  pause.Init
  repeat
    i++
    pause.delay_ms(10)
    repeat j from 0 to 49
      set_bulb(j,$CC,i+j)

pub init(pin)
  gecepin := |< pin
  period_10_us := clkfreq / 1_000_000 * 10
  cog := cognew(@cog_init, @command) + 1

pub send_raw_command(x)
  x |= $80000000
  repeat while command
  command := x

pub set_bulb(bulb,intensity,color) | x
  x := bulb
  x <<= 8
  x |= intensity
  x <<= 12
  x |= color
  send_raw_command(x)

DAT
              org
cog_init      or      dira, gecepin                       'pin directions
loop          wrlong  zero,par
:subloop      rdlong  t3,par                    wz      'wait for command
        if_z  jmp     #:subloop

              call    #send_begin
              mov     T4, #26          '     Load number of data bits
              rol     T3, #(32-26)
:sout_loop
              rol     T3, #1 wc
        if_c  call    #send_one
        if_nc call    #send_zero
        
              djnz    t4,             #:sout_loop       '          Decrement t4 ; jump if not Zero

              call    #send_end

              jmp     #loop

send_begin
              mov     T2, period_10_us          ' get initial delay
              add     T2, cnt
              or      outa, gecepin
              waitcnt T2, period_10_us 
              andn      outa, gecepin
send_begin_ret ret

send_one
              waitcnt T2, period_10_us 
              waitcnt T2, period_10_us 
              or      outa, gecepin
              waitcnt T2, period_10_us 
              andn      outa, gecepin
send_one_ret              ret

send_zero
              waitcnt T2, period_10_us 
              or      outa, gecepin
              waitcnt T2, period_10_us 
              waitcnt T2, period_10_us 
              andn      outa, gecepin
send_zero_ret              ret

send_end
              waitcnt T2, period_10_us 
              waitcnt T2, period_10_us 
              waitcnt T2, period_10_us 
send_end_ret              ret

zero          long      0       ' Constant
period_10_us  long      0       ' Set at init time
gecepin       long      0       ' Set at init time

T1            res 1
T2            res 1
T3            res 1
T4            res 1

