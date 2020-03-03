/*
DESCRIPTION
-Provides an API for threaded queries. Solves SQL module issues mentioned in NOTES below.


NOTES
-This was to solve the issues of:
  -Queries getting executed first in first out. This plugin adds a priority flag to threaded queries.
  -Queries hanging mapchange. If the map changed when there were 10 queries still in memory, the SQL module would block whilst waiting for
   them to return one by one. This plugin adds a flag to allow queries to be disposed of if they are no longer relevant at mapchange.
-Queries are stored in a dynamic array and pushed to the module by priority as the previous query returns.
-All of the feckinmad plugins used this API for SQL queries.

COMMANDS
-None

AUTHOR:
-watch

DATE:
-2006 - 2010
*/

#include "feckinmad/fm_global"
#include "feckinmad/fm_sql_api"
#include "feckinmad/fm_sql_tquery"

#define MAX_RETRY 3

enum eQueryData_t
{
	m_iQueryIdent, // Unique identifier for each query
	m_iQueryForward, // Handle to the forward to execute
	m_iQueryPriority, // Priority
	m_iQueryPlugin,// Plugin this query belongs to
	m_iQueryDisposable, // Whether the query can be discarded if machange occurs (otherwise block)
	m_iQueryDataLen, // Length of the extra data to be sent to the forward in the calling plugin
	m_sQueryData[MAX_QUERY_DATA_LEN] // Extra data sent to the forward in the calling plugin
}

new Array:g_QueryList // The actual query string to execute
new Array:g_QueryData // Data passed to the handler function in this plugin
new g_iQueryCount
new g_iTotalQueryCount

new bool:g_bPluginStart
new bool:g_bPluginEnd

new g_iCurrentQueryIdent
new g_iReturn
new g_iQueryIdentCount
new g_iQueryRetryCount // How many times the current query has been retried

public plugin_natives()
{
	g_QueryList = ArrayCreate(MAX_QUERY_LEN)
	g_QueryData = ArrayCreate(eQueryData_t)

	register_native("fm_SQLAddThreadedQuery", "Native_SQLAddThreadedQuery")
	register_native("fm_SQLRemoveThreadedQuery", "Native_RemoveThreadedQuery")

	register_library("fm_sql_tquery")
}


// native fm_AddThreadedQuery(sQuery[], sForward[], iDisposable, iPriority, QueryData[] = "", iQueryDataLen = 0)
public Native_SQLAddThreadedQuery(iPlugin, iParams) 
{
	fm_DebugPrintLevel(1, "Native_AddThreadedQuery(%d, %d)", iPlugin, iParams)

	// ------------------------------------------------------------------------------------------
	// Get the query to execute on the SQL server
	// ------------------------------------------------------------------------------------------

	static sQuery[MAX_QUERY_LEN]; get_string(1, sQuery, charsmax(sQuery))

	// -----------------------------------------------------------------------------------------
	// Check if the plugin has ended
	// ------------------------------------------------------------------------------------------

	if (g_bPluginEnd)
	{
		new sPluginFileName[32]; get_plugin(iPlugin, sPluginFileName, charsmax(sPluginFileName))
		fm_WarningLog("Plugin \"%s\" attempted to add threaded query after plugin_end (\"%s\")", sPluginFileName, sQuery)
		return 0
	}
	

	// -----------------------------------------------------------------------------------------
	// Build the data associated with this query
	// ------------------------------------------------------------------------------------------

	new Buffer[eQueryData_t]	

	Buffer[m_iQueryIdent] = ++g_iQueryIdentCount // Unique identifier for each query
	Buffer[m_iQueryPlugin] = iPlugin // Store the plugin that added this query
	Buffer[m_iQueryDisposable] = get_param(3) // Whether or not the query can be discarded if mapchange occurs

	// ------------------------------------------------------------------------------------------
	// Get the priority
	// ------------------------------------------------------------------------------------------

	new iPriority = get_param(4)
	if (iPriority < PRIORITY_LOWEST)
	{
		iPriority = PRIORITY_LOWEST
	}
	else if (iPriority > PRIORITY_HIGHEST)
	{
		iPriority = PRIORITY_HIGHEST
	}
	Buffer[m_iQueryPriority] = iPriority

	// ------------------------------------------------------------------------------------------
	// Get the data the plugin wants to pass through to its function handler
	// ------------------------------------------------------------------------------------------

	Buffer[m_iQueryDataLen] = get_param(6)
	if (Buffer[m_iQueryDataLen] > MAX_QUERY_DATA_LEN)
	{
		Buffer[m_iQueryDataLen]	= MAX_QUERY_DATA_LEN
		//fm_WarningLog()
	}
	get_array(5, Buffer[m_sQueryData], Buffer[m_iQueryDataLen])
	
	// ------------------------------------------------------------------------------------------
	// Get the handler function
	// ------------------------------------------------------------------------------------------

	static sForward[32]; sForward[0] = 0
	get_string(2, sForward, charsmax(sForward))

	
	// Store the forward to the handler function in calling plugin which will be executed once the query returns
	//								iFailState	hQuery		sError		iError		sData[]		iLen		fQueueTime	iQueryIdent
	Buffer[m_iQueryForward] = CreateOneForward(iPlugin, sForward, 	FP_CELL, 	FP_CELL, 	FP_STRING,	FP_CELL, 	FP_ARRAY /*FP_STRING*/,	FP_CELL, 	FP_FLOAT, 	FP_CELL)

	// Check the forward is valid
	if (Buffer[m_iQueryForward] <= 0)
	{
		log_error(AMX_ERR_NOTFOUND, "Function \"%s\" was not found", sForward)
		return 0
	}
	
	// ------------------------------------------------------------------------------------------

	ArrayPushString(g_QueryList, sQuery)
	ArrayPushArray(g_QueryData, Buffer)
	g_iQueryCount++

	// Run the query now if plugin_cfg has already been called and this is the only query in the queue
	// This ensures the first query to run is not the first query added during plugin_init
	if (g_bPluginStart && g_iQueryCount == 1)
	{
		RunThreadedQuery(0)
	}

	return Buffer[m_iQueryIdent]
}

