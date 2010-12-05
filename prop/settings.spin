{{
        Settings Object v1.0
        Robert Quattlebaum <darco@deepdarc.com>
        PUBLIC DOMAIN
        
        This object handles the storage and retrieval of variables
        and data which need to persist across power cycles.

        By default requires a 64KB EEPROM to save things persistently.
        You can make it work with a 32KB EEPROM by changing the
        EEPROMOffset constant to zero.

        Also, since it is effectively a "singleton" type of object,
        it allows for some rudimentary cross-object communication.
        It is not terribly fast though, so it should be read-from
        and written-to sparingly.

        The data is stored at the end of hub ram, starting at $8000
        and expanding *downward*.

        The format is as follows (in reverse!):

        1 Word                  Key Value
        1 Byte                  Data Length
        1 Byte                  Check Byte (Ones complement of key length)
        x Bytes                 Data
        1 Byte (If necessary)   Padding, if size is odd

        The data is filled in from back to front, so that the
        size of settings area can be adjusted later without
        causing problems. This means that the actual order
        of things in memory is reverse of what you see above.

        Even though it is written stored from the top-down, the
        data is stored in its original order. In other words,
        the actual data contained in a variable isn't stored
        backward. Doing so would have made things more complicated
        without any obvious benefit.

        Limitations/implications:
          * The maximum data size is 255 bytes.
          * Zero-length entries are valid.
          * The key value of zero is reserved.
          * Two entries cannot have the same key.
          * A valid entry must:
            * have a non-zero key.
            * have a correct check byte.
            * have a length which doesn't extend beyond
              the settings boundary.
          * The first invalid entry encountered marks
            the start of free space. 

        TRIVIA: The data format for this object is based
        loosely on the OLPC XO-1 manufacturing data,
        documented here: http://wiki.laptop.org/go/Manufacturing_Data
}} 
CON { Tweakable parameters }
  SettingsSize = $400
  EEPROMOffset = $8000 ' Change to zero if you want to use with a 32KB EEPROM
  EEPROMPageSize = 128 ' May need to be 64 for some EEPROM devices

CON { Non-tweakable constants }
  SettingsTop = $8000 - 1
  SettingsBottom = SettingsTop - (SettingsSize-1)

CON { Keys for various stuff (Mostly ybox2 specific) }
  MISC_UUID          = "i"+("d"<<8)
  MISC_PASSWORD      = "p"+("w"<<8)
  MISC_AUTOBOOT      = "a"+("b"<<8)
  MISC_SOUND_DISABLE = "s"+("-"<<8)
  MISC_LED_CONF      = "l"+("c"<<8) ' 4 bytes: red pin, green pin, blue pin, CC=0/CA=1
  MISC_TV_MODE       = "t"+("v"<<8) ' 1 byte, 0=NTSC, 1=PAL
  MISC_ONE_WIRE_BUS  = "1"+("w"<<8) ' Pin number for the one wire bus

  MISC_X10_HOUSE     = "X"+("H"<<8) ' X10 House id (in raw wire format)

  MISC_STAGE2        = "2"+("2"<<8)

  MISC_STAGE2_SIZE   = "2"+("S"<<8)
  MISC_STAGE2_HASH   = "2"+("H"<<8)

  NET_MAC_ADDR       = "E"+("A"<<8)
  NET_IPv4_ADDR      = "4"+("A"<<8)
  NET_IPv4_MASK      = "4"+("M"<<8)
  NET_IPv4_GATE      = "4"+("G"<<8)
  NET_IPv4_DNS       = "4"+("D"<<8)
  NET_DHCPv4_DISABLE = "4"+("d"<<8)
  
  SERVER_IPv4_ADDR   = "S"+("A"<<8) 
  SERVER_IPv4_PORT   = "S"+("P"<<8) 
  SERVER_PATH        = "S"+("T"<<8) 
  SERVER_HOST        = "S"+("H"<<8)

  ALARM_ON           = "A"+("O"<<8)
  ALARM_HOUR         = "A"+("H"<<8)
  ALARM_MIN          = "A"+("M"<<8)
  TIMEZONE           = "T"+("Z"<<8)

DAT
SettingsLock  byte      -1
OBJ
  eeprom : "Fast_I2C_Driver"
PUB start
{{ Initializes the object. Call only once. }}
  if(SettingsLock := locknew) == -1
    abort FALSE

  ' If we don't have any environment variables, try to load the defaults from EEPROM
  ifnot size
    revert

  return TRUE
