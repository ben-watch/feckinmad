#include "feckinmad/fm_global"
#include "feckinmad/entmod/fm_entmod_misc"
#include "feckinmad/entmod/fm_entmod_base"
#include "feckinmad/entmod/fm_entmod_access"

#include <fakemeta>

public plugin_init()
{
	fm_RegisterPlugin()

	register_clcmd("fm_ent_create", "Player_CreateEnt")
}

public Player_CreateEnt(id)
{
	if (!fm_CheckUserEntAccess(id))
	{
		return PLUGIN_HANDLED
	}

	new sArgs[32]; read_args(sArgs, charsmax(sArgs))
	trim(sArgs)

	if (!sArgs[0])
	{
		console_print(id, "You must specify a classname")	
		return PLUGIN_HANDLED
	}	

	new iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, sArgs))
	if (!iEnt)
	{
		console_print(id, "Failed to create entity")	
		return PLUGIN_HANDLED
	}

	console_print(id, "Created entity: %d %s", iEnt, sArgs)
	fm_SetCachedEntKey(iEnt, "classname", sArgs)
		
	new Float:fOrigin[3]; pev(id, pev_origin, fOrigin)

	new sBuffer[64]; formatex(sBuffer, charsmax(sBuffer), "%d %d %d", floatround(fOrigin[0]), floatround(fOrigin[1]), floatround(fOrigin[2]))
	fm_SetCachedEntKey(iEnt, "origin", sBuffer)
	fm_SetKeyValue(iEnt, sArgs, "origin", sBuffer)	

	return PLUGIN_HANDLED
}
