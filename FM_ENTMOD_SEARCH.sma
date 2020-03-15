#include "feckinmad/fm_global"
#include "feckinmad/entmod/fm_entmod_access" // fm_CheckUserEntAccess()

#include <fakemeta>

public plugin_init()
{
	fm_RegisterPlugin()

	register_clcmd("fm_ent_search", "Player_EntSearch", -1, "<key> <value> - Lists entities which match specified key and value")
	register_clcmd("fm_ent_nearby", "Player_EntNearby", -1, "- Lists entities within 250 units of your position")
}

public Player_EntNearby(id, iLevel, iCommand)
{
	if (!fm_CheckUserEntAccess(id))
	{
		return PLUGIN_HANDLED
	}

	new iEnt, iCount, sClassname[32]
	new Float:fOrigin[3], Float:fEntOrigin[3]

	pev(id, pev_origin, fOrigin)	
	while ((iEnt = engfunc(EngFunc_FindEntityInSphere, iEnt, fOrigin, 250.0)) > 0)
	{
		pev(iEnt, pev_classname, sClassname, charsmax(sClassname))
		if (equal(sClassname, "player") || equal(sClassname, "tf_weapon", 9))
		{
			continue
		}

		pev(iEnt, pev_origin, fEntOrigin)
		console_print(id, "#%d %s %0.2f", iEnt, sClassname, get_distance_f(fOrigin, fEntOrigin))

		iCount++
	}
	console_print(id, "Total: %d", iCount)
	return PLUGIN_HANDLED
}

public Player_EntSearch(id, iLevel, iCommand)
{
	if (!fm_CheckUserEntAccess(id) || !fm_CommandUsage(id, iCommand, 3, 1))
	{
		return PLUGIN_HANDLED
	}

	new sBuffer[128]; read_args(sBuffer, charsmax(sBuffer))
	new sArg1[32], sArg2[128]; argbreak(sBuffer, sArg1, charsmax(sArg1), sArg2, charsmax(sArg2))

	new iEnt, iCount, sClassname[32]
	while ((iEnt = engfunc(EngFunc_FindEntityByString, iEnt, sArg1, sArg2)) > 0)
	{
		pev(iEnt, pev_classname, sClassname, charsmax(sClassname))	
		console_print(id, "#%d %s", iEnt, sClassname)
		iCount++
	}
	console_print(id, "Total: %d", iCount)
	return PLUGIN_HANDLED
}
