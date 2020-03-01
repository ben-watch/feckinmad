#include "feckinmad/fm_global"
#include "feckinmad/entmod/fm_entmod_misc" // fm_SetKeyValue()
#include "feckinmad/entmod/fm_entmod_base" // fm_SetCachedEntKey() & fm_CachedEntKeyCount() & fm_GetCachedEntKeyIndex()
#include "feckinmad/entmod/fm_entmod_command" // fm_CommandGetEntity()
#include "feckinmad/entmod/fm_entmod_access" // fm_CheckUserEntAccess()

#include <fakemeta>

public plugin_init()
{
	fm_RegisterPlugin()

	register_clcmd("fm_ent_info", "Player_EntInfo")
	register_clcmd("fm_ent_key", "Player_EntSetKey")
	register_clcmd("fm_ent_spawn", "Player_EntSpawn")	
}

public Player_EntInfo(id)
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

	new iMax = fm_CachedEntKeyCount(iEnt)

	new sClassName[32]; pev(iEnt, pev_classname, sClassName, charsmax(sClassName))

	console_print(id, "\nEntity: %d - pev_classname: %s", iEnt, sClassName)
	console_print(id, "{")

	new sKey[32], sValue[32]
	for (new i = 0; i < iMax; i++)
	{
		fm_GetCachedEntKeyIndex(iEnt, i, sKey, charsmax(sKey), sValue, charsmax(sValue))

		if (!equal(sKey, "fm_", 3))
		{			
			console_print(id, "\t\t\t\"%s\" \"%s\"", sKey, sValue)
		}
	}

	console_print(id, "}")
	return PLUGIN_HANDLED
}

public Player_EntSpawn(id)
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

	dllfunc(DLLFunc_Spawn, iEnt)

	new sClassName[32]; pev(iEnt, pev_classname, sClassName, charsmax(sClassName))
	console_print(id, "Entity #%d \"%s\": Spawned", iEnt, sClassName)

	return PLUGIN_HANDLED
}

public Player_EntSetKey(id)
{
	if (!fm_CheckUserEntAccess(id))
	{
		return PLUGIN_HANDLED
	}

	new sBuffer[255]; read_args(sBuffer, charsmax(sBuffer))

	new sArg1[8]; strbreak(sBuffer, sArg1, charsmax(sArg1), sBuffer, charsmax(sBuffer))
	new iEnt = fm_CommandGetEntity(id, sArg1)
	if (!iEnt || !fm_CommandCheckEntity(id, iEnt, ENTCMD_MODIFY)) 
	{
		return PLUGIN_HANDLED
	}

	new sArg2[32], sArg3[128]
	strbreak(sBuffer, sArg2, charsmax(sArg2), sArg3, charsmax(sArg3))

	if (!sArg2[0])
	{
		console_print(id, "You must specify a key")
		return PLUGIN_HANDLED
	}

	if (equal(sArg2, "fm_", 3))
	{
		console_print(id, "Reserved key")
		return PLUGIN_HANDLED
	}

	trim(sArg3)

	if (equal(sArg2, "model") && sArg3[0] == '*')
	{
		if (!fm_IsValidBrushModel(str_to_num(sArg3[1])))
		{
			console_print(id, "Invalid brush model specified")
			return PLUGIN_HANDLED
		}
	}
	
	new sClassName[32]; pev(iEnt, pev_classname, sClassName, charsmax(sClassName))
	fm_SetCachedEntKey(iEnt, sArg2, sArg3)
	fm_SetKeyValue(iEnt, sClassName, sArg2, sArg3)
	console_print(id, "Entity #%d \"%s\": Set key %s to \"%s\"", iEnt, sClassName, sArg2, sArg3)

	return PLUGIN_HANDLED
}
