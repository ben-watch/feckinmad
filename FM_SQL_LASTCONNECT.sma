#include "feckinmad/fm_global"
#include "feckinmad/fm_sql_player"
#include "feckinmad/fm_sql_tquery"

new const g_sConnectQuery[] = "UPDATE players SET player_lastconnect = UNIX_TIMESTAMP() WHERE player_id = %d LIMIT 1;"

public plugin_init()
{
	fm_RegisterPlugin()
}

public fm_SQLPlayerIdent(id, iPlayerIdent)
{
	new sQuery[128]; formatex(sQuery, charsmax(sQuery), g_sConnectQuery, iPlayerIdent)
	fm_SQLAddThreadedQuery(sQuery, "Handle_UpdatePlayerLastConnect", QUERY_DISPOSABLE, PRIORITY_LOW)	
}

public Handle_UpdatePlayerLastConnect(iFailState, Handle:hQuery, sError[], iError, sData[], iLen, Float:fQueueTime)
{
	fm_SQLCheckThreadedError(iFailState, hQuery, sError, iError)
}