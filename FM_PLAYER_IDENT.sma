#include "feckinmad/fm_global"
#include "feckinmad/fm_sql_tquery"

#include <nvault>

new g_iPlayerIdent[MAX_PLAYERS + 1] // A players player_id in the database
new g_iMaxPlayers

new const g_sPlayerIdentForward[] = "fm_SQLPlayerIdent"
new g_iForward, g_iReturn

new const g_sPlayerQuery[] = "SELECT player_id FROM players WHERE player_authid = '%s' LIMIT 1;"
new g_iPlayerQuery[MAX_PLAYERS + 1]
new g_sQuery[256]

enum ePlayerQuery_t
{
	m_iPlayerQueryIndex,
	m_sPlayerQueryAuthid[MAX_AUTHID_LEN]
}

new const g_sVaultName[] = "fm_player_ident_cache"
new g_iCacheVault = INVALID_HANDLE

public plugin_init()
{	
	fm_RegisterPlugin()

	g_iMaxPlayers = get_maxplayers()

	g_iForward = CreateMultiForward(g_sPlayerIdentForward, ET_IGNORE, FP_CELL, FP_CELL)
	if (g_iForward <= 0)
	{
		fm_WarningLog(FM_FORWARD_WARNING, g_sPlayerIdentForward)
		return PLUGIN_CONTINUE
	}

	g_iCacheVault = nvault_open(g_sVaultName)
	if (g_iCacheVault == INVALID_HANDLE)
	{
		fm_WarningLog("Failed to open vault \"%s\"", g_sVaultName)
		return PLUGIN_CONTINUE
	}

	nvault_prune(g_iCacheVault, 0,  get_systime() - 2592000) // 30 days
	
	return PLUGIN_CONTINUE
}

public client_putinserver(id)
{
	if (is_user_bot(id) || is_user_hltv(id))
	{
		return PLUGIN_CONTINUE	
	}

	new sAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAuthid, charsmax(sAuthid))
	if (equal(sAuthid, "STEAM_ID_PENDING"))
	{
		fm_WarningLog("STEAM_ID_PENDING in client_putinserver")
		return PLUGIN_CONTINUE
	}

	if (g_iCacheVault != INVALID_HANDLE && (g_iPlayerIdent[id] = nvault_get(g_iCacheVault, sAuthid)))
	{
		fm_DebugPrintLevel(2, "Loaded player ident for <%s> from cache: #%d", sAuthid, g_iPlayerIdent[id])

		nvault_touch(g_iCacheVault, sAuthid) // Touch the entry to update its timestamp
		ExecutePlayerIdentForward(id)
		
		return PLUGIN_CONTINUE
	}

	fm_DebugPrintLevel(2, "Quering player ident for <%s> from database", sAuthid)

	new Data[ePlayerQuery_t]; Data[m_iPlayerQueryIndex] = id
	copy(Data[m_sPlayerQueryAuthid], MAX_AUTHID_LEN - 1, sAuthid)

	formatex(g_sQuery, charsmax(g_sQuery), g_sPlayerQuery, sAuthid)
	g_iPlayerQuery[id] = fm_SQLAddThreadedQuery(g_sQuery, "Handle_GetPlayerId", QUERY_DISPOSABLE, PRIORITY_NORMAL, Data, ePlayerQuery_t)

	return PLUGIN_CONTINUE
}

