{ WORK IN PROGRESS. }
CON
  ACK      = 0                        ' I2C Acknowledge
  NAK      = 1                        ' I2C No Acknowledge
  Xmit     = 0                        ' I2C Direction Transmit
  Recv     = 1                        ' I2C Direction Receive
  EEPROM   = $A0                      ' I2C EEPROM Device Address


  CMD_BEGIN     = 1<<0
  CMD_WRITE_BYTE= 1<<1
  CMD_WRITE     = 1<<2
  CMD_READ      = 1<<3
  CMD_END       = 1<<4
  CMD_BOOTSTRAP = 1<<5

DAT
cog           long 0
command       long 0
        
PUB start(scl)
  mask_scl := |< scl
  mask_sda := |< (scl+1)
  _start

PRI _start

  dira&=!(mask_scl|mask_sda)
  outa&=!(mask_scl|mask_sda)

  stop
  command~~
  cog := cognew(@init, @command) + 1
  
  'Wait for the cog to start
  ifnot cog
    abort -1

  repeat while command
  reset
  
PUB stop
  if cog
    cogstop(cog~ - 1)
  command~

PUB setcommand(cmd, arg0_, arg1_):startCnt
  command := cmd << 16 + @arg0_                       'write command and pointer
  startCnt := cnt

  if cmd & CMD_BOOTSTRAP
    ' If this was a bootstrap command,
    ' then kill this cog.
    cogstop(cogid)

  repeat while command                                'wait for command to be cleared, signifying receipt
'    if (cnt-startCnt) > clkfreq
'      stop
'      abort -100
  return arg0_
  
PUB bootstrapFromEEPROM(addr_,size)|device
  reset
  device := EEPROM | (addr_ >> 15 & %1110)
  repeat while setcommand(constant(CMD_BEGIN|CMD_WRITE_BYTE),device|Xmit,0)
  setcommand(CMD_WRITE_BYTE,addr_.byte[1],0)
  setcommand(CMD_WRITE_BYTE,addr_.byte[0],0)
  setcommand(constant(CMD_BEGIN|CMD_WRITE_BYTE),device|Recv,0)
  setcommand(constant(CMD_READ|CMD_BOOTSTRAP),0,size)
  
PUB blockReadDevice(device,destaddr,addr_,count): ackBit
  reset
  device |= (addr_ >> 15 & %1110)
  ackbit := (ackbit << 1) | setcommand(constant(CMD_BEGIN|CMD_WRITE_BYTE),device|Xmit,0)
  ackbit := (ackbit << 1) | setcommand(CMD_WRITE_BYTE,addr_.byte[1],0)
  ackbit := (ackbit << 1) | setcommand(CMD_WRITE_BYTE,addr_.byte[0],0)
  ackbit := (ackbit << 1) | setcommand(constant(CMD_BEGIN|CMD_WRITE_BYTE),device|Recv,0)
  ackbit := (ackbit << 1) | setcommand(constant(CMD_READ|CMD_END),destaddr,count)
  if ackbit
    abort ackbit
PUB blockRead(destaddr,addr_,count): ackBit|device
  blockReadDevice(EEPROM,destaddr,addr_,count)
  
PUB blockWriteDevice(device,srcaddr,destaddr,count): ackBit
  reset
  device |= (destaddr >> 15 & %1110)
  ackbit := (ackbit << 1) | setcommand(constant(CMD_BEGIN|CMD_WRITE_BYTE),device|Xmit,0)
  ackbit := (ackbit << 1) | setcommand(CMD_WRITE_BYTE,destaddr.byte[1],0)
  ackbit := (ackbit << 1) | setcommand(CMD_WRITE_BYTE,destaddr.byte[0],0)
  ackbit := (ackbit << 1) | setcommand(constant(CMD_WRITE|CMD_END),srcaddr,count)

  if ackbit
    abort ackbit
