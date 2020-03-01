#if defined _fm_voice_api_included
  #endinput
#endif
#define _fm_voice_api_included

#pragma reqlib "fm_voice_api"

#define SPEAK_MUTED	0
#define SPEAK_NORMAL	1

native fm_SetVoiceListening(iReciever, iSender, iListening)
native fm_GetVoiceListening(iReciever, iSender)