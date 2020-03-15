#include "feckinmad/fm_global"
#include "feckinmad/fm_speedrun_api"

#include <fakemeta>

new bool:g_bSpeedRunningStatus

new bool:g_bPlayerSpeedrunning[MAX_PLAYERS + 1] 
new Float:g_fPlayerStartTime[MAX_PLAYERS + 1] // Gametime the player started the speedrun
new g_iMaxPlayers

new const g_sPlayerStartedForward[] = "fm_PlayerStartedSpeedRunning"
new const g_sPlayerStoppedForward[] = "fm_PlayerStoppedSpeedRunning"
new g_iStartForward, g_iStopForward

public plugin_init()
{
	fm_RegisterPlugin()

	g_iMaxPlayers = get_maxplayers()

	register_clcmd("say", "Handle_Say")
	register_clcmd("say_team", "Handle_Say")

	// Called when a player starts a speedrun
	g_iStartForward = CreateMultiForward(g_sPlayerStartedForward, ET_IGNORE, FP_CELL)
	if (g_iStartForward < 0)
	{
		fm_WarningLog(FM_FORWARD_WARNING, g_sPlayerStartedForward)
	}

	// Called when a player ends or aborts a speedrun
	g_iStopForward = CreateMultiForward(g_sPlayerStoppedForward, ET_IGNORE, FP_CELL, FP_CELL)
	if (g_iStopForward < 0)
	{
		fm_WarningLog(FM_FORWARD_WARNING, g_sPlayerStoppedForward)
	}
}

public plugin_natives()
{
	register_native("fm_ReadyToSpeedRun", "Native_ReadyToSpeedRun")
	register_native("fm_GetSpeedRunStatus", "Native_GetSpeedRunStatus")
	register_native("fm_IsUserSpeedRunning", "Native_IsUserSpeedRunning")
	register_native("fm_GetUserSpeedRunTime", "Native_GetUserSpeedRunTime")
	register_native("fm_StartSpeedRunning", "Native_StartSpeedRunning")
	register_native("fm_StopSpeedRunning", "Native_StopSpeedRunning")

	register_library("fm_speedrun_api")
}

// Other plugins call this when the are ready. If they return plugin_handled they are not ready and speedrunning isn't enabled yet
// This is used to ensure the flag data from the db and the speedrun data from the db have both loaded. but makes the plugin more modular if we wish to expand
public Native_ReadyToSpeedRun(iPlugin, iParams)
{
	fm_DebugPrintLevel(1, "Native_ReadyToSpeedRun(%d, %d)", iPlugin, iParams)

	new iReturn, iForward = CreateMultiForward("fm_CanEnableSpeedRun", ET_STOP)
	ExecuteForward(iForward, iReturn)
	if (iReturn == PLUGIN_HANDLED)
	{
		return 0
	}

	iForward = CreateMultiForward("fm_InitSpeedRunning", ET_IGNORE)
	ExecuteForward(iForward, iReturn)

	g_bSpeedRunningStatus = true

	return 1
}

public fm_InitSpeedRunning()
{
	register_event("DeathMsg", "Event_Death", "a")
}

public Native_GetSpeedRunStatus(iPlugin, iParams)
{
	return g_bSpeedRunningStatus
}

public Native_StartSpeedRunning(iPlugin, iParams)
{
	fm_DebugPrintLevel(1, "Native_StartSpeedRunningn(%d, %d)", iPlugin, iParams)

	new id = get_param(1)

	if (id < 1 || id > g_iMaxPlayers)
	{
		log_error(AMX_ERR_NATIVE, "Player out of range (%d)", id)
		return 0
	}

	if (!is_user_connected(id))
	{
		log_error(AMX_ERR_NATIVE, "Invalid player (%d)", id)
		return 0
	}

	new iReturn; ExecuteForward(g_iStartForward, iReturn, id)

	g_fPlayerStartTime[id] = get_gametime()
	g_bPlayerSpeedrunning[id] = true

	return 1
}

public Native_StopSpeedRunning(iPlugin, iParams)
{
	fm_DebugPrintLevel(1, "Native_StopSpeedRunning(%d, %d)", iPlugin, iParams)

	new id = get_param(1)

	if (id < 1 || id > g_iMaxPlayers)
	{
		log_error(AMX_ERR_NATIVE, "Player out of range (%d)", id)
		return 0
	}

	if (!is_user_connected(id))
	{
		log_error(AMX_ERR_NATIVE, "Invalid player (%d)", id)
		return 0
	}

	new iTime, iAborted = get_param(2)
	if (iAborted)
	{
		iTime = -1
	}
	else
	{
		iTime = floatround((get_gametime() - g_fPlayerStartTime[id]) * 100)	
		new sTime[16]; fm_FormatSpeedRunTime(iTime, sTime, charsmax(sTime))
		new sName[MAX_NAME_LEN]; get_user_name(id, sName, charsmax(sName))

		client_print(0, print_chat,"* \"%s\" has finished speedrunning in %s", sName, sTime)
	}

	ResetPlayerSpeedRun(id, iTime) 

	return 1
}

public Native_IsUserSpeedRunning(iPlugin, iParams)
{
	new id = get_param(1)

	if (id < 1 || id > g_iMaxPlayers)
	{
		log_error(AMX_ERR_NATIVE, "Player out of range (%d)", id)
		return 0
	}

	if (!is_user_connected(id))
	{
		log_error(AMX_ERR_NATIVE, "Invalid player (%d)", id)
		return 0
	}

	return g_bPlayerSpeedrunning[id]
}


public Native_GetUserSpeedRunTime(iPlugin, iParams)
{
	new id = get_param(1)

	if (id < 1 || id > g_iMaxPlayers)
	{
		log_error(AMX_ERR_NATIVE, "Player out of range (%d)", id)
		return 0
	}

	if (!is_user_connected(id))
	{
		log_error(AMX_ERR_NATIVE, "Invalid player (%d)", id)
		return 0
	}

	return floatround((get_gametime() - g_fPlayerStartTime[id]) * 100)
}

public Handle_Say(id)
{
	new sArgs[192]; read_args(sArgs, charsmax(sArgs))
	remove_quotes(sArgs)
	
	if (!sArgs[0])
		return PLUGIN_HANDLED
		

	if (equali(sArgs, "/stop"))
	{
		StopTimer(id)
		return PLUGIN_HANDLED
	}

	return PLUGIN_CONTINUE
}

StopTimer(id)
{
	if (g_bPlayerSpeedrunning[id]) 
	{
		ResetPlayerSpeedRun(id, -1) 
		client_print(id, print_chat, "* You have stopped your speedrun")
	} 
	else
		client_print(id, print_chat, "* You are not currently speedrunning")

}

ResetPlayerSpeedRun(id, iTime) 
{
	g_fPlayerStartTime[id] = 0.0
	g_bPlayerSpeedrunning[id] = false

	new iReturn; ExecuteForward(g_iStopForward, iReturn, id, iTime)	
}


public Event_Death() 
{
	new id = read_data(2)
	
	if (g_bPlayerSpeedrunning[id])	
	{
		ResetPlayerSpeedRun(id, -1) 
	}
}
