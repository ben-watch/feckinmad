#include "feckinmad/fm_global"

#include "feckinmad/entmod/fm_entmod_base" // fm_DestroyEntKeys()
#include "feckinmad/entmod/fm_entmod_access" // fm_CheckUserEntAccess()
#include "feckinmad/entmod/fm_entmod_command" // fm_CommandGetEntity()

#include <fakemeta>

public  plugin_init()
{
	fm_RegisterPlugin()

	register_clcmd("fm_ent_drop", "Player_DropToFloor")
	register_clcmd("fm_ent_use", "Player_EntUse")
	register_clcmd("fm_ent_sendto", "Player_SendToEnt") 
	register_clcmd("fm_ent_origin", "Player_EntOrigin")
}

public Player_EntOrigin(id)
{
	if (!fm_CheckUserEntAccess(id))
	{
		return PLUGIN_HANDLED
	}

	new sArg[8]; read_argv(1, sArg, charsmax(sArg))
	new iEnt = fm_CommandGetEntity(id, sArg)
	if (!iEnt) 
	{
		iEnt = id
	}

	new Float:fOrigin[3]; pev(iEnt, pev_origin, fOrigin)
	console_print(id, "Origin of #%d: { %f %f %f }", iEnt, fOrigin[0], fOrigin[1], fOrigin[2])
	return PLUGIN_HANDLED
}


public Player_SendToEnt(id)
{
	if (!fm_CheckUserEntAccess(id))
	{
		return PLUGIN_HANDLED
	}

	new sArg[8]; read_argv(1, sArg, charsmax(sArg))
	new iEnt = fm_CommandGetEntity(id, sArg)
	if (!iEnt || !fm_CommandCheckEntity(id, iEnt, ENTCMD_READ)) 
	{
		return PLUGIN_HANDLED
	}

	if (!pev_valid(iEnt))
	{	
		console_print(id, "Invalid entity specified (%d)", iEnt)
		return PLUGIN_HANDLED
	}

	new Float:fOrigin[3]
	new Float:fMins[3]; pev(iEnt, pev_mins, fMins)
	new Float:fMaxs[3]; pev(iEnt, pev_maxs, fMaxs)
	for(new i = 0; i < 3; i++)
		fOrigin[i] = (fMins[i] + fMaxs[i]) * 0.5

	set_pev(id, pev_origin, fOrigin)
	return PLUGIN_HANDLED
}


public Player_EntUse(id)
{
	if (!fm_CheckUserEntAccess(id))
	{
		return PLUGIN_HANDLED
	}

	new sArg[8]; read_argv(1, sArg, charsmax(sArg))
	new iEnt = fm_CommandGetEntity(id, sArg)
	if (!iEnt || !fm_CommandCheckEntity(id, iEnt, ENTCMD_MODIFY)) 
	{
		return PLUGIN_HANDLED
	}
	
	dllfunc(DLLFunc_Use, iEnt, id)

	return PLUGIN_HANDLED
}

public Player_DropToFloor(id)
{
	if (!fm_CheckUserEntAccess(id))
	{
		return PLUGIN_HANDLED
	}

	new sArg[8]; read_argv(1, sArg, charsmax(sArg))
	new iEnt = fm_CommandGetEntity(id, sArg)
	if (!iEnt || !fm_CommandCheckEntity(id, iEnt, ENTCMD_MODIFY)) 
	{
		return PLUGIN_HANDLED
	}
	
	engfunc(EngFunc_DropToFloor, iEnt)
	return PLUGIN_HANDLED
}

