#include "feckinmad/fm_global"
#include "feckinmad/fm_time.inc"
#include "feckinmad/fm_config"

#include <fakemeta>

new g_iPlayerAway[MAX_PLAYERS + 1]
new Float:g_fPlayerLastDetected[MAX_PLAYERS + 1]

new g_pCvarIdleMax, g_iMaxIdle
new g_iEnt, g_iMaxPlayers, g_iBackForward, g_iAwayForward, g_iReturn

#define GetSecondsIdle(%1) floatround(get_gametime() - g_fPlayerLastDetected[%1])

public plugin_init()
{
	fm_RegisterPlugin()
	g_pCvarIdleMax = register_cvar("fm_idle_awaytime", "300")
	g_iMaxPlayers = get_maxplayers()
}

public fm_InitConfigExec()
{
	g_iMaxIdle = get_pcvar_num(g_pCvarIdleMax)
	if (g_iMaxIdle <= 0)
	{
		return PLUGIN_CONTINUE
	}

	register_forward(FM_PlayerPreThink, "Forward_PreThink")

	g_iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	if (!g_iEnt)
	{
		fm_WarningLog(FM_ENT_WARNING)
		return PLUGIN_CONTINUE
	}

	set_pev(g_iEnt, pev_nextthink, get_gametime() + 1.0)
	register_forward(FM_Think, "Forward_Think")

	g_iAwayForward = CreateMultiForward("fm_IdlePlayerAway", ET_IGNORE, FP_CELL)
	g_iBackForward = CreateMultiForward("fm_IdlePlayerBack", ET_IGNORE, FP_CELL)

	return PLUGIN_CONTINUE
}

public plugin_end()
{
	if (g_iAwayForward)
	{
		DestroyForward(g_iAwayForward)
	}

	if (g_iBackForward)
	{
		DestroyForward(g_iBackForward)
	}
}

public Forward_PreThink(id)
{
	if (pev(id, pev_button) != pev (id, pev_oldbuttons))
	{
		PlayerActivity(id)
	}
}

PlayerActivity(id)
{
	if (g_iPlayerAway[id])
	{
		new sTime[64]; fm_SecondsToText(floatround(get_gametime() - g_fPlayerLastDetected[id]), sTime, charsmax(sTime))
		new sName[MAX_NAME_LEN]; get_user_name(id, sName, charsmax(sName))
		client_print(0, print_chat, "* %s is no longer marked as away after %s of inactivity", sName, sTime)	

		g_iPlayerAway[id] = 0
		ExecuteForward(g_iBackForward, g_iReturn, id)
	}
	g_fPlayerLastDetected[id] = get_gametime()
}

public Forward_Think(iEnt)
{
	if (iEnt != g_iEnt)
	{
		return FMRES_IGNORED
	}

	static iSecs, sTime[64], sName[32]
	for (new i = 1; i <= g_iMaxPlayers; i++)
	{						
		if (!is_user_connected(i) || g_iPlayerAway[i] || is_user_bot(i) || is_user_hltv(i))
		{
			continue
		}

		iSecs = GetSecondsIdle(i)
		if (iSecs >= g_iMaxIdle)
		{
			fm_SecondsToText(iSecs, sTime, charsmax(sTime), 1)
			get_user_name(i, sName, charsmax(sName))
			client_print(0, print_chat, "* %s is now marked as away after %s of inactivity", sName, sTime)

			g_iPlayerAway[i] = 1
			ExecuteForward(g_iAwayForward, g_iReturn, i)
		}
	}
	set_pev(g_iEnt, pev_nextthink, get_gametime() + 1.0)
	return FMRES_IGNORED
}

public client_putinserver(id)
{
	g_fPlayerLastDetected[id] = get_gametime()
}

public client_disconnected(id)
{
	g_fPlayerLastDetected[id] = 0.0
	g_iPlayerAway[id] = 0
}

public plugin_natives()
{
	register_native("fm_GetUserIdle", "Native_GetUserIdle")
	register_native("fm_GetUserAway", "Native_GetUserAway")
 
	register_library("fm_idle_api")
}

public Native_GetUserIdle() 
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

	// Check this just incase the plugin calling this native is loaded before this plugin
	// and is calling this native on putinserver
	if (g_fPlayerLastDetected[id] == 0.0)
	{
		return 0
	}

	return GetSecondsIdle(id)
}

public Native_GetUserAway() 
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

	return g_iPlayerAway[id]
}
