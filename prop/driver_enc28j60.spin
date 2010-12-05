{{
  ENC28J60 Ethernet NIC / MAC Driver
  ----------------------------------
  
  Copyright (C) 2006 - 2007 Harrison Pham

  This file is part of PropTCP.
   
  PropTCP is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 3 of the License, or
  (at your option) any later version.
   
  PropTCP is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.
   
  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.

  ----
  
  Driver Framework / API derived from EDTP Framethrower Fundamental Driver by Fred Eady
  Constant names / Theoretical Code Logic derived from Microchip Technology, Inc.'s enc28j60.c / enc28j60.h files
}}

CON
  version = 3     ' major version
  release = 2     ' minor version

OBJ
  pause : "pause"

CON
' ***************************************
' **       ENC28J60 SRAM Defines       **
' ***************************************
  ' Silicon Revision
  silicon_rev = 4                               ' required silicon revision (current is B5)

  ' ENC28J60 SRAM Usage Constants              
  MAXFRAME = 1518                               ' 6 (src addr) + 6 (dst addr) + 2 (type) + 1500 (data) + 4 (FCS CRC) = 1518 bytes
  
  TX_BUFFER_SIZE = 1518
  TXSTART = 8192 - (TX_BUFFER_SIZE + 8)
  TXEND = TXSTART + (TX_BUFFER_SIZE + 8)
CON
  { Heap explanation:

  The heap is 4KB large, and is broken down into 128 32byte pages.
  A page can either be a part of an allocation or a part
  of free space. The first byte of the first page of either
  free space or an allocation contains metadata. It is of the
  following format:

   ┌─ Free/Alloc'd
    ├─Span Size─┤   * NOTE: Span size is number of pages minus one! 
  [7|6|5|4|3|2|1|0]

  This byte is duplicated as the last byte of the last page
  in an allocation or free space. This allows the heap to be
  traversed in either direction.
  
  When an allocation is requested, the allocator will step thru
  the spans one by one until it finds a free span which is
  greater than or equal to the requested number of pages. If it
  is greater, the span is split in two.

  When an allocation is freed, the allocator will check to see
  if either span in front of or behind it is free, and if so
  it will merge with either (or both) span(s).
  
  }
  HEAP_SIZE = 4096
  HEAP_BEGIN = 8192 - HEAP_SIZE
  HEAP_END = 8192 - 1
  HEAP_PAGE_SIZE = 32

  

  RXSTART = $0000
  RXSTOP = (TXSTART - 2) | $0001                ' must be odd (B5 Errata)
'  RXSTOP = (HEAP_BEGIN - 2) | $0001                ' must be odd (B5 Errata)
  RXSIZE = (RXSTOP - RXSTART + 1)

{
PUB heap_init
  ' Write the leading byte
  setSRAMWritePointer(HEAP_BEGIN)
  wr_sram(constant(HEAP_SIZE/HEAP_PAGE_SIZE))
   
  ' Write the trailing byte
  setSRAMWritePointer(HEAP_END)
  wr_sram(constant(HEAP_SIZE/HEAP_PAGE_SIZE))

PUB heap_alloc(size) | iter,info
  iter:=HEAP_BEGIN
  size:=(size+2)/HEAP_PAGE_SIZE
  repeat while iter<HEAP_END
    setSRAMReadPointer(iter)
    info:=rd_sram
    ifnot (info & constant(1<<7)) OR (info<size)
      if info>size
        ' We need to split first!
        
        ' Write the leading byte
        setSRAMWritePointer(iter+(size+1)*HEAP_PAGE_SIZE)
        wr_sram(info-size-1)

        ' Write the trailing byte
        setSRAMWritePointer(iter+info*HEAP_PAGE_SIZE+HEAP_PAGE_SIZE-1)
        wr_sram(info-size-1)

        info:=size  

      ' Write the leading byte
      setSRAMWritePointer(iter)
      wr_sram(info|constant(1<<7))

      ' Write the trailing byte
      setSRAMWritePointer(iter+info*HEAP_PAGE_SIZE+HEAP_PAGE_SIZE-1)
      wr_sram(info|constant(1<<7))
      
      return iter+1
    iter+=((info&constant((1<<7)-1)+1)*HEAP_PAGE_SIZE)
    
  ' We couldn't find a suitable page!
  abort -1
       
    
PUB heap_free(eptr)| previnfo,info,nextinfo,nextaddr
  eptr--
  setSRAMReadPointer(eptr-1)
  previnfo:=rd_sram
  info:=rd_sram & !(1<<7)

  ' Possibly merge with span before
  if eptr<>HEAP_BEGIN
    ifnot previnfo & constant(1<<7)
      ' Previous span is free, so lets merge these two
      previnfo++
      eptr-=previnfo*HEAP_PAGE_SIZE
      info+=previnfo

  ' Possibly merge with span after
  nextaddr:=eptr+info*HEAP_PAGE_SIZE+HEAP_PAGE_SIZE
  if nextaddr<HEAP_END
    setSRAMReadPointer(nextaddr)
    nextinfo:=rd_sram
    ifnot nextinfo & constant(1<<7)
      info+=nextinfo+1

  ' Write the leading byte
  setSRAMWritePointer(eptr)
  wr_sram(info)
   
  ' Write the trailing byte
  setSRAMWritePointer(eptr+info*HEAP_PAGE_SIZE+HEAP_PAGE_SIZE-1)
  wr_sram(info)
}   
     




