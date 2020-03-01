#include "feckinmad/fm_global"
#include "feckinmad/fm_point" // fm_GetAimEntity()

#include "feckinmad/entmod/fm_entmod_misc" // fm_SetKeyValue()
#include "feckinmad/entmod/fm_entmod_base" // fm_DestroyCachedEntKeys() etc
#include "feckinmad/entmod/fm_entmod_move" // fm_SetPlayerMoveEnt() & fm_GetPlayerMoveEnt()
#include "feckinmad/entmod/fm_entmod_command" // fm_CommandGetEntity()
#include "feckinmad/entmod/fm_entmod_access" // fm_CheckUserEntAccess()

#include <fakemeta>

new Float:g_fPlayerNextCopy[MAX_PLAYERS + 1] // Gametime a player can next copy an entity

public plugin_init()
{
	fm_RegisterPlugin()

	register_clcmd("+fm_ent_copy", "Player_StartCopy")
	register_clcmd("-fm_ent_copy", "Player_StopCopy")
}
	
public Player_StartCopy(id)
{
	if (!fm_CheckUserEntAccess(id))
	{
		return PLUGIN_HANDLED
	}

	if (!is_user_alive(id))
	{
		return PLUGIN_HANDLED
	}

	if (fm_GetPlayerMoveEnt(id) > 0)
	{
		return PLUGIN_HANDLED
	}

	new iEnt = fm_GetAimEntity(id)
	if (!iEnt || !fm_CommandCheckEntity(id, iEnt, ENTCMD_READ)) 
	{
		return PLUGIN_HANDLED
	}

	new Float:fGameTime = get_gametime()
	if (g_fPlayerNextCopy[id] > fGameTime)
	{
		return PLUGIN_HANDLED
	}

	new sClassName[32]; pev(iEnt, pev_classname, sClassName, charsmax(sClassName))

	new iNewEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, sClassName))
	if (!iNewEnt)
	{
		return PLUGIN_HANDLED
	}

	fm_DestroyCachedEntKeys(iNewEnt)

	new sKey[32], sValue[32]
	for (new i = 0, iMax = fm_CachedEntKeyCount(iEnt); i < iMax; i++)
	{
		fm_GetCachedEntKeyIndex(iEnt, i, sKey, charsmax(sKey), sValue, charsmax(sValue))			
		fm_SetKeyValue(iNewEnt, sClassName, sKey, sValue)
		fm_PushCachedEntKey(iNewEnt, sKey, sValue)
	}

	dllfunc(DLLFunc_Spawn, iNewEnt)

	new Float:fVector[3]; pev(iEnt, pev_angles, fVector)
	set_pev(iNewEnt, pev_angles, fVector)

	if (iNewEnt > 0) 
	{
		fm_SetPlayerMoveEnt(id, iNewEnt, 0, 255, 0)

		g_fPlayerNextCopy[id] = fGameTime + 1.0

		new sName[MAX_NAME_LEN]; get_user_name(id, sName, charsmax(sName))
		fm_SetCachedEntKey(iNewEnt, "fm_entmod_owner", sName)

	}
	return PLUGIN_HANDLED
}

public Player_StopCopy(id)
{
	fm_StopPlayerMoveEnt(id)
}




/*
	new sBuffer[128], Float:fValue
	for (new i=pev_globalname;i<pev_string_end;i++)
	{
		pev(iOriginalEnt, i, sBuffer, charsmax(sBuffer))
		set_pev(iNewEnt, i, sBuffer)
	}
	for (new i=pev_origin;i<pev_vecarray_end;i++){
		pev(iOriginalEnt,i, fVector)
		set_pev(iNewEnt, i, fVector)
	}
	for (new i=pev_fixangle;i<pev_int_end;i++){
		set_pev(iNewEnt, i, pev(iOriginalEnt,i))
	}
	for (new i=pev_impacttime;i<pev_float_end;i++){
		pev(iOriginalEnt,i, fValue)
		set_pev(iNewEnt, i, fValue)
	}
	for (new i=pev_chain;i<pev_edict_end;i++){
		if (pev_valid(pev(iOriginalEnt,i))){
			set_pev(iNewEnt, i, pev(iOriginalEnt,i))
		}
	}
	for (new i=pev_controller_0;i<pev_byte_end;i++)
		 set_pev(iNewEnt, i, pev(iOriginalEnt,i));
*/
	