public Native_RemoveThreadedQuery(iPlugin, iParams)
{
	fm_DebugPrintLevel(1, "Native_RemoveThreadedQuery(%d, %d)", iPlugin, iParams)

	new iIdent = get_param(1)

	if (g_iCurrentQueryIdent == iIdent)
	{
		fm_DebugPrintLevel(2, "Unable to remove query in progress")
		return 0
	}

	new Buffer[eQueryData_t]
	for (new i = 0; i < g_iQueryCount; i++)
	{
		ArrayGetArray(g_QueryData, i, Buffer)
		if (iIdent == Buffer[m_iQueryIdent])
		{
			fm_DebugPrintLevel(2, "Query ident %d found", iIdent)

			if (iPlugin == Buffer[m_iQueryPlugin])
			{
				RemoveQueryByIndex(i)
				return 1
			}
			else
			{
				new sFile[32]; get_plugin(i, sFile, charsmax(sFile))
				fm_WarningLog("Plugin: \"%s\" attempted to remove a query it doesn't own", sFile)
				return 0
			}
		}
	}
	fm_DebugPrintLevel(2, "Query ident %d not found", iIdent)

	return 0
}


public plugin_init() 
{
	fm_RegisterPlugin()

	// Add a small delay to ensure the first threaded query added is not executed
	// It could precede a higher priority query which hasn't been added yet because of the plugin order in plugins.ini
	set_task(0.1, "InitQueryQueue")
}

public InitQueryQueue()
{
	g_bPluginStart = true	
	RunNextQueryByPriority()
}

RunNextQueryByPriority()
{
	fm_DebugPrintLevel(1, "RunNextQueryByPriority()")

	new Buffer[eQueryData_t], iIndex = -1, iHighest = -1

	for (new i = 0; i < g_iQueryCount; i++)
	{
		ArrayGetArray(g_QueryData, i, Buffer)
		if (Buffer[m_iQueryPriority] > iHighest)
		{
			iHighest = Buffer[m_iQueryPriority]
			iIndex = i
		}
	}

	if (iIndex != -1)
	{
		RunThreadedQuery(iIndex)
	}
}