PUB blockWriteDeviceDDC(device,srcaddr,destaddr,count): ackBit
  reset
  device |= (destaddr >> 15 & %1110)
  ackbit := (ackbit << 1) | setcommand(constant(CMD_BEGIN|CMD_WRITE_BYTE),device|Xmit,0)
  ackbit := (ackbit << 1) | setcommand(CMD_WRITE_BYTE,destaddr.byte[0],0)
  ackbit := (ackbit << 1) | setcommand(constant(CMD_WRITE|CMD_END),srcaddr,count)

  if ackbit
    abort ackbit

PUB blockWrite(srcaddr,destaddr,count): ackBit|device
  blockWriteDevice(EEPROM,srcaddr,destaddr,count)
PUB reset
  ifnot cog
    _start
  setcommand(constant(CMD_BEGIN|CMD_WRITE_BYTE),$FF,0)
  setcommand(constant(CMD_BEGIN|CMD_END),0,0)
 
PUB busy:isBusy
  reset
  if (isBusy := setcommand(CMD_BEGIN|CMD_WRITE_BYTE,EEPROM|Recv,0))
    setcommand(CMD_END,0,0)
    

DAT
              org
init
              
loop          wrlong  zero,par                          'zero command (tell spin we are done processing)
:subloop      rdlong  t1,par                    wz      'wait for command
        if_z  jmp     #:subloop

              mov     addr, t1                          'used for holding return addr to spin vars
        
              rdlong  eedata, t1                          'arg0
              add     t1, #4
              rdlong  arg1, t1                          'arg1                                             

              mov     lkup, addr                        'get the command var from spin
              shr     lkup, #16                         'extract the cmd from the command var

              mov     t2,#1
              wrlong  t2,addr

              test    lkup, #CMD_BEGIN        wz
        if_nz call    #ee_start
              test    lkup, #CMD_WRITE_BYTE        wz
        if_nz call    #ee_transmit
              test    lkup, #CMD_WRITE        wz
        if_nz call    #write_
              test    lkup, #CMD_READ        wz
        if_nz call    #read_
              test    lkup, #CMD_END        wz
        if_nz call    #ee_stop
              test    lkup, #CMD_BOOTSTRAP        wz
        if_nz jmp    #launch

        if_nc wrlong zero,addr

              call      #delay_1usec
        
error
              jmp #loop                                 ' no cmd found

restart
              mov     smode,#$1FF              'reboot actualy
              clkset  smode                   '(reboot)
               
launch
                        rdword  address,#$0004+2        'if pbase address invalid, shutdown
                        cmp     address,#$0010  wz
        if_nz           jmp     #restart

                        rdbyte  address,#$0004          'if xtal/pll enabled, start up now
                        and     address,#$F8            '..while remaining in rcfast mode
                        clkset  address

:delay                  djnz    time_xtal,#:delay       'allow 20ms @20MHz for xtal/pll to settle

                        rdbyte  address,#$0004          'switch to selected clock
                        clkset  address

                        coginit interpreter             'reboot cog with interpreter

                        ' Stop this cog.
                        cogid   address
                        cogstop address


write_
              mov t1, eedata
              mov t2, arg1
:loop         rdbyte eedata,t1            
              call #ee_transmit
        if_c  jmp #error
              add t1, #1
              djnz t2, #:loop
write__ret    ret

read_
              mov t1, eedata
              mov t2, arg1
:loop         call #ee_receive              
        if_c  jmp #error
              wrbyte eedata, t1
              add t1, #1
              djnz t2, #:loop
read__ret     ret
              

ee_start                mov     bits,#9                 '1      ready 9 start attempts
:loop                   andn    outa,mask_scl           '1(!)   ready scl low
                        or      dira,mask_scl           '1!     scl low
                        call    #delay_1usec                 '4
                        andn    dira,mask_sda           '1!     sda float
                        call    #delay_1usec                 '5
                        or      outa,mask_scl           '1!     scl high
                        call    #delay_1usec                 '4
                        test    mask_sda,ina    wc      'h?h    sample sda
        if_nc           djnz    bits,#:loop             '1,2    if sda not high, loop until done

        if_nc           jmp     #error               '1      if sda still not high, error

                        or      dira,mask_sda           '1!     sda low

                        call    #delay_1usec                 '4
