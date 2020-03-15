#include "feckinmad/fm_global"
#include "feckinmad/fm_speedrun_api"
#include "feckinmad/fm_sql_tquery"
#include "feckinmad/fm_sql_player"

#define MAX_MOTD_RANKS 15

new g_sQuery[512]
new g_iMapIdent

enum eSpeedTop_t
{
	m_iTopPlayerIdent,
	m_sTopPlayerAuthid[MAX_AUTHID_LEN],
	m_sTopPlayerName[MAX_NAME_LEN],
	m_iTopTime
}

new Array:g_TopList
new g_iTopCount = -1


public plugin_init() 
{
	fm_RegisterPlugin()

	g_TopList = ArrayCreate(eSpeedTop_t)

	register_clcmd("say", "Handle_Say")
	register_clcmd("say_team", "Handle_Say")
}

public fm_CanEnableSpeedRun()
{
	fm_DebugPrintLevel(1, "fm_CanEnableSpeedRun() | g_iTopCount: %d", g_iTopCount)

	if (g_iTopCount == -1)
	{
		return PLUGIN_HANDLED // Return plugin handled. This plugin is not ready to speedrun yet!
	}
	return PLUGIN_CONTINUE
}

public fm_SQLMapIdent(iMapIdent)
{
	fm_DebugPrintLevel(1, "fm_SQLMapIdent(%d)", iMapIdent)
	g_iMapIdent = iMapIdent
	LoadSpeedRunData()
}

LoadSpeedRunData(iPlayerIdent = 0)
{
	new Data[2]; Data[0] = iPlayerIdent
	formatex(g_sQuery, charsmax(g_sQuery), "SELECT speedruns.player_id, player_common_name, player_authid, speedrun_time FROM speedruns, maps, players WHERE speedruns.map_id = maps.map_id AND speedruns.player_id = players.player_id AND speedruns.map_id = '%d' ORDER BY speedrun_time;", g_iMapIdent)
	fm_SQLAddThreadedQuery(g_sQuery, "Handle_SelectTop", QUERY_DISPOSABLE, PRIORITY_HIGHEST, Data, sizeof(Data))
}

public Handle_SelectTop(iFailState, Handle:hQuery, sError[], iError, Data[], iLen, Float:fQueueTime, iQueryIdent)
{
	fm_DebugPrintLevel(1, "Handle_SelectTop: %f", fQueueTime)

	if(fm_SQLCheckThreadedError(iFailState, hQuery, sError, iError))
	{
		fm_WarningLog("Failed to refresh speedrun rank data")
		return PLUGIN_HANDLED
	}

	ArrayClear(g_TopList)
	g_iTopCount = 0

	new Buffer[eSpeedTop_t]
	while(SQL_MoreResults(hQuery)) 
	{	
		Buffer[m_iTopPlayerIdent] = SQL_ReadResult(hQuery, 0)
		SQL_ReadResult(hQuery, 1, Buffer[m_sTopPlayerName], MAX_NAME_LEN - 1)
		SQL_ReadResult(hQuery, 2, Buffer[m_sTopPlayerAuthid], MAX_AUTHID_LEN - 1)
		Buffer[m_iTopTime] = SQL_ReadResult(hQuery, 3)

		ArrayPushArray(g_TopList, Buffer)
		g_iTopCount++
			
		SQL_NextRow(hQuery)
	}

	log_amx("Loaded %d speedruns from database", g_iTopCount)

	// Announce rank of a certain player ident
	new iPlayerIdent = Data[0]
	if (iPlayerIdent != 0)
	{
		new Buffer[eSpeedTop_t]
		new iRank = GetSpeedRunRankByPlayerIdent(iPlayerIdent, Buffer)	
		client_print(0, print_chat, "* \"%s\" is now ranked #%d on the currentmap", Buffer[m_sTopPlayerName], iRank)
	}

	// Tell FM_SPEEDRUN_API that we are ready to speedrun. It will forward to the other plugins to check if they are ready.
	if (!fm_GetSpeedRunStatus())
	{
		fm_ReadyToSpeedRun() 
	}

	return PLUGIN_HANDLED
}

public ShowTop(id, iStart)
{ 
	if (!g_iTopCount)
	{
		client_print(id, print_chat, "* No players have completed a speedrun on the currentmap")
		return
	}

	if (iStart < 0)
		iStart = 0	
	else if (iStart > g_iTopCount)
		iStart = g_iTopCount - 1
	
	new iEnd = iStart + MAX_MOTD_RANKS
	if (iEnd > g_iTopCount)
		iEnd = g_iTopCount

	static sBuffer[1024]
	new sCurrentMap[MAX_MAP_LEN]; get_mapname(sCurrentMap, charsmax(sCurrentMap))
	new iLen = formatex(sBuffer, charsmax(sBuffer), "Speedruns ranks %d to %d for map %s\n", iStart + 1, iEnd, sCurrentMap)

	new TopInfo[eSpeedTop_t], sTime[16], iPos = iStart + 1
	for(new i = iStart; i < iEnd; i++) 
	{
		ArrayGetArray(g_TopList, i, TopInfo)
		fm_FormatSpeedRunTime(TopInfo[m_iTopTime], sTime, charsmax(sTime))
		iLen += formatex(sBuffer[iLen], charsmax(sBuffer) - iLen, "\n%3d) (%s) %s <%s> ", iPos++, sTime, TopInfo[m_sTopPlayerName], TopInfo[m_sTopPlayerAuthid])
	}

	if (iEnd != g_iTopCount)
		iLen += formatex(sBuffer[iLen], charsmax(sBuffer) - iLen, "\n\nClose this window and type \"/top %d\" to view the next %d", iPos, MAX_MOTD_RANKS)

	show_motd(id, sBuffer, "Speedrun Ranks")
	
	return
}