DAT                  
  int             long 0 ' For allignment

  'eth_mac         byte    $02, $00, $00, $00, $00, $01

' ***************************************
' **         Global Variables          **
' ***************************************
 
  packetheader
  ph_nextpacket   word 0
  ph_rxlen        word 0
  ph_rec_status   word 0

  tx_end          word 0
        
  packet          byte 0[MAXFRAME]

PUB start(_cs, _sck, _si, _so, _int, xtalout, macptr)
'' Starts the driver (uses 1 cog for spi engine)

  int := _int
  dira[int]~

  spi_start(_cs, _sck, _so, _si)

'  eth_csoff

  ' Since some people don't have 25mhz crystals, we use the cog counters
  ' to generate a 25mhz frequency for the ENC28J60 (I love the Propeller)
  ' Note: This requires a main crystal that is a multiple of 25mhz (5mhz works).
  if xtalout > -1
    SynthFreq(xtalout, 25_000_000)      'determine ctr and frq for xtalout

  pause.delay_ms(50)
  init_ENC28J60

  ' write mac address to the chip
  if(macptr)
    setMACAddress(macptr)

  'heap_init

  ' check to make sure its a valid supported silicon rev
  return hwVersion => silicon_rev

PUB stop
'' Stops the driver, frees 1 cog

  spi_stop
PUB hwVersion
  banksel(EREVID)
  return rd_cntlreg(EREVID)
PUB setMACAddress(macptr)
  ' write mac address to the chip
  banksel(MAADR1)
{
  spi_out_cs(constant(cWCR | MAADR1))
  repeat 5
    spi_out_cs(byte[macptr++])
  spi_out(byte[macptr++])
}
  wr_reg(MAADR1,byte[macptr++])
  wr_reg(MAADR2,byte[macptr++])
  wr_reg(MAADR3,byte[macptr++])
  wr_reg(MAADR4,byte[macptr++])
  wr_reg(MAADR5,byte[macptr++])
  wr_reg(MAADR6,byte[macptr++])
  
PUB rxPacketCount
  banksel(EPKTCNT)  ' re-select the packet count bank
  return rd_cntlreg(EPKTCNT)
PUB isLinkUp
  return rd_phy(PHSTAT2)&PHSTAT2_LSTAT <>0
PUB get_frame | new_rdptr
'' Get Ethernet Frame from Buffer

  setSRAMReadPointer(ph_nextpacket)

  rd_sram_block(@packetheader,6)

  ' protect from oversized packet
  if ph_rxlen =< MAXFRAME
    rd_sram_block(@packet,ph_rxlen)
     
  new_rdptr := ph_nextpacket
     
  ' handle errata read pointer start (must be odd)
  --new_rdptr
       
  if (new_rdptr < RXSTART) OR (new_rdptr > RXSTOP)
    new_rdptr := RXSTOP

  bfs_reg(ECON2, ECON2_PKTDEC)
  
  banksel(ERXRDPTL)
  wr_reg_word(ERXRDPTL, new_rdptr)

PUB start_frame
'' Start frame - Inits the NIC and sets stuff

  setSRAMWritePointer(TXSTART)

  tx_end := constant(TXSTART - 1)         ' start location is really address 0, so we are sending a count of - 1

  wr_frame_byte(cTXCONTROL)

PUB wr_frame_byte(data)
  spi_out_cs(cWBM)
  spi_out(data)
  ++tx_end
PUB wr_frame_word(data)
  spi_out_cs(cWBM)
  spi_out_cs(byte[@data][1])
  spi_out(byte[@data][0])
  tx_end+=2

PUB wr_frame_long(data)
  spi_out_cs(cWBM)
  spi_out_cs(byte[@data][3])
  spi_out_cs(byte[@data][2])
  spi_out_cs(byte[@data][1])
  spi_out(byte[@data][0])
  tx_end+=4

PUB wr_frame_data(data,len) | i
  wr_sram_block(data,len)
  tx_end+=len

PUB wr_frame_pad(len)
  spi_out_cs(cWBM)
  repeat len-1
    spi_out_cs(0)
  spi_out(0)    
  tx_end+=len

PUB send_frame
'' Sends frame
'' Will retry on send failure up to 15 times with a 1ms delay in between repeats

  repeat 15
    if p_send_frame             ' send packet, if successful then quit retry loop
      quit          
    pause.delay_ms(1)
PUB calc_frame_ip_length : length
  length:=tx_end-constant(TXSTART - 1)-14-1
  setSRAMWritePointer(constant($10 + TXSTART +1))
  wr_sram(length.byte[1]) 
  wr_sram(length.byte[0]) 
  
