
#if defined _fm_entmod_misc_included
  #endinput
#endif
#define _fm_entmod_misc_included

#include <fakemeta>

stock fm_EntSetOrigin(iEnt, Float:fOrigin[3])
{
	fm_EntSetSize(iEnt)
	engfunc(EngFunc_SetOrigin, iEnt, fOrigin)
}

stock fm_EntSetSize(iEnt)
{
	static Float:fMins[3]; pev(iEnt, pev_mins, fMins)
	static Float:fMaxs[3]; pev(iEnt, pev_maxs, fMaxs)
	engfunc(EngFunc_SetSize, iEnt, fMins, fMaxs)
}

stock fm_SetKeyValue(iEnt, sClassName[], sKey[], sValue[]) 
{
	set_kvd(0, KV_ClassName, sClassName)
	set_kvd(0, KV_KeyName, sKey)
	set_kvd(0, KV_Value, sValue)
	set_kvd(0, KV_fHandled, 0)
	dllfunc(DLLFunc_KeyValue, iEnt, 0)
}

stock fm_GetEntOffset(id, iEnt, Float:fOffset[3])
{
	new Float:fOrigin[3]; pev(id, pev_origin, fOrigin)
	new Float:fEntOrigin[3]; pev(iEnt, pev_origin, fEntOrigin)

	for (new i = 0; i < 3; i++) 
	{
		fOffset[i] =  fEntOrigin[i] - fOrigin[i]
	}

	return 1	
}

stock fm_GetBrushOrigin(iEnt, Float:fOrigin[3])
{
	static Float:fMins[3]; pev(iEnt, pev_mins, fMins)
	static Float:fMaxs[3]; pev(iEnt, pev_maxs, fMaxs)
	static Float:fOrigin[3]; pev(iEnt, pev_origin, fOrigin)

	fOrigin[0] += (fMins[0] + fMaxs[0]) * 0.5
	fOrigin[1] += (fMins[1] + fMaxs[1]) * 0.5
	fOrigin[2] += (fMins[2] + fMaxs[2]) * 0.5
}


stock fm_GetAimEntity(id)
{
	new Float:fPlayerOrigin[3]; pev(id, pev_origin, fPlayerOrigin)
	new Float:fPlayerViewOff[3]; pev(id, pev_view_ofs, fPlayerViewOff)
	new Float:fAngles[3]; pev(id, pev_v_angle, fAngles)

	engfunc(EngFunc_MakeVectors, fAngles)
	global_get(glb_v_forward, fAngles)

	new Float:fEndPos[3]
	for (new i = 0; i < 3; i++)
	{
		fPlayerOrigin[i] += fPlayerViewOff[i] // Calculate view offset from origin
		fEndPos[i] = fPlayerOrigin[i] + (fAngles[i] * 4096.0) // Scale up normalised vector
	}
		
	engfunc(EngFunc_TraceLine, fPlayerOrigin, fEndPos , 0, id, 0) // Run trace
	new iEnt = get_tr2(0, TR_pHit) // Get the entity hit

	return iEnt > 0 ? iEnt : 0
}


stock fm_GetAimOrigin(id, Float:fReturn[3], Float:fMaxDist = 4096.0)
{
	new Float:fPlayerOrigin[3]; pev(id, pev_origin, fPlayerOrigin)
	new Float:fPlayerViewOff[3]; pev(id, pev_view_ofs, fPlayerViewOff)
	new Float:fAngles[3]; pev(id, pev_v_angle, fAngles)

	engfunc(EngFunc_MakeVectors, fAngles)
	global_get(glb_v_forward, fAngles)

	new Float:fEndPos[3]
	for (new i = 0; i < 3; i++)
	{
		fPlayerOrigin[i] += fPlayerViewOff[i] // Calculate view offset from origin
		fEndPos[i] = fPlayerOrigin[i] + (fAngles[i] * fMaxDist) // Scale up normalised vector
	}
		
	engfunc(EngFunc_TraceLine, fPlayerOrigin, fEndPos , IGNORE_MONSTERS, id, 0) // Run trace
	get_tr2(0, TR_vecEndPos, fReturn) 

	return 1
}
