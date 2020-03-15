#include "feckinmad/fm_global"
#include "feckinmad/fm_speedrun_api"
#include "feckinmad/fm_precache"

#include <fakemeta>

#define CLOCK_UPDATE_FREQUENCY 1.0

new const g_sClockModel[] = "models/fm/speedrun/fm_stopwatch.mdl" 
new g_iPlayerClockEnt[MAX_PLAYERS + 1], g_iMaxPlayers

public plugin_precache()
{
	fm_SafePrecacheModel(g_sClockModel)
}

public plugin_init()
{
	fm_RegisterPlugin()
}

RemoveClock(id)
{
	if (g_iPlayerClockEnt[id])
	{
		engfunc(EngFunc_RemoveEntity, g_iPlayerClockEnt[id])
		g_iPlayerClockEnt[id] = 0
	}
}

CreateStopwatch(id)
{
	fm_DebugPrintLevel(1, "CreateStopwatch(%d)", id)

	if (g_iPlayerClockEnt[id]) // Shouldn't occur but just in case
	{
		RemoveClock(id)
	}

	new iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target")) 
	if (!iEnt)
	{
		fm_WarningLog(FM_ENT_WARNING)
		return 0
	}

	engfunc(EngFunc_SetModel, iEnt, g_sClockModel)
	set_pev(iEnt, pev_movetype, MOVETYPE_FOLLOW)
	set_pev(iEnt, pev_aiment, id)
	set_pev(iEnt, pev_owner, id)
	set_pev(iEnt, pev_framerate, 0.1)
	set_pev(iEnt, pev_nextthink, get_gametime() + CLOCK_UPDATE_FREQUENCY)

	g_iPlayerClockEnt[id] = iEnt

	return iEnt
}

public Forward_Think(iEnt)
{
	for (new i = 1; i <= g_iMaxPlayers; i++)
	{
		if (iEnt == g_iPlayerClockEnt[i])
		{
			new id = pev(iEnt, pev_owner)
			new iTime = fm_GetUserSpeedRunTime(id)

			new iSecs = iTime / 100
			new iMins = iSecs / 60 
			iSecs %= 60

			set_pev(iEnt, pev_controller_0,  floatround(iSecs * 4.25, floatround_floor))
			set_pev(iEnt, pev_controller_1, floatround(iMins * 4.25, floatround_floor))

			set_pev(iEnt, pev_nextthink, get_gametime() + CLOCK_UPDATE_FREQUENCY)
			return FMRES_HANDLED
		}
	}

	return FMRES_IGNORED
}


public fm_InitSpeedRunning()
{
	g_iMaxPlayers = get_maxplayers()
	register_forward(FM_Think, "Forward_Think")
	
}

public fm_PlayerStoppedSpeedRunning(id, iTime)
{
	RemoveClock(id)
}

public client_disconnected(id)
{
	RemoveClock(id)
}

public fm_PlayerStartedSpeedRunning(id)
{
	CreateStopwatch(id)
}