PUB calc_frame_udp_length : length
  length:=calc_frame_ip_length - 28
  setSRAMWritePointer(constant($26 + TXSTART +1))
  wr_sram(length.byte[1]) 
  wr_sram(length.byte[0]) 
  
PUB calc_frame_ip_checksum
  ' TODO: This needs to be able to handle different header sizes!
  return calc_checksum(14,constant(14+20),constant(14+20-10))
PUB calc_frame_icmp_checksum
  return calc_checksum(34,tx_end-TXSTART, 36)

PUB calc_frame_tcp_checksum
'' For this to work, the partial checksum of the pseudo header needs
'' to be in the checksum field.
  return calc_checksum(34,tx_end-TXSTART, $32)

PUB calc_frame_udp_checksum
'' For this to work, the partial checksum of the pseudo header needs
'' to be in the checksum field.
  return calc_checksum(34,tx_end-TXSTART, 38)
 
PUB calc_checksum(crc_start, crc_end, dest) | econval, crc
  crc_start += constant(TXSTART+1)
  crc_end += TXSTART

  banksel(EDMASTL)
  wr_reg_word(EDMASTL, crc_start)
  wr_reg_word(EDMANDL, crc_end)
  
  ' Wait for receive to finish, errata 15
  repeat while ((rd_cntlreg(ESTAT) & constant(ESTAT_RXBUSY)))
  
  ' Enable and start checksum calculation
  bfs_reg(ECON1, ECON1_CSUMEN|ECON1_DMAST)

  ' Wait for the DMA op to finish
  repeat while ((rd_cntlreg(ECON1) & constant(ECON1_DMAST)))

  crc_end := dest + constant(TXSTART+1)

  crc := rd_cntlreg(EDMACSL) + (rd_cntlreg(EDMACSH) << 8)
  
  ' Now we write out the checksum back to the device
  wr_reg_word(EWRPTL, crc_end)

  wr_sram(crc.byte[1]) 
  wr_sram(crc.byte[0]) 
  return 1

PUB get_packetpointer
'' Gets packet pointer (for external object access)
  return @packet

{
PUB get_mac_pointer
'' Gets mac address pointer
  return @eth_mac
}
PUB get_rxlen
'' Gets received packet length
  return ph_rxlen - 4             ' knock off the 4 byte Frame Check Sequence CRC, not used anywhere outside of this driver (pg 31 datasheet)

PRI rd_macreg(address) : data
'' Read MAC Control Register

  spi_out_cs(cRCR | address)
  spi_out_cs(0)                 ' transmit dummy byte
  data.byte[0] := spi_in                ' get actual data

PRI rd_macreg_word(address) : data
'' Read MAC Control Register

  spi_out_cs(cRCR | address)
  spi_out_cs(0)                 ' transmit dummy byte
  data.byte[0] := spi_in                ' get actual data

  spi_out_cs(cRCR | address+1)
  spi_out_cs(0)                 ' transmit dummy byte
  data.byte[1] := spi_in                ' get actual data

PRI rd_cntlreg(address) : data
'' Read ETH Control Register

  spi_out_cs(cRCR | address)
  data.byte[0] := spi_in

PRI wr_reg(address, data)
'' Write MAC and ETH Control Register

  spi_out_cs(cWCR | address)
  spi_out(data)

PRI wr_reg_word(address, data)
'' Write MAC and ETH Control Register

  spi_out_cs(cWCR | address++)
  spi_out(data.byte[0])

  spi_out_cs(cWCR | address)
  'spi_out_cs(data.byte[0])
  spi_out(data.byte[1])

PRI bfc_reg(address, data)
'' Clear Control Register Bits

  spi_out_cs(cBFC | address)
  spi_out(data)

PRI bfs_reg(address, data)
'' Set Control Register Bits

  spi_out_cs(cBFS | address)
  spi_out(data)

PRI soft_reset
'' Soft Reset ENC28J60

  spi_out(cSC)

PRI banksel(register)
'' Select Control Register Bank

  bfc_reg(ECON1, %0000_0011)
  bfs_reg(ECON1, register.byte[1])                         ' high byte

PRI rd_phy(register): retVal
'' Read ENC28J60 PHY Register

  banksel(MIREGADR)
  wr_reg(MIREGADR, register)
  wr_reg(MICMD, MICMD_MIIRD)
  banksel(MISTAT)
  repeat while ((rd_macreg(MISTAT) & MISTAT_BUSY) > 0)
  banksel(MIREGADR)
  wr_reg(MICMD, $00)
  retVal := rd_macreg_word(MIRDL)

PRI wr_phy(register, data)
'' Write ENC28J60 PHY Register

  banksel(MIREGADR)
  wr_reg(MIREGADR, register)   
  wr_reg_word(MIWRL,data)
  banksel(MISTAT)
  repeat while ((rd_macreg(MISTAT) & MISTAT_BUSY) > 0)

PRI setSRAMReadPointer(x)
  banksel(ERDPTL)
  wr_reg_word(ERDPTL, x)
  
PRI setSRAMWritePointer(x)
  banksel(EWRPTL)
  wr_reg_word(EWRPTL, x)