public Handle_Say(id)
{
	new sArgs[192]; read_args(sArgs, charsmax(sArgs))
	remove_quotes(sArgs)
	
	if (!sArgs[0])
		return PLUGIN_HANDLED

	if (equali(sArgs, "/rank"))
	{
		if (!fm_GetSpeedRunStatus())
		{
			client_print(id, print_chat, "* Speedrunning is not active on the currentmap")
			return PLUGIN_HANDLED
		}

		new sName[MAX_NAME_LEN]; get_user_name(id, sName, charsmax(sName))

		new iPlayerIdent = fm_SQLGetUserIdent(id)
		if (iPlayerIdent == -1)
		{
			//err
			return PLUGIN_CONTINUE
		}
		
		new Buffer[eSpeedTop_t]
		new iRank = GetSpeedRunRankByPlayerIdent(iPlayerIdent, Buffer)

		if (!iRank)
		{
			client_print(0, print_chat, "* \"%s\" is not ranked in speedruns for the currentmap", sName)
		}
		else
		{
			new sTime[16]; fm_FormatSpeedRunTime(Buffer[m_iTopTime], sTime, charsmax(sTime))
			client_print(0, print_chat, "* \"%s\" is ranked %d/%d in speedruns for the currentmap with a time of %s", sName, iRank, g_iTopCount, sTime)
		}
		return PLUGIN_CONTINUE
	}
	else if (equali(sArgs, "/top", 4)) 
	{
		if (!fm_GetSpeedRunStatus())
		{
			client_print(id, print_chat, "* Speedrunning is not active on the currentmap")
			return PLUGIN_HANDLED
		}
				
		if (sArgs[4] == ' ')
		{
			ShowTop(id, str_to_num(sArgs[5]) - 1)
			return PLUGIN_HANDLED
		}
		else if (!sArgs[4])
		{	
			ShowTop(id, 0)
			return PLUGIN_HANDLED
		}
	}
	return PLUGIN_CONTINUE
}

// Returns the rank of a users speedrun
// Also returns the details of the speedrun as eSpeedTop_t struct
GetSpeedRunRankByPlayerIdent(iPlayerIdent, TopInfo[eSpeedTop_t])
{
	fm_DebugPrintLevel(1, "GetSpeedRunRankByPlayerIdent(%d)", iPlayerIdent)

	new Buffer[eSpeedTop_t]
	for (new i = 0; i < g_iTopCount; i++)
	{
		ArrayGetArray(g_TopList, i, Buffer)
		if (Buffer[m_iTopPlayerIdent] == iPlayerIdent)
		{
			TopInfo[m_iTopPlayerIdent] = Buffer[m_iTopPlayerIdent]
			copy(TopInfo[m_sTopPlayerAuthid], MAX_AUTHID_LEN - 1, Buffer[m_sTopPlayerAuthid])
			copy(TopInfo[m_sTopPlayerName], MAX_NAME_LEN -1,  Buffer[m_sTopPlayerName])
			TopInfo[m_iTopTime] = Buffer[m_iTopTime]

			return i + 1
		}
	}
	return 0
}

GetSpeedRunRankByTime(iTime)
{
	static Buffer[eSpeedTop_t]
	for (new i = 0; i < g_iTopCount; i++)
	{
		ArrayGetArray(g_TopList, i, Buffer)
		if (Buffer[m_iTopTime] > iTime)
		{
			return i + 1
		}
	}
	return 0
}

public plugin_end()
{
	ArrayDestroy(g_TopList)
}

public plugin_natives()
{
	register_native("fm_ReloadSpeedRunData", "Native_ReloadSpeedRunData")
	register_native("fm_GetSpeedRunTimeByRank", "Native_GetSpeedRunTimeByRank")
	register_native("fm_GetSpeedRunRankByIdent", "Native_GetSpeedRunRankByIdent")
	register_native("fm_GetSpeedRunRankByTime", "Native_GetSpeedRunRankByTime")
	register_native("fm_GetSpeedRunTotal", "Native_GetSpeedRunTotal")

	register_library("fm_speedrun_top")
}

public Native_ReloadSpeedRunData(iPlugin, iParams)
{
	new id = get_param(1)
	LoadSpeedRunData(id)
}

public Native_GetSpeedRunTotal(iPlugin, iParams)
{
	return g_iTopCount
}

public Native_GetSpeedRunRankByIdent(iPlugin, iParams)
{
	new iPlayerIdent = get_param(1)	
	new Buffer[eSpeedTop_t]; 
	new iReturn = GetSpeedRunRankByPlayerIdent(iPlayerIdent, Buffer)
	
	if (iReturn > 0)
	{	 
		set_array(2, Buffer, eSpeedTop_t)
	}

	return iReturn
}

public Native_GetSpeedRunTimeByRank(iPlugin, iParams)
{
	new iRank = get_param(1)

	if (iRank < 1 || iRank > g_iTopCount)
	{
		log_error(AMX_ERR_NATIVE, "Rank out of range (%d)", iRank)
		return 0
	}

	static Buffer[eSpeedTop_t]; ArrayGetArray(g_TopList, iRank - 1, Buffer) // -1 as 0 == 1st
	return Buffer[m_iTopTime]
}

public Native_GetSpeedRunRankByTime(iPlugin, iParams)
{
	new iTime = get_param(1)
	return GetSpeedRunRankByTime(iTime)
}