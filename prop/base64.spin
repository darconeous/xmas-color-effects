{{
** Base64 decoding/encoding functions v0.1
** by Robert Quattlebaum <darco@deepdarc.com>
** PUBLIC DOMAIN
** 2008-04-18
**
** TODO: Implement this in ASM!
** TODO: Implement encoder!    
}}
PUB inplaceDecode(in_ptr) | out_ptr,i,in,char,size
{{ Decodes a base64 encoded string in-place. Returns the size of the decoded data. }}
  out_ptr:=in_ptr
  size:=0
  repeat
    ifnot BYTE[in_ptr]
      quit
    repeat i from 0 to 3
      repeat while isWhitespace(char:=BYTE[in_ptr++])
      ifnot char
        BYTE[@in][i]:="="
        in_ptr--
        quit
      else
        BYTE[@in][i]:=char
     
    i:=base64_decode_4(@in,out_ptr)
    out_ptr+=i
    size+=i
  while char AND i==3     
  BYTE[out_ptr]:=0
  return size
PRI isWhitespace(char)
  case char
    9..13,32: return TRUE
    other: return FALSE
pri base64_tlu(char) | i
  case char
    "A".."Z": return char-"A"
    "a".."z": return char-"a"+26
    "0".."9": return char-"0"+52
    "+": return 62
    "/": return 63
    other: return 0
PRI base64_decode_4(inptr,outptr) | retVal,i,out
  out:=0
  retVal:=3
  repeat i from 0 to 3
    if(BYTE[inptr][i]=="=")
      case i
        3: retVal:=2
        2: retVal:=1
        1: retVal:=0
        0: retVal:=0
      quit
    out|=\base64_tlu(BYTE[inptr][i])<<((3-i)*6)
  if retVal
    repeat i from 0 to retVal-1
      BYTE[outptr][i]:=BYTE[@out][2-i]
  return retVal
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