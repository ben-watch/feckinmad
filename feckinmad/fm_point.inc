#if defined _fm_point_included
  #endinput
#endif
#define _fm_point_included

#include <fakemeta>

stock fm_GetAimPlayer(id)
{
	new iEnt = fm_GetAimEntity(id)
	if (iEnt > 0 && iEnt <= get_maxplayers())
	{
		return iEnt	
	}
	return 0
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
