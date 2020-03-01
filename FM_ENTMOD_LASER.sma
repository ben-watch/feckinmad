#include "feckinmad/fm_global"

#include "feckinmad/entmod/fm_entmod_base" // fm_SetCachedEntKey()
#include "feckinmad/entmod/fm_entmod_access" // fm_CheckUserEntAccess()
#include "feckinmad/entmod/fm_entmod_misc"

#include <fakemeta>

new g_sLaserEntity[] = "env_laser"
new g_sInfoTarget[] = "info_target"

public plugin_init()
{
	fm_RegisterPlugin()

	register_clcmd("fm_ent_startlaser", "Player_CreateLaserStart")
	register_clcmd("fm_ent_endlaser", "Player_CreateLaserEnd")
}

public plugin_precache()
	engfunc(EngFunc_PrecacheModel, "sprites/laserbeam.spr")	

public Player_CreateLaserStart(id)
{
	if (!fm_CheckUserEntAccess(id))
		return PLUGIN_HANDLED

	new sArgs[32]; read_args(sArgs, charsmax(sArgs))
	trim(sArgs)
	if (!sArgs[0])
	{
		console_print(id, "You must supply a name for the laser")
		return PLUGIN_HANDLED
	}

	new iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, g_sLaserEntity))
	if (!iEnt)
	{
		console_print(id, "Failed to create \"%s\" entity", g_sLaserEntity)	
		return PLUGIN_HANDLED
	}

	console_print(id, "Created laser \"%s\" start entity (#%d)", sArgs, iEnt)
	fm_SetCachedEntKey(iEnt, "classname", g_sLaserEntity) // Store classname
	
	fm_SetKeyValue(iEnt, g_sLaserEntity, "spawnflags", "1") // Start On
	fm_SetCachedEntKey(iEnt, "spawnflags", "1") 

	fm_SetKeyValue(iEnt, g_sLaserEntity, "renderamt", "100") 
	fm_SetCachedEntKey(iEnt, "renderamt", "100") 

	fm_SetKeyValue(iEnt, g_sLaserEntity, "rendercolor", "255 0 0")
	fm_SetCachedEntKey(iEnt, "rendercolor", "255 0 0") 

	fm_SetKeyValue(iEnt, g_sLaserEntity, "width", "25") 
	fm_SetCachedEntKey(iEnt, "width", "25") 

	fm_SetKeyValue(iEnt, g_sLaserEntity, "TextureScroll", "35")
	fm_SetCachedEntKey(iEnt, "TextureScroll", "35") 

	fm_SetKeyValue(iEnt, g_sLaserEntity, "texture", "sprites/laserbeam.spr")
	fm_SetCachedEntKey(iEnt, "texture", "sprites/laserbeam.spr")

	fm_SetKeyValue(iEnt, g_sLaserEntity, "damage", "0")
	fm_SetCachedEntKey(iEnt, "damage", "0")

	fm_SetKeyValue(iEnt, g_sLaserEntity, "LaserTarget", sArgs)
	fm_SetCachedEntKey(iEnt, "LaserTarget", sArgs)

	new Float:fOrigin[3]; fm_GetAimOrigin(id, fOrigin)
	new sBuffer[64]; formatex(sBuffer, charsmax(sBuffer), "%0.4f %0.4f %0.4f", fOrigin[0], fOrigin[1], fOrigin[2])//floatround(fOrigin[0]), floatround(fOrigin[1]), floatround(fOrigin[2]))
	fm_SetKeyValue(iEnt, g_sLaserEntity, "origin", sBuffer)
	fm_SetCachedEntKey(iEnt, "origin", sBuffer)

	dllfunc(DLLFunc_Spawn, iEnt)

	return PLUGIN_HANDLED
}

public Player_CreateLaserEnd(id)
{
	if (!fm_CheckUserEntAccess(id))
		return PLUGIN_HANDLED

	new iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, g_sInfoTarget))
	if (!iEnt)
	{
		console_print(id, "Failed to create \"%s\" entity", g_sInfoTarget)
		return PLUGIN_HANDLED
	}
	fm_SetCachedEntKey(iEnt, "classname", g_sInfoTarget) // Store classname
	

	new sArgs[32]; read_args(sArgs, charsmax(sArgs))
	trim(sArgs)

	if (!sArgs[0])
	{
		console_print(id, "You must supply a name for the laser")
		return PLUGIN_HANDLED
	}

	set_pev(iEnt, pev_targetname, sArgs)
	fm_SetCachedEntKey(iEnt, "targetname", sArgs) 

	new Float:fOrigin[3]; fm_GetAimOrigin(id, fOrigin)
	set_pev(iEnt, pev_origin, fOrigin)
	fm_SetCachedEntKeyVector(iEnt, "origin", fOrigin)

	console_print(id, "Created laser \"%s\" end entity (#%d)", sArgs, iEnt)

	return PLUGIN_HANDLED
}