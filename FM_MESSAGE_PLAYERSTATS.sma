#include "feckinmad/fm_global"
#include "feckinmad/fm_sql_tquery"

#define SECONDS_IN_DAY 86400
#define RECORDS_BEGAN 2008

new const g_sStatsQuery[] = "SELECT COUNT(player_id) FROM players WHERE player_lastconnect > UNIX_TIMESTAMP() - %d;"
new const g_sAllStatsQuery[] = "SELECT COUNT(player_id) FROM players"
new g_iCurrentMessage

enum
{
	QUERY_DAY = 0,
	QUERY_MONTH,
	QUERY_YEAR,
	QUERY_ALLTIME,
	QUERY_COUNT
}

new g_iQueryLen[QUERY_COUNT] = 
{
	SECONDS_IN_DAY,
	SECONDS_IN_DAY * 30,
	SECONDS_IN_DAY * 365,
	0
}

new g_sStatsText[QUERY_COUNT][] = 
{
	"24 hours",
	"month",
	"year",
	"2008"	
}

new g_iQueryStats[QUERY_COUNT]
new g_iQueryIdent[QUERY_COUNT]

public plugin_init()
{
	fm_RegisterPlugin()

	new g_sQuery[256]

	for (new i = 0; i < QUERY_COUNT - 1; i++)
	{
		formatex(g_sQuery, charsmax(g_sQuery), g_sStatsQuery, g_iQueryLen[i])
		g_iQueryIdent[i] = fm_SQLAddThreadedQuery(g_sQuery, "Handle_PlayerStatsQuery", QUERY_DISPOSABLE, PRIORITY_LOW)	

	}	

	formatex(g_sQuery, charsmax(g_sQuery), g_sAllStatsQuery)
	g_iQueryIdent[QUERY_ALLTIME] = fm_SQLAddThreadedQuery(g_sQuery, "Handle_PlayerStatsQuery", QUERY_DISPOSABLE, PRIORITY_LOW)		
}

public Handle_PlayerStatsQuery(iFailState, Handle:hQuery, sError[], iError, Data[], iDataLen, Float:fQueueTime, iQueryIdent)
{
	fm_DebugPrintLevel(1, "Handle_Handle_PlayerStatsQuery: %f", fQueueTime)

	if(fm_SQLCheckThreadedError(iFailState, hQuery, sError, iError))
	{
		return PLUGIN_HANDLED
	}	

	for (new i = 0; i < QUERY_COUNT ; i++)
	{
		if (g_iQueryIdent[i] == iQueryIdent)
		{
			g_iQueryStats[i] = SQL_ReadResult(hQuery, 0)
			break
		}
	}
	return PLUGIN_HANDLED
}

public fm_ScreenMessage(sBuffer[], iSize)
{
	if (g_iCurrentMessage >= QUERY_COUNT)
	{
		g_iCurrentMessage = 0
	}
	
	if (!g_iQueryStats[g_iCurrentMessage])
	{
		formatex(sBuffer, iSize, "All your player stats belong to us")	
	}

	formatex(sBuffer, iSize, "%d unique players have connected to the server %s %s", g_iQueryStats[g_iCurrentMessage], g_iCurrentMessage != QUERY_ALLTIME ? "in the last" : "since", g_sStatsText[g_iCurrentMessage])
	g_iCurrentMessage++

}