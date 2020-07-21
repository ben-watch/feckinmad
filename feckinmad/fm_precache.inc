#if defined _fm_precache_included
  #endinput
#endif
#define _fm_precache_included

#include <fakemeta> // engfunc(...)
#include "feckinmad/fm_global" // for fm_WarningLog()

stock fm_SafePrecacheSound(const sFile[])
{
	new sFilePath[128]; formatex(sFilePath, charsmax(sFilePath), "sound/%s", sFile)

	if (!file_exists(sFilePath))
	{
		fm_WarningLog("Failed to precache sound \"%s\"", sFilePath)
		return 0
	}
	return engfunc(EngFunc_PrecacheSound, sFile)
}

stock fm_SafePrecacheModel(const sFile[])
{
	if (!file_exists(sFile))
	{
		fm_WarningLog("Failed to precache model \"%s\"", sFile)
		return 0
	}
	return engfunc(EngFunc_PrecacheModel, sFile)
}

stock fm_SafePrecacheGeneric(const sFile[])
{
	if (!file_exists(sFile))
	{
		fm_WarningLog("Failed to precache generic \"%s\"", sFile)
		return 0
	}
	return engfunc(EngFunc_PrecacheGeneric, sFile)
}