ee_start_ret            
                        ret '1 nc=ack

'
'
' Transmit/receive
'
ee_transmit             shl     eedata,#1               '1      ready to transmit byte and receive ack
                        or      eedata,#%00000000_1     '1
                        jmp     #ee_tr                  '1

ee_receive              mov     eedata,#%11111111_0     '1      ready to receive byte and transmit ack

ee_tr                   mov     bits,#9                 '1      transmit/receive byte and ack
:loop                   test    eedata,#$100    wz      '1      get next sda output state
                        andn    outa,mask_scl           '1!     scl low
                        rcl     eedata,#1               '1      shift in prior sda input state
                        muxz    dira,mask_sda           '1!     sda low/float
                        call    #delay_1usec                 '4
                        test    mask_sda,ina    wc      'h?h    sample sda
                        or      outa,mask_scl           '1!     scl high
                        call    #delay_1usec                 '4
                        djnz    bits,#:loop             '1,2    if another bit, loop

                        and     eedata,#$FF             '1      isolate byte received
ee_receive_ret
ee_transmit_ret         
                        ret '1 nc=ack
'
' Stop
'
ee_stop                 mov     bits,#9                 '1      ready 9 stop attempts
:loop                   andn    outa,mask_scl           '1!     scl low
                        call    #delay_1usec                 '4
                        or      dira,mask_sda           '1!     sda low
                        call    #delay_1usec                 '5
                        or      outa,mask_scl           '1!     scl high
                        call    #delay_1usec                 '3
                        andn    dira,mask_sda           '1!     sda float
                        call    #delay_1usec                 '4
                        test    mask_sda,ina    wc      'h?h    sample sda
        if_nc           djnz    bits,#:loop             '1,2    if sda not high, loop until done

ee_jmp  if_nc           jmp     #error               '1      if sda still not high, error
                        mov     zero,zero wc
ee_stop_ret             ret                             '1
'
'
' Cycle delays
'

delay_1usec             mov     delay_count,#17
:loop                   djnz    delay_count,#:loop
delay_1usec_ret         ret

{
delay5                  nop                             '1
                        nop                             '1
                        nop                             '1
                        nop                             '1
                        nop                             '1
delay4                  nop                             '1
                        nop                             '1
                        nop                             '1
                        nop                             '1
                        nop                             '1
delay3                  nop                             '1
                        nop                             '1
                        nop                             '1
                        nop                             '1
                        nop                             '1
delay2
                        nop                             '1
                        nop                             '1
                        nop                             '1
                        nop                             '1
delay2_ret
delay3_ret
delay4_ret
delay5_ret              ret                             '1
}

'
'
' Constants
'
delay_count             long    0   

time_xtal               long    20 * 20000 / 4 / 1      '20ms (@20MHz, 1 inst/loop)
zero                    long    0
smode                   long    0
'h8000                   long    $8000
interpreter             long    $0001 << 18 + $3C01 << 4 + %0000



mask_scl  long  |<28
mask_sda  long  |<29
t1                      res     1                       '     loop and cog error                          
t2                      res     1                       '     loop and cog error
t3                      res     1                       '     Used to hold DataValue SHIFTIN/SHIFTOUT
t4                      res     1                       '     Used to hold # of Bits
t5                      res     1                       '     Used for temporary data mask

addr                    res     1                       '     Used to hold return address of first Argument passed
lkup                    res     1                       '     Used to hold command lookup

                                                        'arguments passed to/from high-level Spin
arg0                    res     1                       ' bits / start address
arg1                    res     1                       ' value / count                                                          

address                 res     1
'raddress                res     1
bits                    res     1
eedata                  res     1

                        fit
                        