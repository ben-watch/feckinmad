#include "feckinmad/fm_global"
#include "feckinmad/fm_sql_tquery"
#include "feckinmad/fm_admin_api"
#include "feckinmad/fm_admin_access" // for fm_CommandAccess(...)

new const g_sAdminQuery[] = "SELECT access_id, access_active, player_authid, access_level, access_realname, access_password FROM access, players WHERE players.player_id = access.player_id AND access_active = 1"

new const g_sTextDatabaseSuccess[] = "Loaded %d admins from database"
new const g_sTextDatabaseFailed[] = "Failed to load admins from database"

new bool:g_bPluginEnd

public plugin_init()
{
	fm_RegisterPlugin()
	register_concmd("admin_reloadadmins", "Admin_ReloadAdmins", ADMIN_HIGHER, "- Queries the database for admin information")
	fm_SQLAddThreadedQuery(g_sAdminQuery, "Handle_QueryAdminInfo", QUERY_DISPOSABLE, PRIORITY_HIGH)	
}

public Admin_ReloadAdmins(id, iLevel, iCommand)
{
	if (!fm_CommandAccess(id, iLevel, true))
	{
		return PLUGIN_HANDLED
	}

	new Data[1]; Data[0] = id 
	fm_SQLAddThreadedQuery(g_sAdminQuery, "Handle_QueryAdminInfo", QUERY_DISPOSABLE, PRIORITY_NORMAL, Data, 1)

	new sAdminName[MAX_NAME_LEN]; get_user_name(id, sAdminName, charsmax(sAdminName))
	new sAdminAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAdminAuthid, charsmax(sAdminAuthid))
	new sAdminRealName[MAX_NAME_LEN]; fm_GetUserRealname(id, sAdminRealName, charsmax(sAdminRealName))

	log_amx("\"%s<%s>(%s)\" admin_reloadadmins", sAdminName, sAdminAuthid, sAdminRealName)
	
	return PLUGIN_HANDLED
}

public Handle_QueryAdminInfo(iFailState, Handle:hQuery, sError[], iError, Data[], iDataLen, Float:fQueueTime, iQueryIdent)
{
	fm_DebugPrintLevel(1, "Handle_QueryAdminInfo: %f", fQueueTime)

	// ------------------------------------------------------------------------------------------------------------------------------
	// Don't process this query if it returns after plugin_end() as the dynamic array in FM_ADMIN_API.amxx will have been destroyed
	// ------------------------------------------------------------------------------------------------------------------------------
	if (g_bPluginEnd)
	{
		return PLUGIN_HANDLED
	}

	// ------------------------------------------------------------------------------------------------------------------------------
	// Get the id that instigated the query. Check datalen to prevent memory access errors
	// ------------------------------------------------------------------------------------------------------------------------------
	new id
	if (iDataLen > 0) 
	{
		id = Data[0]
	}

	// ------------------------------------------------------------------------------------------------------------------------------
	// Check if the query failed and print/log messages
	// ------------------------------------------------------------------------------------------------------------------------------
	if(fm_SQLCheckThreadedError(iFailState, hQuery, sError, iError))
	{
		console_print(id, g_sTextDatabaseFailed)
		log_amx(g_sTextDatabaseFailed)
		return PLUGIN_HANDLED
	}

	// ------------------------------------------------------------------------------------------------------------------------------
	// Run this function in FM_ADMIN_API.amxx to clear existing admin info stored 
	// ------------------------------------------------------------------------------------------------------------------------------
	fm_ClearAdminInfo()
	
	// ------------------------------------------------------------------------------------------------------------------------------
	// Loop through SQL query results 
	// ------------------------------------------------------------------------------------------------------------------------------
	new Buffer[eAdmin_t], iAdminCount
	while(SQL_MoreResults(hQuery))
	{	
		Buffer[m_iAdminIdent] = SQL_ReadResult(hQuery, 0)
		Buffer[m_iAdminActive] = SQL_ReadResult(hQuery, 1)
		SQL_ReadResult(hQuery, 2, Buffer[m_sAdminAuthid], MAX_AUTHID_LEN - 1)
		Buffer[m_iAdminAccess] = SQL_ReadResult(hQuery, 3)
		SQL_ReadResult(hQuery, 4, Buffer[m_sAdminName], MAX_AUTHID_LEN - 1)
		SQL_ReadResult(hQuery, 5, Buffer[m_sAdminPassword], 31)

		// ------------------------------------------------------------------------------------------------------------------------------
		// Add admin to the dynamic array in FM_ADMIN_API.amxx
		// ------------------------------------------------------------------------------------------------------------------------------
		fm_AddAdminInfo(Buffer) 
		iAdminCount++

		SQL_NextRow(hQuery)
	}

	console_print(id, g_sTextDatabaseSuccess, iAdminCount)
	log_amx(g_sTextDatabaseSuccess, iAdminCount)

	// ------------------------------------------------------------------------------------------------------------------------------
	// Tell FM_ADMIN_API.amxx that we have updated admin information so it can run a forward to tell other plugins
	// ------------------------------------------------------------------------------------------------------------------------------
	// FM_ADMIN_CACHE.amxx will use this to write the updated list to the cache file
	// FM_ADMIN_ACCESS.amxx will refresh access for players connected
	// ------------------------------------------------------------------------------------------------------------------------------
	fm_InfoAdminUpdated()

	return PLUGIN_HANDLED	
}

public plugin_end()
{
	g_bPluginEnd = true
}
