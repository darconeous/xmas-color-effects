{{
  Basic HTTP authentication object
  By Robert Quattlebaum <darco@deepdarc.com>

  Written in such a way as to make it easy to migrate to an
  MD5 digest mechanism later on.
}}
obj
  settings : "settings"
  base64 : "base64"
CON
  STAT_UNAUTH =  FALSE
  STAT_STALE =   $80
  STAT_AUTH =    TRUE
DAT
type byte "Basic"
pub init(random)
{{ Placeholder. Doesn't do anything for basic authentication. }}
pub authenticateResponse(str,method,uriPath) | i,buffer[20]
  ' Skip past the word "Basic"
  repeat i from 0 to 4
    if byte[str][i]<>type[i]
      return STAT_UNAUTH
  str+=i+1

  base64.inplaceDecode(str)

  settings.getString(settings#MISC_PASSWORD,@buffer,80)

  ' This check gives us compatibility with
  ' the earlier way passwords were handled.
  if strcomp(str,@buffer)
    return STAT_AUTH

  'Skip past username
  repeat while byte[str]<>":"
    if byte[str]==0
      return STAT_UNAUTH
    str++
  byte[str++]~
    
  if strcomp(str,@buffer)
    return STAT_AUTH
  return STAT_UNAUTH
     
pub generateChallenge(dest,len,authstate)
  bytemove(dest,string("Basic realm='ybox2'"),len)
  return 0

pub setAdminPassword(str)
  if byte[str]
    settings.setString(settings#MISC_PASSWORD,str)
  else
    settings.removeKey(settings#MISC_PASSWORD)
  settings.commit
         