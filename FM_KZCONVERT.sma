#include "feckinmad/fm_global"
#include "feckinmad/fm_mapfunc"

#include <fakemeta>

new g_sDetectEnt[] = "info_tfdetect"
new g_sConvertFile[] = "fm_kzconvert.ini"
new g_iForward, g_iDetectEnt

SetKeyValue(iEnt, sClassName[], sKey[], sValue[]) 
{
	set_kvd(0, KV_ClassName, sClassName)
	set_kvd(0, KV_KeyName, sKey)
	set_kvd(0, KV_Value, sValue)
	set_kvd(0, KV_fHandled, 0)
	dllfunc(DLLFunc_KeyValue, iEnt, 0)
}

public plugin_precache()
{
	new sCurrentMap[MAX_MAP_LEN]; get_mapname(sCurrentMap, charsmax(sCurrentMap))
	new sFile[128]; fm_BuildAMXFilePath(g_sConvertFile, sFile, charsmax(sFile), "amxx_configsdir")

	if (!fm_IsMapNameInFile(sCurrentMap, sFile))
	{
		return PLUGIN_CONTINUE
	}

	g_iForward = register_forward(FM_KeyValue, "Forward_KeyValue")
		
	g_iDetectEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, g_sDetectEnt))
	if (g_iDetectEnt)
	{
		SetKeyValue(g_iDetectEnt, g_sDetectEnt, "team1_name", "Climbers")
		SetKeyValue(g_iDetectEnt, g_sDetectEnt, "maxammo_shells", "-1")
		SetKeyValue(g_iDetectEnt, g_sDetectEnt, "number_of_teams", "1")

		dllfunc(DLLFunc_Spawn, g_iDetectEnt)
	}
	return PLUGIN_CONTINUE
}

// Remove the crash bug with negative damage ents they put in kz maps to give lots of health
public Forward_KeyValue(iEnt, Kvd)
{
	if (!pev_valid(iEnt))
	{
		return FMRES_IGNORED
	}

	static sBuffer[32]; sBuffer[0] = 0
	get_kvd(Kvd, KV_KeyName, sBuffer, charsmax(sBuffer))
	
	if (equal(sBuffer, "dmg") || equal(sBuffer, "damage"))
	{
		get_kvd(Kvd, KV_Value, sBuffer, charsmax(sBuffer))
		if (str_to_num(sBuffer) < 0) 
		{
			set_kvd(Kvd, KV_Value, "0")
		}
	}
	return FMRES_IGNORED
}

public plugin_init()
{
	fm_RegisterPlugin()

	if (g_iForward)
	{
		unregister_forward(FM_KeyValue, g_iForward)
	}

	if (g_iDetectEnt)
	{
		// Find the first player start to exlude it from being coverted
		new iEnt = engfunc(EngFunc_FindEntityByString, 0, "classname", "info_player_start")

		while ((iEnt = engfunc(EngFunc_FindEntityByString, iEnt, "classname", "info_player_start")) > 0)
		{	
			set_pev(iEnt, pev_classname, "info_player_teamspawn")
			SetKeyValue(iEnt, "info_player_teamspawn", "team_no", "1") //set_pev(iEnt, pev_team, 1)
			
		}
		iEnt = 0
	
		while ((iEnt = engfunc(EngFunc_FindEntityByString, iEnt, "classname", "info_player_deathmatch")) > 0)
		{	
			set_pev(iEnt, pev_classname, "info_player_teamspawn")
			SetKeyValue(iEnt, "info_player_teamspawn", "team_no", "1") //set_pev(iEnt, pev_team, 1)	
		}
	}
}
