{{
** Base16 decoding/encoding functions v0.1
** by Robert Quattlebaum <darco@deepdarc.com>
** PUBLIC DOMAIN
** 2008-05-19
**
}}
PUB inplaceDecode(in_ptr)
{{ Decodes a base16 encoded string in-place. Returns the size of the decoded data. }}
  return decode(in_ptr,in_ptr,POSX)
PUB decode(out_ptr,in_ptr,len)|i,in,char,size
  size:=0
  ifnot in_ptr
    return 0
  repeat
    ifnot BYTE[in_ptr]
      quit
    in:=0
    repeat i from 0 to 1
      repeat while isWhitespace(char:=BYTE[in_ptr++])
      ifnot char
        quit
      BYTE[@in][i]:=char
     
    if (i:=base16_decode_byte(in))=>0
      BYTE[out_ptr++]:=i
      size++
      len--
  while char AND len AND i=>0     
  BYTE[out_ptr]:=0
  return size

PUB encode(out_ptr,in_ptr,len)|val
  repeat while len--
    val:=base16_encode_byte(BYTE[in_ptr++])
    BYTE[out_ptr++]:=BYTE[@val][0]
    BYTE[out_ptr++]:=BYTE[@val][1]
  BYTE[out_ptr]:=0
  return out_ptr
  
PRI isWhitespace(char)
  case char
    9..13,32: return TRUE
    other: return FALSE
PUB base16_to_dec(char) | i
  case char
    "0".."9": return char-"0"
    "a".."f": return char-"a"+10
    "A".."F": return char-"A"+10
    other: return -1
PUB dec_to_base16(dec) | i
  dec&=%1111
  if dec < 10
    return dec+"0"
  return dec+"a"-10
PRI base16_decode_byte(in)
  return base16_to_dec(BYTE[@in][0])<<4+base16_to_dec(BYTE[@in][1])
PRI base16_encode_byte(in):out
  byte[@out][0]:=dec_to_base16(in>>4)
  byte[@out][1]:=dec_to_base16(in)

CON
{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │                                                            
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │ 
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}