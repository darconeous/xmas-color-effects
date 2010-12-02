CON
  _clkmode = xtal1 + pll16x
  _clkfreq = 80_000_000                                                      
  cntMin     = 400
DAT
us  long _CLKFREQ/1_000_000
ms  long _CLKFREQ/1_000

PUB Init
  ms    :=       clkfreq / 1_000
  us    :=       clkfreq / 1_000_000
PUB delay_ms(dur)
  waitcnt( (dur * ms-2300 #> cntMin) + cnt )
PUB delay_us(dur)
  waitcnt( (dur * us-2300 #> cntMin) + cnt )
PUB delay_s(dur)
  repeat dur
    delay_ms(1_000)