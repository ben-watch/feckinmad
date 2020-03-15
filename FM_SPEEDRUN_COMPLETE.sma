#include "feckinmad/fm_global"
#include "feckinmad/fm_sql_tquery"
#include "feckinmad/fm_speedrun_api"
#include "feckinmad/fm_sql_player"

enum eQueryData_t
{
	m_iPlayerIndex,
	m_iPlayerIdent
}

new g_iPlayerFinished[MAX_PLAYERS + 1] = { -1, ... } // Whether the player has touched the endflag during the map

public fm_SQLPlayerIdent(id, iPlayerIdent)
{
	GetPlayerCompletionCount(id)
}

GetPlayerCompletionCount(id)
{	
	new Data[eQueryData_t]
	Data[m_iPlayerIndex] = id
	Data[m_iPlayerIdent] = fm_SQLGetUserIdent(id)

	formatex(g_sQuery, charsmax(g_sQuery), "SELECT complete_num FROM completed, players, maps WHERE players.player_id = completed.player_id AND completed.map_id = maps.map_id AND maps.map_id = %d AND players.player_id = %d LIMIT 1;", g_iMapId, sData[m_iPlayerIdent])	
	fm_SQLAddThreadedQuery(g_sQuery, "Handle_SelectCompleteCount", QUERY_DISPOSABLE, PRIORITY_LOW, Data, eQueryData_t)
	return 1
}

public Handle_SelectCompleteCount(iFailState, Handle:hQuery, sError[], iError, Data[], iLen, Float:fQueueTime, iQueryIdent)
{
	fm_DebugPrintLevel(1, "Handle_SelectCompleteCount: %f", fQueueTime)

	if(!fm_SQLCheckThreadedError(iFailState, hQuery, sError, iError) && SQL_NumResults(hQuery))
	{
		new id = sData[m_iID]
		if (sData[m_iPlayerIdent] == g_iPlayerCachedDatabaseIdent[id]) // Check the player hasn't disconnected and another player joined in his slot
			g_iPlayerCompletionCount[id] = SQL_ReadResult(hQuery, 0)
	}
}

UpdateCompleteCount(id)
{
	new Data[eQueryData_t]
	Data[m_iPlayerIndex] = id
	Data[m_iPlayerIdent] = fm_SQLGetUserIdent(id)

	if (Data[m_iPlayerIdent] !

	formatex(g_sQuery, charsmax(g_sQuery), "INSERT INTO completed (player_id, map_id, complete_num) VALUES(%d, %d, 1) ON duplicate KEY UPDATE complete_num = complete_num + 1;", sData[m_iPlayerIdent], g_iMapId)

	if (g_SqlTuple == Empty_Handle  || g_iPlayerCachedDatabaseIdent[id] <= 0)
	{
		fm_WarningLog("Unable to update map completion count: MapId: %d iPlayerIdent: %d", g_iMapId, g_iPlayerCachedDatabaseIdent[id])
		return 0
	}

	SQL_ThreadQuery(g_SqlTuple, "Handle_IncreaseCompleteCount", g_sQuery, sData, sizeof(sData))
	fm_PluginLog(g_sQuery)
	return 1	
}

public Handle_IncreaseCompleteCount(iFailState, Handle:hQuery, sError[], iError, sData[], iLen, Float:fQueueTime)
{
	fm_DebugPrintLevel(1, "Handle_IncreaseCompleteCount: %f", fQueueTime)
	fm_SQLCheckThreadedError(iFailState, hQuery, sError, iError)	
}


public Handle_Say(id)
{
	new sArgs[192]; read_args(sArgs, charsmax(sArgs))
	remove_quotes(sArgs)
	
	if (!sArgs[0])
		return PLUGIN_HANDLED
		
	
	if (equali(sArgs, "/complete"))
	{
		if (!CheckSpeedStatus(id))
			return PLUGIN_HANDLED
	
		new sName[MAX_NAME_LEN]; get_user_name(id, sName, charsmax(sName))

		if (g_iPlayerCompletionCount[id] != -1)
			client_print(0, print_chat, "* \"%s\" has completed the currentmap %d times", sName, g_iPlayerCompletionCount[id])
		else
			client_print(0, print_chat, "* Please wait, completion count for \"%s\" has not been loaded from database yet", sName)	
	}

	return PLUGIN_CONTINUE
}

fm_FinishedMap(id)
{


}