PRI rd_sram : data
'' Read ENC28J60 8k Buffer Memory

  spi_out_cs(cRBM)
  data := spi_in

PRI wr_sram(data)
'' Write ENC28J60 8k Buffer Memory

  spi_out_cs(cWBM)
  spi_out(data)


PRI rd_sram_block(data_ptr,size)
  'repeat size
  '  byte[data_ptr++]:=rd_sram
  blockread(data_ptr,size)

PRI wr_sram_block(data_ptr,size)
  blockwrite(data_ptr, size)

PRI init_ENC28J60 | starttime,i
'' Init ENC28J60 Chip

  starttime:=cnt
  repeat
    if cnt-starttime>clkfreq
      ' Timeout!
      abort 0
    i := rd_cntlreg(ESTAT)
  while (i & $08) OR (!i & ESTAT_CLKRDY)
  
  soft_reset
  pause.delay_ms(5)                                           ' reset delay

  bfc_reg(ECON1, ECON1_RXEN)                            ' stop send / recv
  bfc_reg(ECON1, ECON1_TXRTS)

  bfs_reg(ECON2, ECON2_AUTOINC)                         ' enable auto increment of sram pointers (already default)

  packetheader[nextpacket_low] := RXSTART
  packetheader[nextpacket_high] := constant(RXSTART >> 8)

  banksel(ERDPTL)
  wr_reg_word(ERDPTL, RXSTART)

  banksel(ERXSTL)
  wr_reg_word(ERXSTL, RXSTART)
  wr_reg_word(ERXRDPTL, RXSTOP)
  wr_reg_word(ERXNDL, RXSTOP)
  wr_reg_word(ETXSTL, TXSTART)

  banksel(MACON1)
  wr_reg(MACON1, constant(MACON1_TXPAUS | MACON1_RXPAUS | MACON1_MARXEN))
  wr_reg(MACON3, constant(MACON3_TXCRCEN | MACON3_PADCFG0 | MACON3_FRMLNEN))
  
  ' don't timeout transmissions on saturated media
  wr_reg(MACON4, MACON4_DEFER)
  ' collisions occur at 63rd byte
  wr_reg(MACLCON2, 63)
  
  wr_reg(MAIPGL, $12)
  wr_reg(MAIPGH, $0C)
  wr_reg_word(MAMXFLL, MAXFRAME)                     

  ' back-to-back inter-packet gap time
  ' full duplex = 0x15 (9.6us)
  ' half duplex = 0x12 (9.6us)
  wr_reg(MABBIPG, $12)

  ' half duplex 
  wr_phy(PHCON2, PHCON2_HDLDIS)
  wr_phy(PHCON1, $0000)

  ' set LED options (led A = link, led B = tx/rx)
  wr_phy(PHLCON, $0472)         '$0472          
   
  ' enable packet reception
  bfs_reg(ECON1, ECON1_RXEN)


  
PRI p_send_frame | i, eirval
'' Sends the frame
  banksel(ETXSTL)
  wr_reg_word(ETXSTL, TXSTART)

  banksel(ETXNDL)
  wr_reg_word(ETXNDL, tx_end)

  ' B5 Errata #10 - Reset transmit logic before send
  bfs_reg(ECON1, ECON1_TXRST)
  bfc_reg(ECON1, ECON1_TXRST)
  
  ' B5 Errata #10 & #13: Reset interrupt error flags
  bfc_reg(EIR, constant(EIR_TXERIF | EIR_TXIF))

  ' trigger send
  bfs_reg(ECON1, ECON1_TXRTS)

  ' fix for transmit stalls (derived from errata B5 #13), watches TXIF and TXERIF bits
  ' also implements a ~3.75ms (15 * 250us) timeout if send fails (occurs on random packet collisions)
  ' btw: this took over 10 hours to fix due to the elusive undocumented bug
  i := 0
  repeat
    eirval := rd_cntlreg(EIR)
    if ((eirval & constant(EIR_TXERIF | EIR_TXIF)) > 0)
      quit
    if (++i => 15)
      eirval := EIR_TXERIF
      quit
    pause.delay_us(250)

  ' B5 Errata #13 - Reset TXRTS if failed send then reset logic
  bfc_reg(ECON1, ECON1_TXRTS)
  
  return ((eirval & EIR_TXERIF) == 0)

PRI SynthFreq(Pin, Freq) | s, d, ctr, frq

  Freq := Freq #> 0 <# 128_000_000     'limit frequency range
  
  if Freq < 500_000                    'if 0 to 499_999 Hz,
    ctr := constant(%00100 << 26)      '..set NCO mode
    s := 1                             '..shift = 1
  else                                 'if 500_000 to 128_000_000 Hz,
    ctr := constant(%00010 << 26)      '..set PLL mode
    d := >|((Freq - 1) / 1_000_000)    'determine PLLDIV
    s := 4 - d                         'determine shift
    ctr |= d << 23                     'set PLLDIV
    
  frq := fraction(Freq, CLKFREQ, s)    'Compute FRQA/FRQB value
  ctr |= Pin                           'set PINA to complete CTRA/CTRB value

  CTRA := ctr                        'set CTRA
  FRQA := frq                        'set FRQA                   
  DIRA[Pin]~~                        'make pin output

