#include "feckinmad/fm_global"
#include "feckinmad/fm_sql_tquery"

new const g_sMapIdentForward[] = "fm_SQLMapIdent"
new const g_sMapIdentQuery[] = "SELECT map_id, root_id FROM maps WHERE map_name = '%s' LIMIT 1;"

new g_iMapIdent, g_iMapRootIdent
new g_iForward, g_iReturn

public plugin_init()
{
	fm_RegisterPlugin()
	
	g_iForward = CreateMultiForward(g_sMapIdentForward, ET_IGNORE, FP_CELL, FP_CELL)
	if (g_iForward > 0)
	{
		new sCurrentMap[MAX_MAP_LEN]; get_mapname(sCurrentMap, charsmax(sCurrentMap))
		new sQuery[128]; formatex(sQuery, charsmax(sQuery), g_sMapIdentQuery, sCurrentMap)
		fm_SQLAddThreadedQuery(sQuery, "Handle_GetMapIdent", QUERY_DISPOSABLE, PRIORITY_HIGH, sCurrentMap, strlen(sCurrentMap) + 1)		
	}
	else
	{
		fm_WarningLog(FM_FORWARD_WARNING, g_sMapIdentForward)
	}
}


public plugin_natives()
{	
	register_native("fm_SQLGetMapIdent", "Native_SQLGeMapIdent")
	register_library("fm_map_ident")	
}

public Native_SQLGeMapIdent()
{	
	return g_iMapIdent
}

public Handle_GetMapIdent(iFailState, Handle:hQuery, sError[], iError, Data[], iDataSize, Float:fQueueTime, iQueryIdent)
{
	fm_DebugPrintLevel(1, "Handle_GetMapIdent: %f", fQueueTime)

	if(fm_SQLCheckThreadedError(iFailState, hQuery, sError, iError))
	{
		fm_WarningLog("Failed to load map ident for \"%s\" from database", Data)
		return PLUGIN_HANDLED
	}
	
	if (SQL_NumResults(hQuery) > 0)	
	{			
		g_iMapIdent = SQL_ReadResult(hQuery, 0)
		g_iMapRootIdent = SQL_ReadResult(hQuery, 1)

		fm_DebugPrintLevel(2, "Loaded map ident for \"%s\" from database: #%d", Data, g_iMapIdent)
		ExecuteForward(g_iForward, g_iReturn, g_iMapIdent, g_iMapRootIdent)
	}
	else
	{	
		new sQuery[128]; formatex(sQuery, charsmax(sQuery), "INSERT INTO maps (map_name) VALUES ('%s');", Data)
		fm_SQLAddThreadedQuery(sQuery, "Handle_InsertMapIdent", QUERY_DISPOSABLE, PRIORITY_HIGH, Data, iDataSize)
	}
	return PLUGIN_HANDLED
}

public Handle_InsertMapIdent(iFailState, Handle:hQuery, sError[], iError, Data[], iDataSize, Float:fQueueTime, iQueryIdent)
{
	fm_DebugPrintLevel(1, "Handle_InsertMapIdent: %f", fQueueTime)

	if(fm_SQLCheckThreadedError(iFailState, hQuery, sError, iError) || !(g_iMapIdent = SQL_GetInsertId(hQuery)))
	{
		fm_WarningLog("Failed to insert map ident for \"%s\" into database", Data)
		return PLUGIN_HANDLED
	}

	fm_DebugPrintLevel(2, "Added map ident for \"%s\" to database: #%d", Data, g_iMapIdent)
	ExecuteForward(g_iForward, g_iReturn, g_iMapIdent, g_iMapRootIdent)

	return PLUGIN_HANDLED
}
