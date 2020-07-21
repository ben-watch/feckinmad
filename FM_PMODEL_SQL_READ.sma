#include "feckinmad/fm_global"
#include "feckinmad/fm_sql_tquery"
#include "feckinmad/fm_mapfunc" // fm_IsMapNameInFile()
#include "feckinmad/fm_playermodel_api"

#define MAX_DB_CACHE_AGE 86400 // 24 hours
#define ALWAYS_LOAD 1 // Overwrite the cache age. I find querying models every mapchange actually works best, but I don't want to move the cache code.

new const g_sModelQuery[] = "SELECT model_id, model_name FROM models WHERE model_active=1"
new const g_sModelFile[] = "fm_pmodels_cache.dat" // File to which database model information is saved

new bool:g_bPluginEnd
new g_iLastDatabaseUpdate // The systime the database was last queried. Loaded from cache file

public plugin_precache()
{
	new sFile[128]; fm_BuildAMXFilePath(g_sExcludeFile, sFile, charsmax(sFile), "amxx_configsdir")
	new sCurrentMap[MAX_MAP_LEN]; get_mapname(sCurrentMap, charsmax(sCurrentMap))

	if (!fm_IsMapNameInFile(sCurrentMap, sFile))
	{
		// Read the cache file to load the models here so I can precache. 
		// I don't want to use a blocking query to avoid hanging mapchanges
		g_iLastDatabaseUpdate = ReadCacheFile()
	}
	else
	{
		fm_SetPlayerModelDisabled()
	}
}

public plugin_natives()
{
	register_native("fm_PlayerModelReload", "Native_PlayerModelReload")
}

public Native_PlayerModelReload()
{
	RunPlayerModelQuery()
}

ReadCacheFile()
{
	fm_DebugPrintLevel(1, "ReadCacheFile()")

	new sFile[128]; fm_BuildAMXFilePath(g_sModelFile, sFile, charsmax(sFile), FM_AMXX_LOCAL_DATA)
	new iFileHandle = fopen(sFile, "rb")
	if (!iFileHandle) 
	{
		fm_WarningLog(FM_FOPEN_WARNING, sFile)
		return 0
	}
	fread(iFileHandle, g_iLastDatabaseUpdate, BLOCK_INT)

	new iLastUpdate = fseek(iFileHandle, 0, SEEK_END)
	new iCount = (ftell(iFileHandle) - BLOCK_INT) / (_:eModel_t * BLOCK_INT)
	fseek(iFileHandle, BLOCK_INT, SEEK_SET)

	new Buffer[eModel_t]
	for (new i = 0; i < iCount; i++)
	{
		if (fread_blocks(iFileHandle, Buffer, eModel_t, BLOCK_INT) != _:eModel_t)
		{
			fm_WarningLog("Failed whilst reading model cache file (%d)", ftell(iFileHandle))
			break
		}
		fm_AddPlayerModel(Buffer[m_iModelIdent], Buffer[m_sModelName])
	}

	fclose(iFileHandle)
	log_amx("Read %d models from \"%s\"", iCount, sFile)
	
	return iLastUpdate
}


public plugin_init() 
{ 
	fm_RegisterPlugin()

	// Determine if the cache is old enough to warrant reloading from db. Using cached results saves having to query on every mapload
	if (ALWAYS_LOAD || (g_iLastDatabaseUpdate <= 0 || ((get_systime() - g_iLastDatabaseUpdate) > MAX_DB_CACHE_AGE))) 
	{
		RunPlayerModelQuery()
	}	
	
}

RunPlayerModelQuery()
{
	fm_SQLAddThreadedQuery(g_sModelQuery, "Handle_QueryModelInfo", QUERY_DISPOSABLE, PRIORITY_LOW)
}

public Handle_QueryModelInfo(iFailState, Handle:hQuery, sError[], iError, sData[], iLen, Float:fQueueTime)
{
	if (g_bPluginEnd)
	{
		return PLUGIN_HANDLED
	}

	if(fm_SQLCheckThreadedError(iFailState, hQuery, sError, iError))
	{
		return PLUGIN_HANDLED
	}

	new sFile[128]; fm_BuildAMXFilePath(g_sModelFile, sFile, charsmax(sFile), FM_AMXX_LOCAL_DATA)
	new iFileHandle = fopen(sFile, "wb")
	if (!iFileHandle)
	{
		fm_WarningLog(FM_FOPEN_WARNING, sFile)
		return PLUGIN_HANDLED
	}

	fwrite(iFileHandle, get_systime(), BLOCK_INT)

	// Get the SQL results and store
	new Buffer[eModel_t], iCount
	while(SQL_MoreResults(hQuery))
	{	
		Buffer[m_iModelIdent] = SQL_ReadResult(hQuery, 0)
		SQL_ReadResult(hQuery, 1, Buffer[m_sModelName], charsmax(Buffer[m_sModelName]))
		fwrite_blocks(iFileHandle, Buffer, eModel_t, BLOCK_INT) // Write the SQL results to cache file
		iCount++

		SQL_NextRow(hQuery)	
	}

	fclose(iFileHandle)
	log_amx("Wrote %d models to \"%s\"", iCount, sFile)
	
	return PLUGIN_HANDLED
}

public plugin_end()
{
	g_bPluginEnd = true
}