#include "feckinmad/fm_global"
#include "feckinmad/fm_sql_tquery"
#include "feckinmad/fm_speedrun_api"
#include "feckinmad/fm_speedrun_top"
#include "feckinmad/fm_sql_player" // fm_SQLGetUserIdent(id)
#include "feckinmad/fm_sql_map" // fm_SQLGetMapIdent()

new g_sQuery[512]

public plugin_init()
{
	fm_RegisterPlugin()
}

stock FormatTime(iTime, sTime[], iLen)
{
	new iHuns = iTime % 100
	new iSecs = iTime / 100
	new iMins = iSecs / 60
	iSecs %= 60

	formatex(sTime, iLen, "%02d:%02d:%02d", iMins, iSecs, iHuns)
}

public fm_PlayerStoppedSpeedRunning(id, iTime)
{
	// Ignore aborted runs	
	if (iTime < 0)
	{
		return PLUGIN_CONTINUE
	}

	new iPlayerIdent = fm_SQLGetUserIdent(id)
	if (iPlayerIdent <= 0)
	{
		//log_error_here
		return PLUGIN_CONTINUE
	}	

	// Get Map ID
	new iMapIdent = fm_SQLGetMapIdent()
	if (iMapIdent <= 0)
	{
		//log_error_here
		return PLUGIN_CONTINUE
	}	

	new sName[MAX_NAME_LEN]; get_user_name(id, sName, charsmax(sName))
	new CurrentRank[eSpeedTop_t], iRank = fm_GetSpeedRunRankByIdent(iPlayerIdent, CurrentRank)

	// Check if they are ranked
	if (!iRank)
	{
		// Insert the run into the SQL db
		formatex(g_sQuery, charsmax(g_sQuery), "INSERT INTO speedruns (map_id, player_id, speedrun_time, speedrun_timestamp) VALUES (%d, %d, %d, UNIX_TIMESTAMP())", iMapIdent, iPlayerIdent, iTime)
		fm_SQLAddThreadedQuery(g_sQuery, "Handle_InsertSpeedrun", QUERY_NOT_DISPOSABLE, PRIORITY_HIGH)
	}
	else // They are already ranked
	{	
		new sTimeDiff[32]
		new sPreviousTime[32]; FormatTime(CurrentRank[m_iTopTime], sPreviousTime, charsmax(sPreviousTime))

		// Did they beat their previous speedrun?
		if (iTime < CurrentRank[m_iTopTime])
		{
			fm_SpeedRunTimeToText(CurrentRank[m_iTopTime] - iTime, sTimeDiff, charsmax(sTimeDiff), 1)
			client_print(0, print_chat, "* \"%s\" beat their previous speedrun of %s by %s", sName, sPreviousTime, sTimeDiff)

			// Update the SQL db
			formatex(g_sQuery, charsmax(g_sQuery), "UPDATE speedruns SET speedrun_time = '%d', speedrun_timestamp = UNIX_TIMESTAMP() WHERE player_id = '%d' AND map_id = '%d';", iTime, iPlayerIdent, iMapIdent)
			fm_SQLAddThreadedQuery(g_sQuery, "Handle_UpdateSpeedrun", QUERY_NOT_DISPOSABLE, PRIORITY_HIGH)
		}
		else // They didn't beat it. Oh well, print their failure!
		{
			fm_SpeedRunTimeToText(iTime - CurrentRank[m_iTopTime], sTimeDiff, charsmax(sTimeDiff), 1)
			client_print(0, print_chat, "* \"%s\" failed to beat their previous speedrun of %s by %s", sName, sPreviousTime, sTimeDiff)
		}
	}
	return PLUGIN_CONTINUE
}

public Handle_InsertSpeedrun(iFailState, Handle:hQuery, sError[], iError, sData[], iLen, Float:fQueueTime)
{
	fm_DebugPrintLevel(1, "Handle_InsertSpeedrun: %f", fQueueTime)

	if(fm_SQLCheckThreadedError(iFailState, hQuery, sError, iError))
	{
		return PLUGIN_HANDLED
	}
	
	new iIdent = SQL_GetInsertId(hQuery)
	if (iIdent <= 0)
	{
		//log_error_here
	}

	fm_ReloadSpeedRunData() // Tell FM_SPEEDRUN_TOP.amxx to reload the ranks

	return PLUGIN_HANDLED
}

public Handle_UpdateSpeedrun(iFailState, Handle:hQuery, sError[], iError, sData[], iLen, Float:fQueueTime)
{
	fm_DebugPrintLevel(1, "Handle_UpdateSpeedrun: %f", fQueueTime)

	if(fm_SQLCheckThreadedError(iFailState, hQuery, sError, iError))
	{
		return PLUGIN_HANDLED
	}

	new iAffected = SQL_AffectedRows(hQuery)
	if (iAffected != 1)
	{
		//log_error_here
	}

	fm_ReloadSpeedRunData() // Tell FM_SPEEDRUN_TOP.amxx to reload the ranks

	return PLUGIN_HANDLED
}