public RunThreadedQuery(iIndex)
{
	fm_DebugPrintLevel(1, "RunThreadedQuery(%d)", iIndex)

	static sQuery[MAX_QUERY_LEN]; ArrayGetString(g_QueryList, iIndex, sQuery, charsmax(sQuery))
	static Data[eQueryData_t]; ArrayGetArray(g_QueryData, iIndex, Data)
	
	g_iCurrentQueryIdent = iIndex

	fm_DebugPrintLevel(2, "Running Query: Index %d Ident: %d Priority: %d", iIndex, Data[m_iQueryIdent], Data[m_iQueryPriority])
	fm_DebugPrintLevel(3, sQuery)
	
	new Handle:SqlTuple = fm_SQLGetHandle()
	if (SqlTuple != Empty_Handle)	
	{		
		SQL_ThreadQuery(SqlTuple, "Handle_ThreadedQuery", sQuery, Data, sizeof(Data))

		g_iTotalQueryCount++
		static sLogFile[32]; get_time("query_%Y%m%d.log", sLogFile, charsmax(sLogFile))
		log_to_file(sLogFile, sQuery)
	}
	else // Execute the forward with our custom failstate 
	{
		g_iCurrentQueryIdent = 0
		if (!g_bPluginEnd)
		{
			RemoveQueryByIndex(iIndex)
		}

		new iDataArray = PrepareArray(Data[m_sQueryData], Data[m_iQueryDataLen])
		ExecuteForward(Data[m_iQueryForward], g_iReturn, TQUERY_TUPLE_FAILED, 0, sQuery, 0, iDataArray, Data[m_iQueryDataLen], 0.0, _:Data[m_iQueryIdent])	
	}
}

public Handle_ThreadedQuery(iFailState, Handle:hQuery, sError[], iError, Data[], iLen, Float:fQueueTime)
{
	if (iFailState == TQUERY_CONNECT_FAILED && g_iQueryRetryCount <= MAX_RETRY)
	{
		set_task(0.5, "RunThreadedQuery", 0)
		g_iQueryRetryCount++
		return PLUGIN_HANDLED
	}

	static sLogFile[32]; get_time("query_%Y%m%d.log", sLogFile, charsmax(sLogFile))
	log_to_file(sLogFile, "#%d: Queue Size: %d - Retry Count: %d - Last Query Queue Time %f", g_iQueryIdentCount, g_iQueryCount, g_iQueryRetryCount, fQueueTime)

	g_iQueryRetryCount = 0
	g_iCurrentQueryIdent = 0

	// Execute the handler function (The parameters are similar to the function called by mysqlx, except the query ident is also sent after queue time)
	new iDataArray = PrepareArray(Data[m_sQueryData], Data[m_iQueryDataLen])
	ExecuteForward(_:Data[m_iQueryForward], g_iReturn, iFailState, hQuery, sError, iError, iDataArray, _:Data[m_iQueryDataLen], fQueueTime, _:Data[m_iQueryIdent])
	
	// If this is called after plugin_end() we cannot add queries anymore ([MySQL] Thread worker was unable to start)
	// The remaining queries will have already been added in plugin_end() and any disposable ones will have been discarded
	if (!g_bPluginEnd) 
	{
		// Find the index of the query and remove it from the array
		new iIndex = GetQueryIndexByIdent(Data[m_iQueryIdent])
		if (iIndex != -1)
		{ 
			RemoveQueryByIndex(iIndex)
		}

		RunNextQueryByPriority()
	}
	return PLUGIN_HANDLED
}

RemoveQueryByIndex(iIndex)
{
	fm_DebugPrintLevel(1, "RemoveQueryByIndex(%d)", iIndex)

	ArrayDeleteItem(g_QueryList, iIndex)
	ArrayDeleteItem(g_QueryData, iIndex)
	g_iQueryCount--
}

public plugin_end()
{
	fm_DebugPrintLevel(1, "plugin_end()")

	g_bPluginEnd = true

	// Add all queries that aren't disposable to the mysqlx module queue before it shuts down
	new Buffer[eQueryData_t]
	for (new i = 0; i < g_iQueryCount; i++)
	{
		ArrayGetArray(g_QueryData, i, Buffer)
		if (!Buffer[m_iQueryDisposable])
		{
			RunThreadedQuery(0)
		}
		else
		{
			fm_DebugPrintLevel(2, "Skipping Query: Index %d Ident: %d", i, Buffer[m_iQueryIdent])
		}
	}
		
	ArrayDestroy(g_QueryList)
	ArrayDestroy(g_QueryData)
}

GetQueryIndexByIdent(iIdent)
{
	new Buffer[eQueryData_t]
	for (new i = 0; i < g_iQueryCount; i++)
	{
		ArrayGetArray(g_QueryData, i, Buffer)
		if (iIdent == Buffer[m_iQueryIdent])
			return i // Return the index
	}
	return -1
}

public fm_ScreenMessage(sBuffer[], iSize)
{
	formatex(sBuffer, iSize, "Since mapchange we've executed %d queries on the SQL database!", g_iTotalQueryCount)
}

