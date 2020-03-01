#if defined _fm_mapvote_nominate_included
  #endinput
#endif
#define _fm_mapvote_nominate_included

#pragma reqlib fm_mapvote_nominate

native fm_NominateMap(id, sMap[])
native fm_GetNominatedMapByIndex(iIndex, sMap[], iLen)
native fm_IsMapNominated(sMap[])
native fm_PrintNominations()