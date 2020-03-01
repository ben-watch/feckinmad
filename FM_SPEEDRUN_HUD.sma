#include "feckinmad/fm_global"
#include "feckinmad/fm_speedrun_api"
#include "feckinmad/fm_speedrun_top"

#include <fakemeta>

#define HUD_UPDATE_FREQUENCY 0.15

new g_iEnt, g_iMaxPlayers, g_iStatusMsgId
new bool:g_bPlayerSpeedRunning[MAX_PLAYERS + 1] // Local cache of speedrunning status


public plugin_init()
{
	fm_RegisterPlugin()
}

public fm_InitSpeedRunning()
{
	g_iMaxPlayers = get_maxplayers()
	g_iStatusMsgId = get_user_msgid("StatusText")

	g_iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target")) 
	if (!g_iEnt)
	{
		fm_WarningLog(FM_ENT_WARNING)
	}
	else
	{
		register_forward(FM_Think, "Forward_Think")
		set_pev(g_iEnt, pev_nextthink, get_gametime() + HUD_UPDATE_FREQUENCY)	
	}
}

public fm_PlayerStoppedSpeedRunning(id, iTime)
{
	fm_DebugPrintLevel(1, "fm_PlayerStoppedSpeedRunning(%d, %d)", id, iTime)

	g_bPlayerSpeedRunning[id] = false
	
	// Clear the HUD of speedrun info
	if (is_user_connected(id))
	{
		message_begin(MSG_ONE, g_iStatusMsgId, {0,0,0}, id) 
		write_byte(0)
		write_string("") 
		message_end()
	}
}

public fm_PlayerStartedSpeedRunning(id)
{
	fm_DebugPrintLevel(1, "fm_PlayerStartedSpeedRunning(%d)", id)

	g_bPlayerSpeedRunning[id] = true
}


public Forward_Think(iEnt)
{
	if (iEnt != g_iEnt)
	{
		return FMRES_IGNORED
	}

	for (new i = 1; i <= g_iMaxPlayers; i++)
	{

		if (!g_bPlayerSpeedRunning[i])
		{
			continue
		}

		new iCurrentTime = fm_GetUserSpeedRunTime(i)
		
		static sMessage[64]

		new iHuns = iCurrentTime % 100
		new iSecs = iCurrentTime / 100
		new iMins = iSecs / 60 
		iSecs %= 60

		new iLen = formatex(sMessage, charsmax(sMessage), "Timer: (%02d:%02d:%02d)", iMins, iSecs, iHuns)
		
		// Get the current ranking if the player were to finish right now
		new iCurrentRank = fm_GetSpeedRunRankByTime(iCurrentTime)
		new iRankTotal = fm_GetSpeedRunTotal()

		iLen += formatex(sMessage[iLen], charsmax(sMessage) - iLen, " Rank: (%d/%d)", !iCurrentRank ? iRankTotal + 1 : iCurrentRank, !iCurrentRank ? iRankTotal + 1 : iRankTotal)

		// Get the time difference until the next rank
		
		if (iCurrentRank > 0)
		{
			new iRankTime = fm_GetSpeedRunTimeByRank(iCurrentRank) - iCurrentTime
			if (iRankTime >= 0)		
			{
				new iRankHuns = iRankTime % 100
				new iRankSecs = iRankTime / 100
				new iRankMins = iRankSecs / 60
				iRankSecs %= 60

				iLen += formatex(sMessage[iLen], charsmax(sMessage) - iLen, " (%02d:%02d:%02d)", iRankMins, iRankSecs, iRankHuns)
			}
		}
		message_begin(MSG_ONE, g_iStatusMsgId, {0,0,0}, i) 
		write_byte(0)
		write_string(sMessage) 
		message_end()
	}

	set_pev(iEnt, pev_nextthink, get_gametime() + HUD_UPDATE_FREQUENCY)

	return FMRES_IGNORED
}