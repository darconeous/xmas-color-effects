{{
  MD5 Hash in Spin
  Written by Robert Quattlebaum <darco@deepdarc.com>
  Adapted from pseudo code from http://en.wikipedia.org/wiki/MD5.

  This code is hereby released into the PUBLIC DOMAIN. In jurisdictions where this
  is not legally possible, this code is released under the "MIT license":

    Permission is hereby granted, free of charge, to any person obtaining a copy of
    this software and associated documentation files (the "Software"), to deal in
    the Software without restriction, including without limitation the rights to use,
    copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the
    Software, and to permit persons to whom the Software is furnished to do so, subject
    to the following conditions:                                                                   
                                                                                                                              
    The above copyright notice and this permission notice shall be included in all copies
    or substantial portions of the Software.
                                                                                                                                
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
    INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
    PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
    HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
    CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
    OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
}}
CON { Public Constants }
  HASH_LENGTH = 16 ' An MD5 hash is 16 bytes long
  BLOCK_LENGTH = 64 ' Block length is 64 bytes  
DAT { Tables }

k       long  $D76AA478, $E8C7B756, $242070DB, $C1BDCEEE, $F57C0FAF, $4787C62A, $A8304613, $FD469501
        long  $698098D8, $8B44F7AF, $FFFF5BB1, $895CD7BE, $6B901122, $FD987193, $A679438E, $49B40821
        long  $F61E2562, $C040B340, $265E5A51, $E9B6C7AA, $D62F105D, $02441453, $D8A1E681, $E7D3FBC8
        long  $21E1CDE6, $C33707D6, $F4D50D87, $455A14ED, $A9E3E905, $FCEFA3F8, $676F02D9, $8D2A4C8A
        long  $FFFA3942, $8771F681, $6D9D6122, $FDE5380C, $A4BEEA44, $4BDECFA9, $F6BB4B60, $BEBFBC70
        long  $289B7EC6, $EAA127FA, $D4EF3085, $04881D05, $D9D4D039, $E6DB99E5, $1FA27CF8, $C4AC5665
        long  $F4292244, $432AFF97, $AB9423A7, $FC93A039, $655B59C3, $8F0CCC92, $FFEFF47D, $85845DD1
        long  $6FA87E4F, $FE2CE6E0, $A3014314, $4E0811A1, $F7537E82, $BD3AF235, $2AD7D2BB, $EB86D391
         
r       byte  7, 12, 17, 22,  7, 12, 17, 22,  7, 12, 17, 22,  7, 12, 17, 22
        byte  5,  9, 14, 20,  5,  9, 14, 20,  5,  9, 14, 20,  5,  9, 14, 20
        byte  4, 11, 16, 23,  4, 11, 16, 23,  4, 11, 16, 23,  4, 11, 16, 23
        byte  6, 10, 15, 21,  6, 10, 15, 21,  6, 10, 15, 21,  6, 10, 15, 21

initial_hash long $67452301, $EFCDAB89, $98BADCFE, $10325476

hash_name byte "MD5",0

PUB hash(dataptr,datalen,h)
{{ Generates a hash of data in memory in one step }}

  ' Initializes the hash values
  hashstart(h)

  ' We don't need to call hashBlock directly because
  ' all of the data we are hashing is already in memory.
  
  ' Hash the data.  
  hashfinish(dataptr,datalen,datalen,h)
  
PUB hashStart(h)
  longmove(h,@initial_hash,constant(HASH_LENGTH/4))
  
PUB hashBlock(dataptr,h)|i,a,b,c,d,f,g,tmp
  longmove(@a,h,constant(HASH_LENGTH/4))

  repeat i from 0 to 15
    f := (b & c) | ((! b) & d)
    g := i

  repeat i from 16 to 31
    f := (d & b) | ((! d) & c)
    g := (5*i + 1) & 15

  repeat i from 32 to 47
    f := b ^ c ^ d
    g := (3*i + 5) & 15

  repeat i from 48 to 63
    f := c ^ (b | (! d))
    g := (7*i) & 15

{
  repeat i from 0 to 63
    case i
      0 .. 15:
        f := (b & c) | ((! b) & d)
        g := i
      16 .. 31:
        f := (d & b) | ((! d) & c)
        g := (5*i + 1) & 15
      32 .. 47:
        f := b ^ c ^ d
        g := (3*i + 5) & 15
      48 .. 63:
        f := c ^ (b | (! d))
        g := (7*i) & 15
}

    tmp := d
    d := c
    c := b
    b += (a + f + k[i] + LONG[dataptr][g]) <- r[i]
    a := tmp
     
  LONG[h][0]+=a
  LONG[h][1]+=b
  LONG[h][2]+=c
  LONG[h][3]+=d
         
PUB hashFinish(dataptr,datalen,totallen,h)|a[BLOCK_LENGTH/4]
  repeat while datalen => BLOCK_LENGTH
    hashBlock(dataptr,h)
    datalen-=BLOCK_LENGTH
    dataptr+=BLOCK_LENGTH
  longfill(@a,0,constant(BLOCK_LENGTH/4))
  bytemove(@a,dataptr,datalen)
  BYTE[@a][datalen]:=$80
  if datalen>BLOCK_LENGTH-9
    hashBlock(@a,h)     
    longfill(@a,0,constant(BLOCK_LENGTH/4))
  LONG[@a][14]:=totallen*8
  hashBlock(@a,h)     
  longfill(@a,0,constant(BLOCK_LENGTH/4))
PUB hashName
  return hash_name
