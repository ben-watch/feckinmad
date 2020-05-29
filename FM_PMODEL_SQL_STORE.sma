#include "feckinmad/fm_global"
#include "feckinmad/fm_playermodel_api"
#include "feckinmad/fm_sql_tquery"
#include "feckinmad/fm_sql_player"

#include <nvault>
#include <fakemeta>

#define MAX_PLAYER_VAULT_AGE 86400 * 30 // 30 days. How many days to keep a players model cached locally (Reduces queries to DB and means the player gets their model on mapload) (lots of queries going on on mapload!)

new g_iCacheVault = INVALID_HANDLE
new const g_sPlayerQuery[] = "SELECT players.model_id, players.model_skin FROM players, models WHERE model_active=1 AND players.model_id = models.model_id AND player_id = %d LIMIT 1;"
new const g_sPlayerModelVault[] = "fm_playermodel_cache"
new g_iPlayerQuery[MAX_PLAYERS + 1]
new g_sQuery[512]

public plugin_init() 
{ 
	fm_RegisterPlugin()
	
	g_iCacheVault = nvault_open(g_sPlayerModelVault)
	if (g_iCacheVault != INVALID_HANDLE)
	{
		nvault_prune(g_iCacheVault, 0, get_systime() - (MAX_PLAYER_VAULT_AGE))
	}
}

public plugin_end()
{
	if (g_iCacheVault != INVALID_HANDLE)
	{
		nvault_close(g_iCacheVault)
	}
}

public client_disconnected(id)
{
	if (g_iPlayerQuery[id])
	{
		fm_SQLRemoveThreadedQuery(g_iPlayerQuery[id])
		g_iPlayerQuery[id] = 0
	}
}

public fm_PlayerModelMenuExit(id, sMenuSelection[MENU_TYPE_COUNT])
{
	fm_DebugPrintLevel(1, "fm_PlayerModelMenuExit(%d, { %d, %d, %d, %d }", id, sMenuSelection[0], sMenuSelection[1], sMenuSelection[2], sMenuSelection[3])
	
	// Convert model index passed from the menu keys to the ident of the model in the database
	new iValue = sMenuSelection[MENU_TYPE_MODEL] 
	if (iValue != -1)
	{	
		iValue = fm_GetPlayerModelIdentByIndex(iValue) 
	}

	// Since the pev_body calculations are based off the current pev_body and not just what is selected in the menu, just grab the single value already applied.
	SavePlayerModel(id, iValue, sMenuSelection[MENU_TYPE_SKIN], pev(id, pev_body))
}

public fm_SQLPlayerIdent(id, iPlayerIdent)
{
	fm_DebugPrintLevel(1, "fm_SQLPlayerIdent(%d, %d)", id, iPlayerIdent)

	if (!fm_GetPlayerModelStatus() || !fm_GetPlayerModelCount())
	{
		return PLUGIN_CONTINUE	
	}

	new sData[128], sPlayerIdent[16], iTimeStamp
	num_to_str(iPlayerIdent, sPlayerIdent, charsmax(sPlayerIdent))

	if (g_iCacheVault != INVALID_HANDLE && nvault_lookup(g_iCacheVault, sPlayerIdent, sData, charsmax(sData), iTimeStamp))
	{
		fm_DebugPrintLevel(2, "nvault_lookup for iPlayerIdent: \"%s\" returned sData: \"%s\"", sPlayerIdent, sData)

		new sModel[MAX_MODEL_NAME_LEN], sSkin[16], sBody[16]
		parse(sData, sModel, charsmax(sModel), sSkin, charsmax(sSkin), sBody, charsmax(sBody))
		new iModelIdent = str_to_num(sModel)

		if (iModelIdent != -1)  // If model is custom
		{
			new iModelIndex = fm_GetPlayerModelIndexByIdent(iModelIdent)
			fm_DebugPrintLevel(2, "iModelIdent: %d iModelIndex: %d", iModelIdent, iModelIndex)

			if (iModelIndex != -1)
			{
				new Buffer[eModel_t];fm_GetPlayerModelDataByIndex(iModelIndex, Buffer)		
				new iSkin = str_to_num(sSkin)
				new iBody = str_to_num(sBody)

				if (iSkin < 0 || iSkin >= Buffer[m_iModelSkinCount])
				{
					iSkin = 0
				}
				if (iBody < 0 || iBody >= Buffer[m_iModelBodyCount])
				{
					iBody = 0
				}

				fm_DebugPrintLevel(2, " Buffer[m_sModelName]: %s iSkin: %d  iBody: %d", Buffer[m_sModelName], iSkin, iBody)

				fm_SetPlayerModel(id, Buffer[m_sModelName])
				fm_SetPlayerSkin(id, iSkin)
				fm_SetPlayerBodyValue(id, iBody) // fm_SetPlayerBody(id, iGroup, iBody)

				nvault_touch(g_iCacheVault, sPlayerIdent)
			}
		}
	}
	else // Query the database if it's not cached / cache not availiable
	{
		if (g_iPlayerQuery[id])
		{
			 fm_SQLRemoveThreadedQuery(g_iPlayerQuery[id])
		}

		new sData[1]; sData[0] = id
		formatex(g_sQuery, charsmax(g_sQuery), g_sPlayerQuery, iPlayerIdent)
		g_iPlayerQuery[id] = fm_SQLAddThreadedQuery(g_sQuery, "Handle_SelectPlayerModel", QUERY_DISPOSABLE, PRIORITY_NORMAL, sData, 1)
	}
	return PLUGIN_CONTINUE
}

