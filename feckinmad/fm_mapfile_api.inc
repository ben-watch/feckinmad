#if defined _fm_mapfile_api_included
  #endinput
#endif
#define _fm_mapfile_api_included

#pragma reqlib "fm_mapfile_api"

native fm_IsMapInMapsFile(sMap[])
native fm_GetMapCount()
native fm_GetMapNameByIndex(iIndex, sMap[], iLen)
native fm_ReloadMapList()