PUB revert : ack | i, addr',startCnt
{{ Retrieves the settings from EEPROM, overwriting any changes that were made. }}  
  lock
  'startCnt := cnt
  addr := SettingsBottom & %11111111_10000000
  repeat while eeprom.busy
    ' If we wait longer than one second,
    ' then abort. Let the caller figure out
    ' what to do in this case.
    'if (cnt-startCnt) > clkfreq
      'abort -5
  ack := eeprom.blockRead(addr, addr+EEPROMOffset, SettingsSize)
  unlock
PUB purge
{{ Removes all settings. }}
  lock
  bytefill(SettingsBottom,$FF,SettingsSize) 
  unlock
PUB stop
  lockret(SettingsLock~~)
PRI lock
  repeat while NOT lockset(SettingsLock)
PRI unlock
  lockclr(SettingsLock)
PUB commit:ack | addr, i, startCnt
{{ Commits current settings to EEPROM }}
  lock
  'startCnt := cnt
  addr := SettingsBottom & %11111111_10000000
  repeat i from 0 to SettingsSize/EEPROMPageSize-1
    repeat while eeprom.busy
      ' If we wait longer than one second,
      ' then abort. Let the caller figure out
      ' what to do in this case.
      'if (cnt-startCnt) > clkfreq
      '  abort -5

    eeprom.blockWrite(addr,addr+EEPROMOffset, EEPROMPageSize)

    addr+=EEPROMPageSize
  unlock
  return 0

pri isValidEntry(iter)
  return (iter > SettingsBottom) AND word[iter] AND (byte[iter-2]==(byte[iter-3]^$FF))
pri nextEntry(iter)
  return iter-(4+((byte[iter-2]+1) & !1))

PUB size | iter
{{ Returns the current size of all settings }}
  iter := SettingsTop
  repeat while isValidEntry(iter)
    iter := nextEntry(iter)
  return SettingsTop-iter

PRI findKey_(key) | iter
  iter := SettingsTop
  repeat while isValidEntry(iter)
    if word[iter] == key
      return iter
    iter:=nextEntry(iter)
  return 0
PUB findKey(key):retVal
{{ Returns non-zero if the given key exists in the store }}
  lock
  retVal:=findKey_(key)
  unlock
PUB firstKey
{{ Returns the key of the first setting }}
  if isValidEntry(SettingsTop)
    return word[SettingsTop]
  return 0

PUB nextKey(key) | iter
{{ Finds and returns the key of the setting after the given key }}
  lock
  iter:=nextEntry(findKey_(key))
  if isValidEntry(iter)
    key:=word[iter]
  else
    key~
  unlock
  return key
PUB getData(key,ptr,size_) | iter
  lock
  iter := findKey_(key)
  if iter
    if byte[iter-2] < size_
      size_ := byte[iter-2]
    
    bytemove(ptr, iter-3-byte[iter-2], size_)
  else
    size_~
  unlock
  return size_
PUB removeKey(key): iter
  lock
  iter := findKey_(key)
  if iter
    key := nextEntry(iter)
    bytemove(SettingsBottom+iter-key,SettingsBottom, key-SettingsBottom+1)
  unlock
PUB setData(key,ptr,size_): iter

  ' We set a value by first removing
  ' the previous value and then
  ' appending the value at the end.
  
  removeKey(key)

  lock
  iter := SettingsTop

  ' Runtime sanity check.
  if size_>255
    abort -666

  ' Traverse to the end of the last setting
  repeat while isValidEntry(iter)
    iter:=nextEntry(iter)

  ' Make sure there is enough space left
  if iter-3-size_<SettingsBottom
    unlock
    abort -667

  ' Append the new setting  
  word[iter]:=key
  byte[iter-2]:=size_
  byte[iter-3]:=!size_
  bytemove(iter-3-size_,ptr,size_)

  ' Make sure that this is the last entry.
  iter:=nextEntry(iter)
  if isValidEntry(iter)
    word[iter]~~
    word[iter-1]~~
      
  unlock

PUB getString(key,ptr,size_): strlen
  strlen:=getData(key,ptr,size_-1)
  ' Strings must be zero terminated.
  byte[ptr][strlen]~  
  
PUB setString(key,ptr)
  return setData(key,ptr,strsize(ptr))  
  
PUB getLong(key): retVal
  getData(key,@retVal,4)
  
PUB setLong(key,value)
  return setData(key,@value,4)

PUB getWord(key): retVal
  getData(key,@retVal,2)
  
PUB setWord(key,value)
  return setData(key,@value,2)

PUB getByte(key): retVal
  getData(key,@retVal,1)
  
PUB setByte(key,value)
  return setData(key,@value,1)