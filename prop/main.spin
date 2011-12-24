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

  xmas_ctrl     : "xmas_ctrl"
  
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

  xmas_ctrl.start

  dira[subsys#SPKRPin]:=!settings.findKey(settings#MISC_SOUND_DISABLE)
  
  if not \socket.start(1,2,3,4,6,7)
    subsys.StatusFatalError
    subsys.chirpSad
    waitcnt(clkfreq*10000 + cnt)
    reboot

  if NOT settings.getData(settings#NET_IPv4_ADDR,@i,4)
    repeat while NOT settings.getData(settings#NET_IPv4_ADDR,@i,4)
      buttonCheck

  subsys.StatusIdle
  subsys.chirpHappy
  
  repeat
    i:=\httpServer
    subsys.StatusOff
    subsys.click
    subsys.FadeToColorBlocking($0,0,0,0)
    delay_ms(300)
    repeat (-i) <# 20
        subsys.FadeToColorBlocking($3F,0,0,0)
        delay_ms(300)
        subsys.FadeToColorBlocking($0,0,0,0)
        delay_ms(300)
    delay_ms(1000)
    subsys.StatusIdle
    socket.closeall
    
PRI delay_ms(Duration)
    waitcnt(((clkfreq / 1_000 * Duration - 3932)) + cnt)

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
  byte httpPath[128]
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

pri buttonCheck
  if ina[subsys#BTTNPin]
    repeat while ina[subsys#BTTNPin]
    xmas_ctrl.toggle_active

pub httpServer | char, i, contentLength,authorized,queryPtr, tmp1, tmp2, tmp3

  repeat
    subsys.StatusIdle
    buttonCheck

    socket.listen(80)

    repeat while NOT socket.isConnected
      socket.waitConnectTimeout(100)
      buttonCheck

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
      elseif strcomp(@httpPath,string("/config"))
        if authorized<>auth#STAT_AUTH
          httpUnauthorized(authorized)
          socket.close
          next

        if contentLength
          i:=0
          repeat while contentLength AND i<127
            httpPath[i++]:=socket.rxtime(1000)
            contentLength--
          httpPath[i]~
          queryPtr:=@httpPath
         
        if http.getFieldFromQuery(queryPtr,string("AH"),@buffer,127)
          settings.setByte(xmas_ctrl#ON_ALARM_HOUR, atoi(@buffer))  

        if http.getFieldFromQuery(queryPtr,string("AM"),@buffer,127)
          settings.setByte(xmas_ctrl#ON_ALARM_MIN, atoi(@buffer))  

        if http.getFieldFromQuery(queryPtr,string("aH"),@buffer,127)
          settings.setByte(xmas_ctrl#OFF_ALARM_HOUR, atoi(@buffer))  

        if http.getFieldFromQuery(queryPtr,string("aM"),@buffer,127)
          settings.setByte(xmas_ctrl#OFF_ALARM_MIN, atoi(@buffer))  

        if http.getFieldFromQuery(queryPtr,string("CH"),@buffer,127)
            tmp1 := atoi(@buffer)
            tmp2 := xmas_ctrl.get_current_minute
            if http.getFieldFromQuery(queryPtr,string("CM"),@buffer,127)
                tmp2 := atoi(@buffer)
            xmas_ctrl.set_time_of_day(tmp1,tmp2,xmas_ctrl.get_current_second)
            
        xmas_ctrl.refresh_alarm_settings
         
        settings.removeKey($1010)
        settings.removeKey(settings#MISC_STAGE2)
        settings.commit
        
        socket.str(@HTTP_303)
        socket.str(string("Location: /",13,10))
        socket.str(@HTTP_CONNECTION_CLOSE)
        socket.str(@CR_LF)
        socket.str(string("OK",13,10))

      elseif strcomp(@httpPath,string("/commit"))
        if authorized<>auth#STAT_AUTH
          httpUnauthorized(authorized)
          socket.close
          next
        socket.str(@HTTP_303)
        socket.str(string("Location: /",13,10))
        socket.str(@HTTP_CONNECTION_CLOSE)
        socket.str(@CR_LF)
        settings.commit
        socket.str(string(" OK",13,10))
      elseif strcomp(@httpPath,string("/xmas"))
        if authorized<>auth#STAT_AUTH
          httpUnauthorized(authorized)
          socket.close
          next
        socket.str(@HTTP_303)
        socket.str(string("Location: /",13,10))
        socket.str(@HTTP_CONNECTION_CLOSE)
        socket.str(@CR_LF)
        
        if http.getFieldFromQuery(queryPtr,string("prg"),@buffer,127)
          i:=atoi(@buffer)
            if i==0
                xmas_ctrl.set_active(FALSE)
            else
                xmas_ctrl.set_program(i)
                xmas_ctrl.set_active(TRUE)
        if http.getFieldFromQuery(queryPtr,string("color"),@buffer,127)
            i:=numbers.FromStr(@buffer,numbers#HEX)
            xmas_ctrl.set_solid_color(i)
            
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



pri indexPage | i,j

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
  socket.dec(subsys.uptime/3600)
  socket.tx("h")
  socket.dec(subsys.uptime/60//60)
  socket.tx("m")
  socket.dec(subsys.uptime//60)
  socket.tx("s")
  socket.str(string("</tt></div>"))
  socket.str(string("<div><tt>Hits: "))
  socket.dec(hits)
  socket.str(string("</tt></div>"))
   
  socket.str(string("<h2>Actions</h2>"))
  socket.str(string("<h3>Christmas Lights</h3>"))

  socket.str(string("<p>"))
  httpOutputLink(string("/xmas?prg=1"),string("green button"),string("Rainbow"))
  socket.str(string("</p><p>"))
  httpOutputLink(string("/xmas?prg=2"),string("green button"),string("Color Cycle"))
  socket.str(string("</p><p>"))
  httpOutputLink(string("/xmas?prg=3"),string("green button"),string("Twinkle"))
  socket.str(string("</p><p>"))
  httpOutputLink(string("/xmas?prg=4"),string("green button"),string("red/green stripes"))
  socket.str(string("</p><p>"))
  httpOutputLink(string("/xmas?prg=5"),string("green button"),string("Trail"))
  socket.str(string("</p><p>"))
  httpOutputLink(string("/xmas?prg=6"),string("green button"),string("Simple Chaiser"))
  socket.str(string("</p><p>"))
  httpOutputLink(string("/xmas?prg=7"),string("green button"),string("Solid Color"))
  socket.str(string("</p><p>"))
  httpOutputLink(string("/xmas?prg=8"),string("green button"),string("RGB Plasma"))
  socket.str(string("</p><p>"))
  httpOutputLink(string("/xmas?prg=9"),string("green button"),string("Fire Plasma"))
  socket.str(string("</p><p>"))
  httpOutputLink(string("/xmas?prg=10"),string("green button"),string("Ice Plasma"))
  socket.str(string("</p><p>"))
  httpOutputLink(string("/xmas?prg=11"),string("green button"),string("Hue Plasma"))
  socket.str(string("</p><p>"))
  httpOutputLink(string("/xmas?prg=12"),string("green button"),string("RWG Plasma"))
  socket.str(string("</p><p>"))
  httpOutputLink(string("/xmas?prg=0"),string("red button"),string("Turn Off"))
  socket.str(string("</p><p>"))
  httpOutputLink(string("/commit"),string("yellow button"),string("Save Settings"))
    
  socket.str(string("</p>"))

  socket.str(string("<h2>Settings</h2>"))
  socket.str(string("<form action='/config' method='GET'>"))
        socket.str(string("Current time: <br> <select name='CH' size='1'>"))
        j :=  xmas_ctrl.get_current_hour
        repeat i from 0 to 23
          socket.str(string("<option value="))
          socket.dec(i)
          if (j == i)
            socket.str(string(" SELECTED "))
          socket.str(string(">"))
          socket.dec(i)
          socket.str(string("</option>"))
        socket.str(string("</select> : <select name='CM' size='1'>"))
        j :=  xmas_ctrl.get_current_minute  
        repeat i from 0 to 59
          socket.str(string("<option value="))
          socket.dec(i)
          if (j == i)
            socket.str(string(" SELECTED "))
          socket.str(string(">"))
          socket.dec(i)
          socket.str(string("</option>"))
        socket.str(string("</select> <br>"))


        socket.str(string("On alarm time: <br> <select name='AH' size='1'>"))
        j :=  settings.getByte(xmas_ctrl#ON_ALARM_HOUR)
        repeat i from 0 to 23
          socket.str(string("<option value="))
          socket.dec(i)
          if (j == i)
            socket.str(string(" SELECTED "))
          socket.str(string(">"))
          socket.dec(i)
          socket.str(string("</option>"))
        socket.str(string("</select> : <select name='AM' size='1'>"))
        j :=  settings.getByte(xmas_ctrl#ON_ALARM_MIN)  
        repeat i from 0 to 59
          socket.str(string("<option value="))
          socket.dec(i)
          if (j == i)
            socket.str(string(" SELECTED "))
          socket.str(string(">"))
          socket.dec(i)
          socket.str(string("</option>"))
        socket.str(string("</select> <br>"))

        socket.str(string("Off alarm time: <br> <select name='aH' size='1'>"))
        j :=  settings.getByte(xmas_ctrl#OFF_ALARM_HOUR)
        repeat i from 0 to 23
          socket.str(string("<option value="))
          socket.dec(i)
          if (j == i)
            socket.str(string(" SELECTED "))
          socket.str(string(">"))
          socket.dec(i)
          socket.str(string("</option>"))
        socket.str(string("</select> : <select name='aM' size='1'>"))
        j :=  settings.getByte(xmas_ctrl#OFF_ALARM_MIN)  
        repeat i from 0 to 59
          socket.str(string("<option value="))
          socket.dec(i)
          if (j == i)
            socket.str(string(" SELECTED "))
          socket.str(string(">"))
          socket.dec(i)
          socket.str(string("</option>"))
        socket.str(string("</select> <br>"))

  socket.str(string("<input name='submit' type='submit' />"))
  socket.str(string("</form>"))

  socket.str(string("<h3>System</h3>"))
  socket.str(string("</p><p>"))
  httpOutputLink(string("/reboot"),string("black button"),string("Reboot"))
  socket.str(string("</p>"))
  
  socket.str(string("<h2>Other</h2>"))
  httpOutputLink(@productURL,0,@productURL)
   
  socket.str(string("</body></html>",13,10))