PRI fraction(a, b, shift) : f

  if shift > 0                         'if shift, pre-shift a or b left
    a <<= shift                        'to maintain significant bits while 
  if shift < 0                         'insuring proper result
    b <<= -shift
 
  repeat 32                            'perform long division of a/b
    f <<= 1
    if a => b
      a -= b
      f++           
    a <<= 1

' ***************************************
' **          ASM SPI Engine           **
' ***************************************   
DAT
cog     long 0
command long 0
  
CON
  SPIOUT        = %00_0001
  SPIIN         = %00_0010
  SRAMWRITE     = %00_0100
  SRAMREAD      = %00_1000
  CSON          = %01_0000
  CSOFF         = %10_0000

  SPIBITS       = 8

PRI spi_out(value)
  setcommand(constant(SPIOUT | CSON | CSOFF), @value)
  
PRI spi_out_cs(value)
  setcommand(constant(SPIOUT | CSON), @value)

PRI spi_in : value
  setcommand(constant(SPIIN | CSON | CSOFF), @value)
  
PRI spi_in_cs : value
  setcommand(constant(SPIIN | CSON), @value)

PRI blockwrite(startaddr, count)
  setcommand(SRAMWRITE, @startaddr)

PRI blockread(startaddr, count)
  setcommand(SRAMREAD, @startaddr)
  
PRI spi_start(_cs, _sck, _di, _do)
  spi_stop

  cspin := |< _cs
  dipin := |< _di
  dopin := |< _do
  clkpin := |< _sck
  
  cog := cognew(@init, @command) + 1
  
PRI spi_stop
  if cog
    cogstop(cog~ - 1)
  command~
  
PRI setcommand(cmd, argptr)
  command := cmd << 16 + argptr                       'write command and pointer
  repeat while command                                'wait for command to be cleared, signifying receipt

DAT
              org
init
              or      dira, cspin                       'pin directions
              andn    dira, dipin
              or      dira, dopin
              or      dira, clkpin

              or      outa, cspin                       'turn off cs (bring it high)
              andn    outa,           dopin             '          PreSet DataPin LOW
              andn    outa,           clkpin            '          PreSet ClockPin LOW
              
loop          wrlong  zero,par                          'zero command (tell spin we are done processing)
:subloop      rdlong  t1,par                    wz      'wait for command
        if_z  jmp     #:subloop

              mov     addr, t1                          'used for holding return addr to spin vars
        
              rdlong  arg0, t1                          'arg0
              add     t1, #4
              rdlong  arg1, t1                          'arg1                                             
              
'             wrlong  zero,par                          'zero command to signify command received

              mov     lkup, addr                        'get the command var from spin
              shr     lkup, #16                         'extract the cmd from the command var

              test    lkup, #CSON               wz      'turn on cs
        if_nz andn    outa, cspin
        
              test    lkup, #SPIOUT             wz      'spi out
        if_nz call    #spi_out_
              test    lkup, #SPIIN              wz      'spi in 
        if_nz call    #xspi_in_
              test    lkup, #SRAMWRITE          wz      'sram block write
        if_nz jmp     #sram_write_
              test    lkup, #SRAMREAD           wz      'sram block read
        if_nz jmp     #sram_read_

              test    lkup, #CSOFF              wz      'cs off
        if_nz or      outa, cspin

              jmp #loop                                 ' no cmd found
              


spi_out_                                                'SHIFTOUT Entry
              mov     t4,             #SPIBITS          '     Load number of data bits

              mov     t3,             arg0              '          Load t3 with DataValue
              rol       t3, #(32-SPIBITS)
:sout_loop
              rol       t3, #1 wc
              muxc    outa,           dopin             '          Set DataBit HIGH or LOW
              or    outa,           clkpin            '          Set ClockPin HIGH
              andn   outa,           clkpin            '          Set ClockPin LOW
              djnz    t4,             #:sout_loop       '          Decrement t4 ; jump if not Zero
              andn    outa,           dopin
              
spi_out__ret  ret                                       '     Go wait for next command

              

spi_in_                                                 'SHIFTIN Entry
              mov     t4,             #SPIBITS          '     Load number of data bits
'              andn    outa,           clkpin            '          PreSet ClockPin LOW

:sin_loop
              test    dipin,          ina     wc        '          Read Data Bit into 'C' flag
              or    outa,           clkpin            '          Set ClockPin HIGH
              rcl     t3,             #1                '          rotate "C" flag into return value
              andn   outa,           clkpin            '          Set ClockPin LOW
              djnz    t4,             #:sin_loop        '          Decrement t4 ; jump if not Zero

              mov     arg0, t3
spi_in__ret   ret                                       '     Go wait for next command

xspi_in_
              call #spi_in_
              wrbyte  arg0, addr
xspi_in__ret  ret

' SRAM Block Read/Write
sram_write_   ' block write (arg0=hub addr, arg1=count)
              mov t1, arg0
              mov t2, arg1

              andn outa, cspin
              mov arg0, #cWBM
              call #spi_out_