public Handle_GetPlayerId(iFailState, Handle:hQuery, sError[], iError, Data[], iLen, Float:fQueueTime, iQueryIdent)
{
	fm_DebugPrintLevel(1, "Handle_GetPlayerId: %f", fQueueTime)

	new id = Data[m_iPlayerQueryIndex]

	if(fm_SQLCheckThreadedError(iFailState, hQuery, sError, iError))
	{
		fm_WarningLog("Failed to load player ident for <%s> from database", Data[m_sPlayerQueryAuthid])
		return PLUGIN_HANDLED
	}
	
	// Check that the EXACT player who originally called the query is still connected
	if (g_iPlayerQuery[id] != iQueryIdent)
	{
		fm_DebugPrintLevel(2, "Aborted loading player ident for <%s> from database as they are no longer connected", Data[m_sPlayerQueryAuthid])
		return PLUGIN_HANDLED
	}

	if (SQL_NumResults(hQuery) > 0)	
	{	
		g_iPlayerQuery[id] = 0
		
		g_iPlayerIdent[id] = SQL_ReadResult(hQuery, 0)
		fm_DebugPrintLevel(2, "Loaded player ident for <%s> from database: #%d", Data[m_sPlayerQueryAuthid], g_iPlayerIdent[id])
	
		if (!g_iPlayerIdent[id])
		{
			fm_WarningLog("Player ident for <%s> from database is 0!", Data[m_sPlayerQueryAuthid])
			return 0
		}

		CachePlayerIdent(id, Data[m_sPlayerQueryAuthid])
		ExecutePlayerIdentForward(id)
	}
	else
	{	
		formatex(g_sQuery, charsmax(g_sQuery), "INSERT INTO players (player_authid) VALUES ('%s');", Data[m_sPlayerQueryAuthid])
		g_iPlayerQuery[id] = fm_SQLAddThreadedQuery(g_sQuery, "Handle_InsertPlayerId", QUERY_DISPOSABLE, PRIORITY_NORMAL, Data, iLen)
	}

	return PLUGIN_HANDLED
}

public Handle_InsertPlayerId(iFailState, Handle:hQuery, sError[], iError, Data[], iLen, Float:fQueueTime, iQueryIdent)
{
	fm_DebugPrintLevel(1, "Handle_InsertPlayerId: %f", fQueueTime)

	new id = Data[m_iPlayerQueryIndex]
		
	if(fm_SQLCheckThreadedError(iFailState, hQuery, sError, iError) || !(g_iPlayerIdent[id] = SQL_GetInsertId(hQuery)))
	{
		fm_DebugPrintLevel(2, "Failed to insert player ident for <%s> into database", Data[m_sPlayerQueryAuthid])
		return PLUGIN_HANDLED
	}

	fm_DebugPrintLevel(2, "Added player ident for <%s> to database: #%d", Data[m_sPlayerQueryAuthid], g_iPlayerIdent[id])
	CachePlayerIdent(id, Data[m_sPlayerQueryAuthid])

	// Check that the EXACT player who originally called the query is still connected
	if (g_iPlayerQuery[id] == iQueryIdent)
	{
		fm_DebugPrintLevel(2, "Aborted executing player ident forward for <%s> as they are no longer connected", Data[m_sPlayerQueryAuthid])
		ExecutePlayerIdentForward(id)
	}

	g_iPlayerQuery[id] = 0

	return PLUGIN_HANDLED
}

ExecutePlayerIdentForward(id)
{
	ExecuteForward(g_iForward, g_iReturn, id, g_iPlayerIdent[id])
}

CachePlayerIdent(id, sAuthid[])
{
	fm_DebugPrintLevel(1, "CachePlayerIdent(%d)", id)

	if (g_iCacheVault != INVALID_HANDLE)
	{		
		new sIdent[16]; num_to_str(g_iPlayerIdent[id], sIdent, charsmax(sIdent))	
		nvault_set(g_iCacheVault, sAuthid, sIdent)
		fm_DebugPrintLevel(2, "Cached player ident for <%s> in vault: #%d", sAuthid, g_iPlayerIdent[id])
	}
}

public client_disconnected(id)
{
	if (g_iPlayerQuery[id])
	{
		fm_SQLRemoveThreadedQuery(g_iPlayerQuery[id])
		g_iPlayerQuery[id] = 0
	}

	g_iPlayerIdent[id] = 0
}


public plugin_natives()
{	
	register_native("fm_SQLGetUserIdent", "Native_SQLGetUserIdent")
	register_library("fm_sql_player")	
}

public Native_SQLGetUserIdent()
{
	new id = get_param(1)	

	if (id < 1 || id > g_iMaxPlayers)
	{
		log_error(AMX_ERR_NATIVE, "Player out of range (%d)", id)
		return 0
	}

	if (!is_user_connected(id))
	{
		log_error(AMX_ERR_NATIVE, "Invalid player %d", id)
		return 0
	}
	
	return g_iPlayerIdent[id]
}

public plugin_end() 
{
	if (g_iForward > 0)
	{
		DestroyForward(g_iForward)
	}

	if (g_iCacheVault != INVALID_HANDLE)
	{
		nvault_close(g_iCacheVault)
	}
}