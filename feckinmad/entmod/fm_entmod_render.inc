#if defined _fm_entmod_render_included
  #endinput
#endif
#define _fm_entmod_render_included

#include <fakemeta>

#include "feckinmad/entmod/fm_entmod_base"

new const g_sKeyRenderMode[] = "fm_entmod_rendermode"
new const g_sKeyRenderAmt[] = "fm_entmod_renderamt"
new const g_sKeyRenderColour[] = "fm_entmod_rendercolour"

stock fm_TempRenderColour(iEnt, iRed, iGreen, iBlue)
{
	if (!pev_valid(iEnt))
	{
		return 0
	}

	// Store original rendermode
	fm_SetCachedEntKeyInt(iEnt, g_sKeyRenderMode, pev(iEnt, pev_rendermode))

	// Store original rendercolour
	new Float:fColours[3]; pev(iEnt, pev_rendercolor, fColours)
	fm_SetCachedEntKeyVector(iEnt, g_sKeyRenderColour, fColours)

	// Store original renderamt
	pev(iEnt, pev_renderamt, fColours[0])
	fm_SetCachedEntKeyFloat(iEnt, g_sKeyRenderAmt, fColours[0])

	// Set the new colours
	fColours[0] = float(iRed)
	fColours[1] = float(iGreen)
	fColours[2] = float(iBlue)

	set_pev(iEnt, pev_rendermode, kRenderTransColor)
	set_pev(iEnt, pev_rendercolor, fColours)
	set_pev(iEnt, pev_renderamt, 100.0)

	return 1
}

stock fm_RestoreRendering(iEnt)
{
	if (!pev_valid(iEnt))
	{
		return 0
	}

	new sValue[32], iIndex, Float:fValue[3]
	if ((iIndex = fm_GetCachedEntKey(iEnt, g_sKeyRenderMode, sValue, charsmax(sValue))) != -1)
	{
		set_pev(iEnt, pev_rendermode, str_to_num(sValue))
		fm_RemoveCachedEntKeyIndex(iEnt, iIndex)
	}

	if ((iIndex = fm_GetCachedEntKeyVector(iEnt, g_sKeyRenderColour, fValue)) != -1)
	{
		set_pev(iEnt, pev_rendercolor, fValue)
		fm_RemoveCachedEntKeyIndex(iEnt, iIndex)
	}

	if ((iIndex = fm_GetCachedEntKey(iEnt, g_sKeyRenderAmt, sValue, charsmax(sValue))) != -1)
	{
		set_pev(iEnt, pev_renderamt, str_to_float(sValue))
		fm_RemoveCachedEntKeyIndex(iEnt, iIndex)
	}

	return 1
}
