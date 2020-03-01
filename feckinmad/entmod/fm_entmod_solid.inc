#if defined _fm_entmod_solid_included
  #endinput
#endif
#define _fm_entmod_solid_included

#include "feckinmad/entmod/fm_entmod_base"

new const g_sKeySolid[] = "fm_entmod_solid"

stock fm_TempSetSolidity(iEnt, iSolid)
{
	if (!pev_valid(iEnt))
	{
		return 0
	}

	fm_SetCachedEntKeyInt(iEnt, g_sKeySolid, pev(iEnt, pev_solid))
	set_pev(iEnt, pev_solid, iSolid)

	return 1
}


stock fm_RestoreSolidity(iEnt)
{
	if (!pev_valid(iEnt))
	{
		return 0
	}

	new sValue[32], iIndex
	if ((iIndex = fm_GetCachedEntKey(iEnt, g_sKeySolid, sValue, charsmax(sValue))) != -1)
	{
		set_pev(iEnt, pev_solid, str_to_num(sValue))
		fm_EntSetSize(iEnt)
		fm_RemoveCachedEntKeyIndex(iEnt, iIndex)
		return 1
	}

	return 0
}
	