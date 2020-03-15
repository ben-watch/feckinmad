#include "feckinmad/fm_global"
#include "feckinmad/fm_sql_api"
#include "feckinmad/fm_sql_tquery"

#include <nvault>

new const g_sPlayerQuery[] = "SELECT player_id FROM players WHERE player_authid = '%s' LIMIT 1;"
new const g_sVaultName[] = "fm_player_ident_cache"

new g_iPlayerIdent[MAX_PLAYERS + 1] // A players player_id in the database
new g_iPlayerQuery[MAX_PLAYERS + 1] // Current query ident 

new g_iCacheVault = INVALID_HANDLE
new g_iMaxPlayers, g_iForward, g_iReturn
new g_sQuery[256]

public plugin_init()
{
	fm_RegisterPlugin()

	g_iMaxPlayers = get_maxplayers()

	g_iForward = CreateMultiForward("fm_SQLPlayerIdent", ET_IGNORE, FP_CELL, FP_CELL)
	if (g_iForward <= 0)
	{
		set_fail_state("g_iForward <= 0")
	}

	g_iCacheVault = nvault_open(g_sVaultName)
	
	if (g_iCacheVault != INVALID_HANDLE)
	{
		nvault_prune(g_iCacheVault, 0,  get_systime() - 2592000) // 30 days
	}
	else
	{
		fm_WarningLog("Failed to open vault \"%s\"", g_sVaultName)
	}
}

public client_putinserver(id)
{
	fm_DebugPrintLevel(1, "client_putinserver(%d)", id)

	if (is_user_bot(id) || is_user_hltv(id))
	{
		return PLUGIN_CONTINUE	
	}
	
	new iPlayerIdent, sAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAuthid, charsmax(sAuthid))
	if (g_iCacheVault != INVALID_HANDLE && (iPlayerIdent = nvault_get(g_iCacheVault, sAuthid)))
	{
		fm_DebugPrintLevel(2, "Loaded player ident for #%d <%s> from cache: %d", id, sAuthid, iPlayerIdent)

		nvault_touch(g_iCacheVault, sAuthid) // Touch the entry to update its timestamp
		g_iPlayerIdent[id] = iPlayerIdent
		ExecuteForward(g_iForward, g_iReturn, id, iPlayerIdent)
	}
	else
	{
		fm_DebugPrintLevel(2, "Quering player ident for #%d <%s> from db", id, sAuthid)

		new sData[1]; sData[0] = id
		formatex(g_sQuery, charsmax(g_sQuery), g_sPlayerQuery, sAuthid)
		g_iPlayerQuery[id] = fm_SQLAddThreadedQuery(g_sQuery, "Handle_GetPlayerId", QUERY_DISPOSABLE, PRIORITY_NORMAL, sData, 1)
	}

	return PLUGIN_CONTINUE
}


public Handle_GetPlayerId(iFailState, Handle:hQuery, sError[], iError, sData[], iLen, Float:fQueueTime, iQueryIdent)
{
	fm_DebugPrintLevel(1, "Handle_GetPlayerId: %f", fQueueTime)

	new id = sData[0]
	
	if(fm_SQLCheckThreadedError(iFailState, hQuery, sError, iError))
	{
		fm_DebugPrintLevel(2, "Failed to load player ident for #%d from db", id)
		return PLUGIN_HANDLED
	}
	
	// Check that the player is still connected and is who we think it is
	if (g_iPlayerQuery[id] != iQueryIdent)
	{
		fm_DebugPrintLevel(2, "g_iPlayerQuery[id] != iQueryIdent")
		g_iPlayerQuery[id] = 0
		return PLUGIN_HANDLED
	}
	
	if (SQL_NumResults(hQuery) > 0)	
	{
		new iPlayerIdent = SQL_ReadResult(hQuery, 0)
		
		new sAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAuthid, charsmax(sAuthid))
		fm_DebugPrintLevel(2, "Loaded player ident for authid \"%s\" from db: %d", sAuthid, iPlayerIdent)
	
		g_iPlayerIdent[id] = iPlayerIdent
		CachePlayerIdent(id, iPlayerIdent)
		ExecuteForward(g_iForward, g_iReturn, id, iPlayerIdent)

		g_iPlayerQuery[id] = 0	
	}
	else
	{
		new sAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAuthid, charsmax(sAuthid))
		new sAddress[32]; get_user_ip(id, sAddress, charsmax(sAddress), 1) // Without port

		formatex(g_sQuery, charsmax(g_sQuery), "INSERT INTO players (player_authid, player_address2) VALUES ('%s',INET_ATON('%s'));", sAuthid, sAddress)
		g_iPlayerQuery[id] = fm_SQLAddThreadedQuery(g_sQuery, "Handle_InsertPlayerId", QUERY_DISPOSABLE, PRIORITY_NORMAL, sData, 1)

	}
	return PLUGIN_HANDLED
}


public Handle_InsertPlayerId(iFailState, Handle:hQuery, sError[], iError, sData[], iLen, Float:fQueueTime, iQueryIdent)
{
	fm_DebugPrintLevel(1, "Handle_InsertPlayerId: %f", fQueueTime)

	new id = sData[0]	
	new iPlayerIdent
	
	if(fm_SQLCheckThreadedError(iFailState, hQuery, sError, iError) || !(iPlayerIdent = SQL_GetInsertId(hQuery)))
	{
		fm_WarningLog("Failed to insert player ident for #%d into db", id)
		return PLUGIN_HANDLED
	}

	fm_DebugPrintLevel(2, "Added player ident for #%d to db: %d", id, iPlayerIdent)
	
	// Ensure the player the query was performed for has not disconnected
	if (g_iPlayerQuery[id] == iQueryIdent)
	{
		g_iPlayerIdent[id] = iPlayerIdent
		CachePlayerIdent(id, iPlayerIdent)
		ExecuteForward(g_iForward, g_iReturn, id, iPlayerIdent)
	}
	else
		fm_DebugPrintLevel(2, "g_iPlayerQuery[id] != iQueryIdent")

	g_iPlayerQuery[id] = 0

	return PLUGIN_HANDLED
}

CachePlayerIdent(id, iPlayerIdent)
{
	fm_DebugPrintLevel(1, "CachePlayerIdent(%d, %d)", id, iPlayerIdent)

	if (g_iCacheVault != INVALID_HANDLE)
	{	
		new sAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAuthid, charsmax(sAuthid))		
		new sIdent[16]; num_to_str(iPlayerIdent, sIdent, charsmax(sIdent))
		
		nvault_set(g_iCacheVault, sAuthid, sIdent)
		fm_DebugPrintLevel(2, "Cached player ident for authid \"%s\" in vault: %d", sAuthid, iPlayerIdent)
	}
}

public client_disconnected(id)
{
	if (g_iPlayerQuery[id])
	{
		fm_SQLRemoveThreadedQuery(g_iPlayerQuery[id])
	}

	g_iPlayerIdent[id] = 0
}

public plugin_end() 
{
	if (g_iForward)
	{
		DestroyForward(g_iForward)
	}

	if (g_iCacheVault != INVALID_HANDLE)
	{
		nvault_close(g_iCacheVault)
	}
}

public plugin_natives()
{	
	register_native("fm_SQLGetUserIdent", "Native_GetPlayerId")
	register_library("fm_sql_player")	
}

public Native_GetPlayerId()
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