:loop         rdbyte arg0, t1
              call #spi_out_              
              add t1, #1
              djnz t2, #:loop
              or outa, cspin
              
              jmp #loop
              
sram_read_    ' block read (arg0=hub addr, arg1=count)
              mov t1, arg0
              mov t2, arg1
              
              andn outa, cspin
              mov arg0, #cRBM
              call #spi_out_
:loop         call #spi_in_
              wrbyte arg0, t1
              add t1, #1
              djnz t2, #:loop
              or outa, cspin
              
              jmp #loop

zero                    long    0                       'constants

                                                        'values filled by spin code before launching
cspin                   long    0                       ' chip select pin
dipin                   long    0                       ' data in pin (enc28j60 -> prop)
dopin                   long    0                       ' data out pin (prop -> enc28j60)
clkpin                  long    0                       ' clock pin (prop -> enc28j60)

                                                        'temp variables
t1                      res     1                       '     loop and cog shutdown                          
t2                      res     1                       '     loop and cog shutdown
t3                      res     1                       '     Used to hold DataValue SHIFTIN/SHIFTOUT
t4                      res     1                       '     Used to hold # of Bits
t5                      res     1                       '     Used for temporary data mask

addr                    res     1                       '     Used to hold return address of first Argument passed
lkup                    res     1                       '     Used to hold command lookup

                                                        'arguments passed to/from high-level Spin
arg0                    res     1                       ' bits / start address
arg1                    res     1                       ' value / count                                                          




CON
' ***************************************
' **    ENC28J60 Control Constants     **
' ***************************************
  ' ENC28J60 opcodes (OR with 5bit address)
  cWCR = %010 << 5              ' write control register command
  cBFS = %100 << 5              ' bit field set command
  cBFC = %101 << 5              ' bit field clear command
  cRCR = %000 << 5              ' read control register command
  cRBM = (%001 << 5) | $1A      ' read buffer memory command
  cWBM = (%011 << 5) | $1A      ' write buffer memory command
  cSC = (%111 << 5) | $1F       ' system command

  ' This is used to trigger TX in the ENC28J60, it shouldn't change, but you never know...
  cTXCONTROL = $0E

  ' Packet header format (tail of the receive packet in the ENC28J60 SRAM)
  #0,nextpacket_low,nextpacket_high,rec_bytecnt_low,rec_bytecnt_high,rec_status_low,rec_status_high

