#include "feckinmad/fm_global"
#include "feckinmad/fm_sql_tquery"
#include "feckinmad/fm_admin_access"
#include "feckinmad/fm_config"

#define MAX_CACHE_AGE 86400 // 24 hours

new const g_sDonatorQuery[] = "SELECT player_authid, donation_amount FROM players WHERE donation_amount > 0;"
new const g_sDonatorFile[] = "fm_donators_cache.dat"

enum eDonator_t
{
	m_sDonatorAuthid[MAX_AUTHID_LEN],
	m_iDonatorAmount,
}
new Array:g_DonatorList // Stores donation structure above
new g_iDonatorCount // Number of donators stored
new g_iPlayerDonation[MAX_PLAYERS + 1] = { -1, ... } // Store player donation once found
new g_iMaxPlayers

new bool:g_bPluginEnd

public plugin_init() 
{ 
	fm_RegisterPlugin()
	
	g_DonatorList = ArrayCreate(eDonator_t)	
	g_iMaxPlayers = get_maxplayers()
	register_concmd("admin_reloaddonators","Admin_ReloadDonators", ADMIN_ADMIN)

	// Read the cache file to load the donators straight away
	// Other plugins may require this info before a threaded query returns and I don't want to use blocking queries
	new iLastUpdate = ReadCacheFile()

	// Determine if the cache is old enough to warrant reloading from db
	// Using cached results saves having to query on every mapload
	if (iLastUpdate <= 0 || ((get_systime() - iLastUpdate) > MAX_CACHE_AGE)) 
	{
		fm_SQLAddThreadedQuery(g_sDonatorQuery, "Handle_QueryDonatorInfo", QUERY_DISPOSABLE, PRIORITY_HIGH)
	}
}

public plugin_end()
{
	g_bPluginEnd = true
}

ReadCacheFile()
{
	new sFile[128]; fm_BuildAMXFilePath(g_sDonatorFile, sFile, charsmax(sFile), FM_AMXX_LOCAL_DATA)
	new iFileHandle = fopen(sFile, "rb")
	if (!iFileHandle) 
	{
		fm_WarningLog(FM_FOPEN_WARNING, sFile)
		return 0
	}
	new iLastUpdate; fread(iFileHandle, iLastUpdate, BLOCK_INT)

	fseek(iFileHandle, 0, SEEK_END)
	new iCount = (ftell(iFileHandle) - BLOCK_INT) / (_:eDonator_t * BLOCK_INT)
	fseek(iFileHandle, BLOCK_INT, SEEK_SET)

	new Buffer[eDonator_t]
	for (new i = 0; i < iCount; i++)
	{
		if (fread_blocks(iFileHandle, Buffer, eDonator_t, BLOCK_INT) != _:eDonator_t)
		{
			fm_WarningLog("Failed whilst reading donator cache file (%d)", ftell(iFileHandle))
			break
		}
		fm_AddDonator(Buffer)
	}

	fclose(iFileHandle)
	log_amx("Read %d donators from \"%s\"", iCount, sFile)
	
	return iLastUpdate
}

public Admin_ReloadDonators(id, iLevel, iCommand)
{
	if (!fm_CommandAccess(id, iLevel, false)) 
	{
		return PLUGIN_HANDLED
	}

	new sData[1]; sData[0] = id 		
	fm_SQLAddThreadedQuery(g_sDonatorQuery, "Handle_QueryDonatorInfo", QUERY_DISPOSABLE, PRIORITY_NORMAL, sData, 1)

	new sAdminName[MAX_NAME_LEN]; get_user_name(id, sAdminName, charsmax(sAdminName))
	new sAdminAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAdminAuthid, charsmax(sAdminAuthid))
	new sAdminRealName[MAX_NAME_LEN]; fm_GetUserRealname(id, sAdminRealName, charsmax(sAdminRealName))
	new sCommand[32]; read_argv(0, sCommand, charsmax(sCommand))
	log_amx("\"%s<%s>(%s)\" %s", sAdminName, sAdminAuthid, sAdminRealName, sCommand)
	
	return PLUGIN_HANDLED
}

public Handle_QueryDonatorInfo(iFailState, Handle:hQuery, sError[], iError, sData[], iLen, Float:fQueueTime)
{
	// Don't process this query if it returns after plugin_end() as the dynamic array in FM_ADMIN_API.amxx will have been destroyed
	if (g_bPluginEnd)
	{
		return PLUGIN_HANDLED
	}

	// Get the id that instigated the query. Check datalen to prevent memory access errors as data won't always exist
	new id
	if (iLen > 0) 
	{
		id = sData[0]
	}

	if(fm_SQLCheckThreadedError(iFailState, hQuery, sError, iError))
	{
		if (id != 0) console_print(id, "Failed to load donators from database")
		return PLUGIN_HANDLED
	}

	ResetDonatorInfo()

	new sFile[128]; fm_BuildAMXFilePath(g_sDonatorFile, sFile, charsmax(sFile), FM_AMXX_LOCAL_DATA)
	new iFileHandle = fopen(sFile, "wb")
	if (!iFileHandle)
	{
		fm_WarningLog(FM_FOPEN_WARNING, sFile)
	}
	else
	{
		fwrite(iFileHandle, get_systime(), BLOCK_INT)
	}

	// Get the SQL results and store
	new Donator[eDonator_t]
	while(SQL_MoreResults(hQuery))
	{	
		SQL_ReadResult(hQuery, 0, Donator[m_sDonatorAuthid], charsmax(Donator[m_sDonatorAuthid]))
		Donator[m_iDonatorAmount] = SQL_ReadResult(hQuery, 1)

		fm_AddDonator(Donator)

		// Write the SQL results to cache file
		if (iFileHandle) fwrite_blocks(iFileHandle, Donator, eDonator_t, BLOCK_INT)

		SQL_NextRow(hQuery)	
	}

	if (iFileHandle) fclose(iFileHandle)

	// If this originated from an admin_reloaddonators request, print the result
	if (id != 0) console_print(id, "Loaded %d donators from database", g_iDonatorCount)

	log_amx("Wrote %d donators to \"%s\"", g_iDonatorCount, sFile)
	return PLUGIN_HANDLED
}

ResetDonatorInfo()
{
	ArrayClear(g_DonatorList)
	g_iDonatorCount = 0
		
	for (new i = 1; i <= g_iMaxPlayers; i++)
	{
		g_iPlayerDonation[i] = -1
	}
}

fm_AddDonator(Donator[eDonator_t])
{
	ArrayPushArray(g_DonatorList, Donator)
	g_iDonatorCount++
}

public plugin_natives()
{
	register_native("fm_GetPlayerDonation", "Native_GetPlayerDonation")
	register_library("fm_donator_api")
}

public Native_GetPlayerDonation() 
{
	new id = get_param(1)
	if (id < 1 || id > g_iMaxPlayers)
	{
		log_error(AMX_ERR_NATIVE, "Player out of range (%d)", id)
		return 0
	}

	if (g_iPlayerDonation[id] == -1)
	{
		g_iPlayerDonation[id] = GetPlayerDonation(id)
	}

	return g_iPlayerDonation[id]
}

GetPlayerDonation(id)
{
	new sAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAuthid, charsmax(sAuthid))
	new Donator[eDonator_t]

	for (new i = 0; i < g_iDonatorCount; i++)
	{	
		ArrayGetArray(g_DonatorList, i, Donator)
		if(equal(sAuthid, Donator[m_sDonatorAuthid])) 
		{
			return Donator[m_iDonatorAmount]
		}
	}
	return 0
}

public client_disconnect(id)
{
	g_iPlayerDonation[id] = -1
}