{{
        ybox2 - Christmas Light Controller
        http://www.deepdarc.com/ybox2
        http://www.deepdarc.com/2010/11/27/hacking-christmas-lights/

}}
CON

  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000
OBJ

  subsys        : "subsys"
  settings      : "settings"
  socket        : "api_telnet_serial"
  http          : "http"
  base64        : "base64"
  auth          : "auth_basic"

  numbers       : "numbers"

  xmas          : "xmas"
  
VAR
  long xmas_stack[40] 
  long hits
  byte xmas_mode_cog
  
DAT
productName   BYTE      "ybox2 + GE Color Effects",0      
productURL    BYTE      "http://www.deepdarc.com/ybox2/",0

PUB init | i
  dira[subsys#SPKRPin]:=1
    
  hits:=0

  settings.start

  numbers.init
  
  ' If you aren't using this thru the bootloader, set your
  ' settings here. 
  {
  settings.setData(settings#NET_MAC_ADDR,string(02,01,01,01,01,01),6)  
  settings.setLong(settings#MISC_LED_CONF,$010B0A09)
  settings.setByte(settings#NET_DHCPv4_DISABLE,TRUE)
  settings.setData(settings#NET_IPv4_ADDR,string(192,168,2,10),4)
  settings.setData(settings#NET_IPv4_MASK,string(255,255,255,0),4)
  settings.setData(settings#NET_IPv4_GATE,string(192,168,2,1),4)
  settings.setData(settings#NET_IPv4_DNS,string(4,2,2,4),4)
  settings.setByte(settings#MISC_SOUND_DISABLE,TRUE)
  }

  settings.removeKey(settings#MISC_STAGE2)

  subsys.init

  subsys.StatusLoading

  start_xmas

  dira[subsys#SPKRPin]:=!settings.findKey(settings#MISC_SOUND_DISABLE)
  
  if not \socket.start(1,2,3,4,6,7)
    subsys.StatusFatalError
    subsys.chirpSad
    waitcnt(clkfreq*10000 + cnt)
    reboot

  if NOT settings.getData(settings#NET_IPv4_ADDR,@i,4)
    repeat while NOT settings.getData(settings#NET_IPv4_ADDR,@i,4)
      if ina[subsys#BTTNPin]
        reboot
      delay_ms(500)

  subsys.StatusIdle
  subsys.chirpHappy
  
  repeat
    i:=\httpServer
    subsys.StatusOff
    subsys.click
    subsys.FadeToColorBlocking($0,0,0,0)
    delay_ms(300)
    repeat -i <# 20
        subsys.FadeToColorBlocking($3F,0,0,0)
        delay_ms(300)
        subsys.FadeToColorBlocking($0,0,0,0)
        delay_ms(300)
    delay_ms(1000)
    subsys.StatusIdle
    socket.closeall
    
PRI delay_ms(Duration)
    waitcnt(((clkfreq / 1_000 * Duration - 3932)) + cnt)

PRI start_xmas
    stop_xmas
    xmas.start(12)
    xmas.set_standard_enum
    xmas_mode_cog := cognew(xmas_loop, @xmas_stack) + 1

PRI xmas_loop | i,j
    ' This code makes an animated rainbow.
    repeat
        i++
        repeat j from 0 to xmas#MAX_BULB
            xmas.set_bulb(j,xmas#DEFAULT_INTENSITY,xmas.make_color_hue((i+j)//constant(xmas#MAX_HUE+1)))

PRI start_xmas2
    stop_xmas
    xmas.start(12)
    xmas.set_standard_enum
    xmas_mode_cog := cognew(xmas_loop2, @xmas_stack) + 1

PRI xmas_loop2 | i,j
    repeat
        i++
        repeat j from 0 to xmas#MAX_BULB
            xmas.set_bulb(j,xmas#DEFAULT_INTENSITY,xmas.make_color_hue((i)//constant(xmas#MAX_HUE+1)))

PRI start_xmas3
    stop_xmas
    xmas.start(12)
    xmas.set_standard_enum
    xmas_mode_cog := cognew(xmas_loop3, @xmas_stack) + 1

PRI xmas_loop3 | i,i2,j,j2,count,intensity
    ' Twinkle
    count:=14
    repeat
        i *= 37
        i += 13
        i //= 64
        repeat j from xmas#MAX_INTENSITY/count to 0
            'delay_ms(1)
            i2 := i
            repeat j2 from 0 to count-1
                i2 *= 37
                i2 += 13
                i2 //= 64
                if i2 <> xmas#BROADCAST_BULB
                    intensity := j+(xmas#MAX_INTENSITY/count)*j2
                    'xmas.set_bulb(i2,intensity*intensity/255,$7BF)
                    xmas.set_bulb(i2,intensity*intensity/255,$FFF)

PRI start_xmas4
    stop_xmas
    xmas.start(12)
    xmas.set_standard_enum
    xmas_mode_cog := cognew(xmas_loop4, @xmas_stack) + 1

PRI xmas_loop4 | i,j
    ' red/green stripes
    repeat
        delay_ms(10)
        i++
        repeat j from 0 to xmas#MAX_BULB
            if ((j+i)/5)&1
                xmas.set_bulb(j,xmas#DEFAULT_INTENSITY,xmas#COLOR_RED)
            else
                xmas.set_bulb(j,xmas#DEFAULT_INTENSITY,xmas#COLOR_GREEN)

PRI start_xmas5
    stop_xmas
    xmas.start(12)
    xmas.set_standard_enum
    xmas_mode_cog := cognew(xmas_loop5, @xmas_stack) + 1

PRI xmas_loop5 | i,i2,j,j2,count,intensity
    ' Trail
    count:=6
    repeat
        i ++
        i //= 50
        repeat j from xmas#MAX_INTENSITY/count to 0
            'delay_ms(1)
            i2 := i
            repeat j2 from 0 to count-1
                i2 ++
                i2 //= 50
                if i2 <> xmas#BROADCAST_BULB
                    intensity := j+(xmas#MAX_INTENSITY/count)*j2
                    xmas.set_bulb(i2,intensity*intensity/255,xmas#COLOR_WHITE)

{
    ' other stripes
    msec := clkfreq/5
    repeat
        repeat j from 0 to xmas#MAX_BULB
            if ((cnt+msec*(j*j/xmas#MAX_BULB))/clkfreq)&1
                xmas.set_bulb(j,xmas#DEFAULT_INTENSITY,xmas#COLOR_RED)
            else
                xmas.set_bulb(j,xmas#DEFAULT_INTENSITY,xmas#COLOR_GREEN)
}

PRI start_xmas6
    stop_xmas
    xmas.start(12)
    xmas.set_standard_enum
    xmas_mode_cog := cognew(xmas_loop6, @xmas_stack) + 1

PRI xmas_loop6 | i,j,fading_intensity
    ' simple chaser
    repeat
        repeat i from 0 to xmas#DEFAULT_INTENSITY step 16
            fading_intensity := xmas#DEFAULT_INTENSITY-i
            fading_intensity *= fading_intensity
            fading_intensity /= xmas#DEFAULT_INTENSITY
            repeat j from 0 to 49
                if j&1
                    xmas.set_bulb(j,(i*3)<#xmas#DEFAULT_INTENSITY,$27F)
                else
                    xmas.set_bulb(j,fading_intensity,$27F)
        repeat j from 0 to 49
            if j&1
                xmas.set_bulb(j,xmas#DEFAULT_INTENSITY,$27F)
            else
                xmas.set_bulb(j,0,$27F)
        delay_ms(250)
        repeat i from 0 to xmas#DEFAULT_INTENSITY step 16
            fading_intensity := xmas#DEFAULT_INTENSITY-i
            fading_intensity *= fading_intensity
            fading_intensity /= xmas#DEFAULT_INTENSITY
            repeat j from 0 to 49
                ifnot j&1
                    xmas.set_bulb(j,(i*3)<#xmas#DEFAULT_INTENSITY,$27F)
                else
                    xmas.set_bulb(j,fading_intensity,$27F)
        repeat j from 0 to 49
            ifnot j&1
                xmas.set_bulb(j,xmas#DEFAULT_INTENSITY,$27F)
            else
                xmas.set_bulb(j,0,$27F)
        delay_ms(250)





PRI stop_xmas
    if xmas_mode_cog
        cogstop(xmas_mode_cog~ - 1)
        xmas.set_standard_enum  

PUB atoi(inptr):retVal | i,char
  retVal~
  
  ' Skip leading whitespace
  repeat while BYTE[inptr] AND BYTE[inptr]==" "
    inptr++
   
  repeat 10
    case (char := BYTE[inptr++])
      "0".."9":
        retVal:=retVal*10+char-"0"
      OTHER:
        quit
           
VAR
  byte httpMethod[8]
  byte httpPath[64]
  byte httpQuery[64]
  byte httpHeader[32]
  byte buffer[128]
  byte buffer2[128]

DAT
HTTP_200      BYTE      "HTTP/1.1 200 OK"
CR_LF         BYTE      13,10,0
HTTP_303      BYTE      "HTTP/1.1 303 See Other",13,10,0
HTTP_404      BYTE      "HTTP/1.1 404 Not Found",13,10,0
HTTP_411      BYTE      "HTTP/1.1 411 Length Required",13,10,0
HTTP_501      BYTE      "HTTP/1.1 501 Not Implemented",13,10,0
HTTP_401      BYTE      "HTTP/1.1 401 Authorization Required",13,10,0

HTTP_CONTENT_TYPE_HTML  BYTE "Content-Type: text/html; charset=utf-8",13,10,0
HTTP_CONNECTION_CLOSE   BYTE "Connection: close",13,10,0
pri httpUnauthorized(authorized)
  socket.str(@HTTP_401)
  socket.str(@HTTP_CONNECTION_CLOSE)
  auth.generateChallenge(@buffer,127,authorized)
  socket.txMimeHeader(string("WWW-Authenticate"),@buffer)
  socket.str(@CR_LF)
  socket.str(@HTTP_401)

pub httpServer | char, i, contentLength,authorized,queryPtr, tmp1, tmp2, tmp3

  repeat
    subsys.StatusIdle
    if ina[subsys#BTTNPin]
      reboot

    socket.listen(80)

    repeat while NOT socket.isConnected
      socket.waitConnectTimeout(100)
      if ina[subsys#BTTNPin]
        reboot

    subsys.StatusActivity

    ' If there isn't a password set, then we are by default "authorized"
    authorized:=NOT settings.findKey(settings#MISC_PASSWORD)
    
    http.parseRequest(socket.handle,@httpMethod,@httpPath)
    
    contentLength:=0
    repeat while http.getNextHeader(socket.handle,@httpHeader,32,@buffer,128)
      if strcomp(@httpHeader,string("Content-Length"))
        contentLength:=numbers.fromStr(@buffer,numbers#DEC)
      elseif NOT authorized AND strcomp(@httpHeader,string("Authorization"))
        authorized:=auth.authenticateResponse(@buffer,@httpMethod,@httpPath)

    ' Authorization check
    ' You can comment this out if you want to
    ' be able to let unauthorized people see the
    ' front page.
    {
    if authorized<>auth#STAT_AUTH
      httpUnauthorized(authorized)
      socket.close
      next
    }
               
    queryPtr:=http.splitPathAndQuery(@httpPath)         
    if strcomp(@httpMethod,string("GET"))
      hits++
      if strcomp(@httpPath,string("/"))
        socket.str(@HTTP_200)
        socket.str(@HTTP_CONTENT_TYPE_HTML)
        socket.str(@HTTP_CONNECTION_CLOSE)
        socket.str(@CR_LF)
        indexPage
      elseif strcomp(@httpPath,string("/reboot"))
        if authorized<>auth#STAT_AUTH
          httpUnauthorized(authorized)
          socket.close
          next
        if strcomp(queryPtr,string("bootloader")) AND settings.findKey(settings#MISC_AUTOBOOT)
          settings.revert
          settings.removeKey(settings#MISC_AUTOBOOT)
          settings.commit
        socket.str(@HTTP_200)
        socket.str(@HTTP_CONNECTION_CLOSE)
        socket.txmimeheader(string("Refresh"),string("12;url=/"))        
        socket.str(@CR_LF)
        socket.str(string("REBOOTING",13,10))
        delay_ms(1000)
        socket.close
        delay_ms(1000)
        reboot
      elseif strcomp(@httpPath,string("/xmas"))
        if authorized<>auth#STAT_AUTH
          httpUnauthorized(authorized)
          socket.close
          next
        socket.str(@HTTP_303)
        socket.str(string("Location: /",13,10))
        socket.str(@HTTP_CONNECTION_CLOSE)
        socket.str(@CR_LF)
        i:=numbers.FromStr(queryPtr,numbers#HEX)
        case i
            1: start_xmas
            2: start_xmas2
            3: start_xmas3
            4: start_xmas4
            5: start_xmas5
            6: start_xmas6
            0: stop_xmas
        socket.str(string(" OK",13,10))
      else           
        socket.str(@HTTP_404)
        socket.str(@HTTP_CONNECTION_CLOSE)
        socket.str(@CR_LF)
        socket.str(@HTTP_404)
    else
      socket.str(@HTTP_501)
      socket.str(@HTTP_CONNECTION_CLOSE)
      socket.str(@CR_LF)
      socket.str(@HTTP_501)
       
    socket.close


pri httpOutputLink(url,class,content)
  socket.str(string("<a href='"))
  socket.strxml(url)
  if class
    socket.str(string("' class='"))
    socket.strxml(class)
  socket.str(string("'>"))
  socket.str(content)
  socket.str(string("</a>"))

pri indexPage | i

  socket.str(string("<html><head><meta name='viewport' content='width=320' /><title>ybox2</title>"))
  socket.str(string("<link rel='stylesheet' href='http://www.deepdarc.com/ybox2.css' />"))
  socket.str(string("</head><body><h1>"))
  socket.str(@productName)
  socket.str(string("</h1>"))
  if settings.getData(settings#NET_MAC_ADDR,@httpMethod,6)
    socket.str(string("<div><tt>MAC: "))
    repeat i from 0 to 5
      if i
        socket.tx(":")
      socket.hex(byte[@httpMethod][i],2)
    socket.str(string("</tt></div>"))
  socket.str(string("<div><tt>Uptime: "))
  socket.dec(subsys.RTC/3600)
  socket.tx("h")
  socket.dec(subsys.RTC/60//60)
  socket.tx("m")
  socket.dec(subsys.RTC//60)
  socket.tx("s")
  socket.str(string("</tt></div>"))
  socket.str(string("<div><tt>Hits: "))
  socket.dec(hits)
  socket.str(string("</tt></div>"))
   
  socket.str(string("<h2>Actions</h2>"))
  socket.str(string("<h3>Christmas Lights</h3>"))
  socket.str(string("<p>"))
  httpOutputLink(string("/xmas?1"),string("green button"),string("Rainbow"))
  socket.str(string("</p><p>"))
  httpOutputLink(string("/xmas?2"),string("green button"),string("Color Cycle"))
  socket.str(string("</p><p>"))
  httpOutputLink(string("/xmas?3"),string("green button"),string("Twinkle"))
  socket.str(string("</p><p>"))
  httpOutputLink(string("/xmas?4"),string("green button"),string("red/green stripes"))
  socket.str(string("</p><p>"))
  httpOutputLink(string("/xmas?5"),string("green button"),string("Trail"))
  socket.str(string("</p><p>"))
  httpOutputLink(string("/xmas?6"),string("green button"),string("Simple Chaiser"))
  socket.str(string("</p><p>"))
  httpOutputLink(string("/xmas?0"),string("red button"),string("Turn Off"))
    
  socket.str(string("</p>"))

  socket.str(string("<h3>System</h3>"))
  socket.str(string("</p><p>"))
  httpOutputLink(string("/reboot"),string("black button"),string("Reboot"))
  socket.str(string("</p>"))
  
  socket.str(string("<h2>Other</h2>"))
  httpOutputLink(@productURL,0,@productURL)
   
  socket.str(string("</body></html>",13,10))