' ***************************************
' **     ENC28J60 Register Defines     **
' ***************************************
  ' Bank 0 registers --------
  ERDPTL = $00
  ERDPTH = $01
  EWRPTL = $02
  EWRPTH = $03
  ETXSTL = $04
  ETXSTH = $05
  ETXNDL = $06
  ETXNDH = $07
  ERXSTL = $08
  ERXSTH = $09
  ERXNDL = $0A
  ERXNDH = $0B
  ERXRDPTL = $0C
  ERXRDPTH = $0D
  ERXWRPTL = $0E
  ERXWRPTH = $0F
  EDMASTL = $10
  EDMASTH = $11
  EDMANDL = $12
  EDMANDH = $13
  EDMADSTL = $14
  EDMADSTH = $15
  EDMACSL = $16
  EDMACSH = $17
  ' = $18
  ' = $19
  ' r = $1A
  EIE = $1B
  EIR = $1C
  ESTAT = $1D
  ECON2 = $1E
  ECON1 = $1F
   
  ' Bank 1 registers -----
  EHT0 = $100
  EHT1 = $101
  EHT2 = $102
  EHT3 = $103
  EHT4 = $104
  EHT5 = $105
  EHT6 = $106
  EHT7 = $107
  EPMM0 = $108
  EPMM1 = $109
  EPMM2 = $10A
  EPMM3 = $10B
  EPMM4 = $10C
  EPMM5 = $10D
  EPMM6 = $10E
  EPMM7 = $10F
  EPMCSL = $110
  EPMCSH = $111
  ' = $112
  ' = $113
  EPMOL = $114
  EPMOH = $115
  EWOLIE = $116
  EWOLIR = $117
  ERXFCON = $118
  EPKTCNT = $119
  ' r = $11A
  ' EIE = $11B
  ' EIR = $11C
  ' ESTAT = $11D
  ' ECON2 = $11E
  ' ECON1 = $11F
   
  ' Bank 2 registers -----
  MACON1 = $200
  MACON2 = $201
  MACON3 = $202
  MACON4 = $203
  MABBIPG = $204
  ' = $205
  MAIPGL = $206
  MAIPGH = $207
  MACLCON1 = $208
  MACLCON2 = $209
  MAMXFLL = $20A
  MAMXFLH = $20B
  ' r = $20C
  MAPHSUP = $20D
  ' r = $20E
  ' = $20F
  ' r = $210
  MICON = $211
  MICMD = $212
  ' = $213
  MIREGADR = $214
  ' r = $215
  MIWRL = $216
  MIWRH = $217
  MIRDL = $218
  MIRDH = $219
  ' r = $21A
  ' EIE = $21B
  ' EIR = $21C
  ' ESTAT = $21D
  ' ECON2 = $21E
  ' ECON1 = $21F
   
  ' Bank 3 registers -----
  
  MAADR5 = $300
  MAADR6 = $301
  MAADR3 = $302
  MAADR4 = $303
  MAADR1 = $304
  MAADR2 = $305

  {MAADR1 = $300
  MAADR0 = $301
  MAADR3 = $302
  MAADR2 = $303
  MAADR5 = $304
  MAADR4 = $305}
  
  EBSTSD = $306
  EBSTCON = $307
  EBSTCSL = $308
  EBSTCSH = $309
  MISTAT = $30A
  ' = $30B
  ' = $30C
  ' = $30D
  ' = $30E
  ' = $30F
  ' = $310
  ' = $311
  EREVID = $312
  ' = $313
  ' = $314
  ECOCON = $315
  ' EPHTST      $316
  EFLOCON = $317
  EPAUSL = $318
  EPAUSH = $319
  ' r = $31A
  ' EIE = $31B
  ' EIR = $31C
  ' ESTAT = $31D
  ' ECON2 = $31E
  ' ECON1 = $31F
   
  {******************************************************************************
  * PH Register Locations
  ******************************************************************************}
  PHCON1 = $00
  PHSTAT1 = $01
  PHID1 = $02
  PHID2 = $03
  PHCON2 = $10
  PHSTAT2 = $11
  PHIE = $12
  PHIR = $13
  PHLCON = $14
   
  {******************************************************************************
  * Individual Register Bits
  ******************************************************************************}
  ' ETH/MAC/MII bits
   
  ' EIE bits ----------
  EIE_INTIE = (1<<7)
  EIE_PKTIE = (1<<6)
  EIE_DMAIE = (1<<5)
  EIE_LINKIE = (1<<4)
  EIE_TXIE = (1<<3)
  EIE_WOLIE = (1<<2)
  EIE_TXERIE = (1<<1)
  EIE_RXERIE = (1)
   
  ' EIR bits ----------
  EIR_PKTIF = (1<<6)
  EIR_DMAIF = (1<<5)
  EIR_LINKIF = (1<<4)
  EIR_TXIF = (1<<3)
  EIR_WOLIF = (1<<2)
  EIR_TXERIF = (1<<1)
  EIR_RXERIF = (1)
        
  ' ESTAT bits ---------
  ESTAT_INT = (1<<7)
  ESTAT_LATECOL = (1<<4)
  ESTAT_RXBUSY = (1<<2)
  ESTAT_TXABRT = (1<<1)
  ESTAT_CLKRDY = (1)
        
  ' ECON2 bits --------
  ECON2_AUTOINC = (1<<7)
  ECON2_PKTDEC = (1<<6)
  ECON2_PWRSV = (1<<5)
  ECON2_VRTP = (1<<4)
  ECON2_VRPS = (1<<3)
        
  ' ECON1 bits --------
  ECON1_TXRST = (1<<7)
  ECON1_RXRST = (1<<6)
  ECON1_DMAST = (1<<5)
  ECON1_CSUMEN = (1<<4)
  ECON1_TXRTS = (1<<3)
  ECON1_RXEN = (1<<2)
  ECON1_BSEL1 = (1<<1)
  ECON1_BSEL0 = (1)
        
  ' EWOLIE bits -------
  EWOLIE_UCWOLIE = (1<<7)
  EWOLIE_AWOLIE = (1<<6)
  EWOLIE_PMWOLIE = (1<<4)
  EWOLIE_MPWOLIE = (1<<3)
  EWOLIE_HTWOLIE = (1<<2)
  EWOLIE_MCWOLIE = (1<<1)
  EWOLIE_BCWOLIE = (1)
        
  ' EWOLIR bits -------
  EWOLIR_UCWOLIF = (1<<7)
  EWOLIR_AWOLIF = (1<<6)
  EWOLIR_PMWOLIF = (1<<4)
  EWOLIR_MPWOLIF = (1<<3)
  EWOLIR_HTWOLIF = (1<<2)
  EWOLIR_MCWOLIF = (1<<1)
  EWOLIR_BCWOLIF = (1)
        
  ' ERXFCON bits ------
  ERXFCON_UCEN = (1<<7)
  ERXFCON_ANDOR = (1<<6)
  ERXFCON_CRCEN = (1<<5)
  ERXFCON_PMEN = (1<<4)
  ERXFCON_MPEN = (1<<3)
  ERXFCON_HTEN = (1<<2)
  ERXFCON_MCEN = (1<<1)
  ERXFCON_BCEN = (1)
        
  ' MACON1 bits --------
  MACON1_LOOPBK = (1<<4)
  MACON1_TXPAUS = (1<<3)
  MACON1_RXPAUS = (1<<2)
  MACON1_PASSALL = (1<<1)
  MACON1_MARXEN = (1)
        
  ' MACON2 bits --------
  MACON2_MARST = (1<<7)
  MACON2_RNDRST = (1<<6)
  MACON2_MARXRST = (1<<3)
  MACON2_RFUNRST = (1<<2)
  MACON2_MATXRST = (1<<1)
  MACON2_TFUNRST = (1)
        
  ' MACON3 bits --------
  MACON3_PADCFG2 = (1<<7)
  MACON3_PADCFG1 = (1<<6)
  MACON3_PADCFG0 = (1<<5)
  MACON3_TXCRCEN = (1<<4)
  MACON3_PHDRLEN = (1<<3)
  MACON3_HFRMEN = (1<<2)
  MACON3_FRMLNEN = (1<<1)
  MACON3_FULDPX = (1)
        
  ' MACON4 bits --------
  MACON4_DEFER = (1<<6)
  MACON4_BPEN = (1<<5)
  MACON4_NOBKOFF = (1<<4)
  MACON4_LONGPRE = (1<<1)
  MACON4_PUREPRE = (1)
        
  ' MAPHSUP bits ----
  MAPHSUP_RSTRMII = (1<<3)
        
  ' MICON bits --------
  MICON_RSTMII = (1<<7)
        
  ' MICMD bits ---------
  MICMD_MIISCAN = (1<<1)
  MICMD_MIIRD = (1)
   
  ' EBSTCON bits -----
  EBSTCON_PSV2 = (1<<7)
  EBSTCON_PSV1 = (1<<6)
  EBSTCON_PSV0 = (1<<5)
  EBSTCON_PSEL = (1<<4)
  EBSTCON_TMSEL1 = (1<<3)
  EBSTCON_TMSEL0 = (1<<2)
  EBSTCON_TME = (1<<1)
  EBSTCON_BISTST = (1)
   
  ' MISTAT bits --------
  MISTAT_NVALID = (1<<2)
  MISTAT_SCAN = (1<<1)
  MISTAT_BUSY = (1)
        
  ' ECOCON bits -------
  ECOCON_COCON2 = (1<<2)
  ECOCON_COCON1 = (1<<1)
  ECOCON_COCON0 = (1)
        
  ' EFLOCON bits -----
  EFLOCON_FULDPXS = (1<<2)
  EFLOCON_FCEN1 = (1<<1)
  EFLOCON_FCEN0 = (1)
   
   
   
  ' PHY bits
   
  ' PHCON1 bits ----------
  PHCON1_PRST = (1<<15)
  PHCON1_PLOOPBK = (1<<14)
  PHCON1_PPWRSV = (1<<11)
  PHCON1_PDPXMD = (1<<8)
   
  ' PHSTAT1 bits --------
  PHSTAT1_PFDPX = (1<<12)
  PHSTAT1_PHDPX = (1<<11)
  PHSTAT1_LLSTAT = (1<<2)
  PHSTAT1_JBSTAT = (1<<1)
   
  ' PHID2 bits --------
  PHID2_PID24 = (1<<15)
  PHID2_PID23 = (1<<14)
  PHID2_PID22 = (1<<13)
  PHID2_PID21 = (1<<12)
  PHID2_PID20 = (1<<11)
  PHID2_PID19 = (1<<10)
  PHID2_PPN5 = (1<<9)
  PHID2_PPN4 = (1<<8)
  PHID2_PPN3 = (1<<7)
  PHID2_PPN2 = (1<<6)
  PHID2_PPN1 = (1<<5)
  PHID2_PPN0 = (1<<4)
  PHID2_PREV3 = (1<<3)
  PHID2_PREV2 = (1<<2)
  PHID2_PREV1 = (1<<1)
  PHID2_PREV0 = (1)
   
  ' PHCON2 bits ----------
  PHCON2_FRCLNK = (1<<14)
  PHCON2_TXDIS = (1<<13)
  PHCON2_JABBER = (1<<10)
  PHCON2_HDLDIS = (1<<8)
   
  ' PHSTAT2 bits --------
  PHSTAT2_TXSTAT = (1<<13)
  PHSTAT2_RXSTAT = (1<<12)
  PHSTAT2_COLSTAT = (1<<11)
  PHSTAT2_LSTAT = (1<<10)
  PHSTAT2_DPXSTAT = (1<<9)
  PHSTAT2_PLRITY = (1<<5)
   
  ' PHIE bits -----------
  PHIE_PLNKIE = (1<<4)
  PHIE_PGEIE = (1<<1)
   
  ' PHIR bits -----------
  PHIR_PLNKIF = (1<<4)
  PHIR_PGIF = (1<<2)
   
  ' PHLCON bits -------
  PHLCON_LACFG3 = (1<<11)
  PHLCON_LACFG2 = (1<<10)
  PHLCON_LACFG1 = (1<<9)
  PHLCON_LACFG0 = (1<<8)
  PHLCON_LBCFG3 = (1<<7)
  PHLCON_LBCFG2 = (1<<6)
  PHLCON_LBCFG1 = (1<<5)
  PHLCON_LBCFG0 = (1<<4)
  PHLCON_LFRQ1 = (1<<3)
  PHLCON_LFRQ0 = (1<<2)
  PHLCON_STRCH = (1<<1)