public Handle_SelectPlayerModel(iFailState, Handle:hQuery, sError[], iError, sData[], iLen, Float:fQueueTime, iQueryIdent)
{
	if(fm_SQLCheckThreadedError(iFailState, hQuery, sError, iError))
	{
		return PLUGIN_HANDLED
	}

	// Since this query is threaded check that the models had not been disabled while it was queued
	if (!fm_GetPlayerModelStatus())
	{
		return PLUGIN_HANDLED
	}

	// Check the player that this query belonged to is still ingame. This shouldn't occur because I remove the query on disconnect. But it could happen if the query is already running
	new id = sData[0]
	if (g_iPlayerQuery[id] != iQueryIdent || !is_user_connected(id))
	{
		return PLUGIN_HANDLED
	}
	
	new iModelIdent = -1
	new iSkin, iBody

	if (SQL_NumResults(hQuery) > 0)
	{
		iModelIdent = SQL_ReadResult(hQuery, 0)
		new iModelIndex = fm_GetPlayerModelIndexByIdent(iModelIdent) 
		if (iModelIndex != -1)
		{
			iSkin = SQL_ReadResult(hQuery, 1)
			iBody = SQL_ReadResult(hQuery, 2)

			new Buffer[eModel_t];fm_GetPlayerModelDataByIndex(iModelIndex, Buffer)	
			fm_SetPlayerModel(id, Buffer[m_sModelName])
			fm_SetPlayerSkin(id, iSkin)
			fm_SetPlayerBodyValue(id, iBody) // fm_SetPlayerBody(id, iGroup, iBody)
		}
	}

	// Cache the result even if no results from the database
	CachePlayerModel(id, iModelIdent, iSkin, iBody) 

	return PLUGIN_HANDLED		
}

CachePlayerModel(id, iModelIdent, iSkin, iBody)
{
	fm_DebugPrintLevel(1, "CachePlayerModel(%d, %d, %d, %d)", id, iModelIdent, iSkin, iBody)

	if (g_iCacheVault == INVALID_HANDLE)
	{
		// Warning Log
		return 0
	}

	// Get the players id in the database
	new iPlayerIdent = fm_SQLGetUserIdent(id)
	if (!iPlayerIdent)
	{
		// Warning Log
		return 0
	}

	new sData[128]; formatex(sData, charsmax(sData), "%d %d %d", iModelIdent, iSkin, iBody)
	new sPlayerIdent[16]; num_to_str(iPlayerIdent, sPlayerIdent, charsmax(sPlayerIdent))
	nvault_set(g_iCacheVault, sPlayerIdent, sData)
	fm_DebugPrintLevel(1, "nvault_set(%d, %s, %s)", g_iCacheVault, sPlayerIdent, sData)

	return 1
}

SavePlayerModel(id, iModelIdent, iSkin, iBody)
{
	fm_DebugPrintLevel(1, "SavePlayerModel(%d, %d, %d, %d)", id, iModelIdent, iSkin, iBody)

	// Cache to the nvault for faster loading on mapchanges
	CachePlayerModel(id, iModelIdent, iSkin, iBody)

	// Remove a player query if it is already running
	if (g_iPlayerQuery[id])
	{
		fm_SQLRemoveThreadedQuery(g_iPlayerQuery[id])
	}

	// Get the players id in the database
	new iPlayerIdent = fm_SQLGetUserIdent(id)
	if (!iPlayerIdent)
	{
		// Warning Log
		return PLUGIN_CONTINUE
	}
	
	// Send the query to update the player's model data stored in the database
	new iLen = formatex(g_sQuery, charsmax(g_sQuery), "UPDATE players SET model_id = ")
	if (iModelIdent != -1)
	{
		iLen += formatex(g_sQuery[iLen], charsmax(g_sQuery) - iLen, "%d", iModelIdent)			
	}
	else
	{
		iLen += formatex(g_sQuery[iLen], charsmax(g_sQuery) - iLen, "NULL")
	}
	iLen += formatex(g_sQuery[iLen], charsmax(g_sQuery) - iLen, ", model_skin = %d, model_body = %d WHERE player_id = %d LIMIT 1;", iSkin, iBody, iPlayerIdent)

	new sData[1]; sData[0] = id
	g_iPlayerQuery[id] = fm_SQLAddThreadedQuery(g_sQuery, "Handle_UpdateModel", QUERY_DISPOSABLE, PRIORITY_LOW, sData, 1)	

	return 1
}

public Handle_UpdateModel(iFailState, Handle:hQuery, sError[], iError, sData[], iLen, Float:fQueueTime)
{	
	fm_SQLCheckThreadedError(iFailState, hQuery, sError, iError)
	g_iPlayerQuery[sData[0]] = 0
}
