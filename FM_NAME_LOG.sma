#include "feckinmad/fm_global"
#include "feckinmad/fm_sql_player"
#include "feckinmad/fm_sql_tquery"
#include "feckinmad/fm_player_get"
#include "feckinmad/fm_admin_access" // fm_CommandAccess()
#include "feckinmad/fm_time"

#include <fakemeta> // engfunc(), register_forward()

#define QUERY_LIMIT 10

enum eNameData_t
{
	m_sPlayerName[MAX_NAME_LEN * 2],
	m_iPlayerNameIdent,
	m_iPlayerNameTimeStamp
}

new Float:g_fPlayerNextNameChange[MAX_PLAYERS + 1]
new g_sQuery[512]

public plugin_init()
{
	fm_RegisterPlugin()

	register_concmd("admin_listidsbyname", "Admin_ListIdsByName", ADMIN_MEMBER, "<name> [start] - Lists the 10 most recent steam ids that have used specified name")
	register_concmd("admin_listcommonnames", "Admin_ListCommonNames", ADMIN_MEMBER, "<target|steamid> - Lists 10 most commonly used names by target")
	register_concmd("admin_listrecentnames", "Admin_ListRecentNames", ADMIN_MEMBER, "<target|steamid> - Lists 10 most recently used names by target")

	register_forward(FM_ClientUserInfoChanged, "Forward_ClientUserInfoChanged")
}


//----------------------------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------------------------


new const g_sAuthidByNameQuery[] = "SELECT players.player_authid, last_used FROM players, player_names, player_names_link \
WHERE players.player_id = player_names_link.player_id AND player_names.name_id = player_names_link.name_id \
AND player_names.player_name = '%s' ORDER BY last_used DESC LIMIT %d,%d";

public Admin_ListIdsByName(id, iLevel, iCommand)
{
	//----------------------------------------------------------------------------------------------------
	// Check the user has access and entered the correct number of arguments
	//----------------------------------------------------------------------------------------------------

	if (!fm_CommandAccess(id, iLevel, true) || !fm_CommandUsage(id, iCommand, 2))
	{
		return PLUGIN_HANDLED
	}

	new sArgs[64], sName[MAX_NAME_LEN * 2], sStart[16]
	read_args(sArgs, charsmax(sArgs))
	parse(sArgs, sName, charsmax(sName), sStart, charsmax(sStart))

	new iStart = str_to_num(sStart)
	if (iStart < 0)
	{
		iStart = 0
	}

	fm_SQLMakeStringSafe(sName, (MAX_NAME_LEN * 2) - 1)
	formatex(g_sQuery, charsmax(g_sQuery), g_sAuthidByNameQuery, sName, iStart, QUERY_LIMIT)

	new Data[1]; Data[0] = id
	fm_SQLAddThreadedQuery(g_sQuery, "Handle_ListNames", QUERY_DISPOSABLE, PRIORITY_HIGH, Data, 1)

	console_print(id, "Players who have used the name: \"%s\":", QUERY_LIMIT, sName)

	return PLUGIN_HANDLED
}

//----------------------------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------------------------

new const g_sRecentNameQuery[] = "SELECT player_names.player_name, last_used FROM players, player_names, player_names_link \
WHERE players.player_id = player_names_link.player_id AND player_names.name_id = player_names_link.name_id \
AND players.player_authid = '%s' \
ORDER BY last_used DESC LIMIT %d;"

public Admin_ListRecentNames(id, iLevel, iCommand)
{
	//----------------------------------------------------------------------------------------------------
	// Check the user has access and entered the correct number of arguments
	//----------------------------------------------------------------------------------------------------

	if (!fm_CommandAccess(id, iLevel, true) || !fm_CommandUsage(id, iCommand, 2))
	{
		return PLUGIN_HANDLED
	}

	//----------------------------------------------------------------------------------------------------

	//----------------------------------------------------------------------------------------------------

	new sArgs[192], sAuthid[MAX_AUTHID_LEN * 2]
	read_args(sArgs, charsmax(sArgs))
	
	new iPlayer = fm_CommandGetPlayer(id, sArgs)
	if (!iPlayer)
	{
		if (!equal(sArgs, "STEAM_", 6))
		{
			return PLUGIN_HANDLED
		}
		copy(sAuthid, charsmax(sAuthid), sArgs)
	}
	else
	{
		get_user_authid(iPlayer, sAuthid, charsmax(sAuthid))
	}


	fm_SQLMakeStringSafe(sAuthid, (MAX_AUTHID_LEN * 2) - 1)
	formatex(g_sQuery, charsmax(g_sQuery), g_sRecentNameQuery, sAuthid, QUERY_LIMIT)

	new Data[1]; Data[0] = id
	fm_SQLAddThreadedQuery(g_sQuery, "Handle_ListNames", QUERY_DISPOSABLE, PRIORITY_HIGH, Data, 1)

	console_print(id, "Most recent names used by \"%s\":", sAuthid)

	return PLUGIN_HANDLED
}

new const g_sCommonNameQuery[] = "SELECT player_names.player_name, last_used FROM players, player_names, player_names_link \
WHERE players.player_id = player_names_link.player_id AND player_names.name_id = player_names_link.name_id \
AND players.player_authid = '%s' \
ORDER BY times_used DESC LIMIT %d;"

public Admin_ListCommonNames(id, iLevel, iCommand)
{
	//----------------------------------------------------------------------------------------------------
	// Check the user has access and entered the correct number of arguments
	//----------------------------------------------------------------------------------------------------

	if (!fm_CommandAccess(id, iLevel, true) || !fm_CommandUsage(id, iCommand, 2))
	{
		return PLUGIN_HANDLED
	}

	new sArgs[192], sAuthid[MAX_AUTHID_LEN * 2]
	read_args(sArgs, charsmax(sArgs))
	
	new iPlayer = fm_CommandGetPlayer(id, sArgs)
	if (!iPlayer)
	{
		if (!equal(sArgs, "STEAM_", 6))
		{
			return PLUGIN_HANDLED
		}
		copy(sAuthid, charsmax(sAuthid), sArgs)
	}
	else
	{
		get_user_authid(iPlayer, sAuthid, charsmax(sAuthid))
	}

	replace_all(sAuthid, (MAX_AUTHID_LEN * 2) - 1, "\\", "\\\\'")
	replace_all(sAuthid, (MAX_AUTHID_LEN * 2) - 1, "'", "\\'")

	new Data[1]; Data[0] = id
	formatex(g_sQuery, charsmax(g_sQuery), g_sCommonNameQuery, sAuthid, QUERY_LIMIT)
	fm_SQLAddThreadedQuery(g_sQuery, "Handle_ListNames", QUERY_DISPOSABLE, PRIORITY_HIGH, Data, 1)

	console_print(id, "Most common names used by \"%s\":", sAuthid)

	return PLUGIN_HANDLED
}

public Handle_ListNames(iFailState, Handle:hQuery, sError[], iError, Data[], iDataLen, Float:fQueueTime, iQueryIdent)
{
	fm_DebugPrintLevel(1, "Handle_ListCommonNames: %f", fQueueTime)

	new id = Data[0]
	if(fm_SQLCheckThreadedError(iFailState, hQuery, sError, iError))
	{
		console_print(id, "There was problem querying the database")
		return PLUGIN_HANDLED
	}

	new iCount = SQL_NumResults(hQuery)
	if (!iCount)
	{
		console_print(id, "No results returned from the database")
		return PLUGIN_HANDLED
	}

	new sName[MAX_NAME_LEN], sTime[64], iSecs, i, iLastUsed
	new iTimeStamp = get_systime()

	while(SQL_MoreResults(hQuery)) 
	{	
		SQL_ReadResult(hQuery, 0, sName, charsmax(sName))
	
		// Check last_used != 0 because of importing name data collected from a previous plugin that didn't include timestamps
		iLastUsed = SQL_ReadResult(hQuery, 1)
		if (!iLastUsed)
		{
			copy(sTime, charsmax(sTime), "Unknown")
		}
		else
		{
			iSecs = iTimeStamp - iLastUsed
			fm_SecondsToText(iSecs, sTime, charsmax(sTime), 1)
			add(sTime, charsmax(sTime), " ago")
		}

		console_print(Data[0], "\t\t#%d %s - %s", ++i, sName, sTime)
		SQL_NextRow(hQuery)
	}

	console_print(id, "Total: %d", iCount)

	return PLUGIN_HANDLED
}

//----------------------------------------------------------------------------------------------------
// Use this forward from FM_SQL_PLAYER.amxx to log names on connect
//----------------------------------------------------------------------------------------------------

public fm_SQLPlayerIdent(id, iPlayerIdent)
{
	new sName[MAX_NAME_LEN]; get_user_name(id, sName, charsmax(sName))
	LogPlayerName(iPlayerIdent, sName)
}

//----------------------------------------------------------------------------------------------------
// Hook to detect name changes
//----------------------------------------------------------------------------------------------------

public Forward_ClientUserInfoChanged(id, Buffer)
{
	//----------------------------------------------------------------------------------------------------
	// Check the user is actually connected to prevent blank name changes
	//----------------------------------------------------------------------------------------------------

	if (!is_user_connected(id))
	{
		return FMRES_IGNORED
	}

	//----------------------------------------------------------------------------------------------------
	// Check if the player name has changed
	//----------------------------------------------------------------------------------------------------

	static sOldName[MAX_NAME_LEN]; get_user_name(id, sOldName, charsmax(sOldName))
	static sNewName[MAX_NAME_LEN]; engfunc(EngFunc_InfoKeyValue, Buffer, "name", sNewName, charsmax(sNewName))	

	if (equal(sOldName, sNewName))
	{
		return FMRES_IGNORED
	}

	//----------------------------------------------------------------------------------------------------
	// Player name has changed, check if they recently changed it to prevent spam
	//----------------------------------------------------------------------------------------------------

	new Float:fGameTime = get_gametime()
	if (fGameTime < g_fPlayerNextNameChange[id])
	{
		//----------------------------------------------------------------------------------------------------
		// They changed their name recently so don't allow
		//----------------------------------------------------------------------------------------------------

		engfunc(EngFunc_SetClientKeyValue, id, Buffer, "name", sOldName)
		client_cmd(id, "name \"%s\"; setinfo name \"%s\"", sOldName, sOldName)

		console_print(id, "Please wait another %d seconds before changing your name", floatround(g_fPlayerNextNameChange[id] - fGameTime, floatround_ceil))	
		return FMRES_SUPERCEDE
	}
	else
	{
		//----------------------------------------------------------------------------------------------------
		// 
		//----------------------------------------------------------------------------------------------------

		new iPlayerIdent = fm_SQLGetUserIdent(id)
		if (!iPlayerIdent)
		{
			fm_WarningLog("Unable to log name change. iPlayerIdent is 0")
			return FMRES_IGNORED
		}

		LogPlayerName(iPlayerIdent, sNewName)
		g_fPlayerNextNameChange[id] = fGameTime + 5.0
	}
	return FMRES_IGNORED
}

//----------------------------------------------------------------------------------------------------
// Reset player name change time on disconnect
//----------------------------------------------------------------------------------------------------

public client_disconnected(id)
{
	g_fPlayerNextNameChange[id] = 0.0
}

LogPlayerName(iPlayerIdent, sName[])
{
	static Data[eNameData_t]

	//----------------------------------------------------------------------------------------------------
	// Fill the data struct to send with the query
	//----------------------------------------------------------------------------------------------------

	copy(Data[m_sPlayerName], (MAX_NAME_LEN * 2) - 1, sName)
	replace_all(Data[m_sPlayerName], (MAX_NAME_LEN * 2) - 1, "'", "\\'")

	Data[m_iPlayerNameIdent] = iPlayerIdent
	Data[m_iPlayerNameTimeStamp] = get_systime()

	//----------------------------------------------------------------------------------------------------
	// Run a query to locate the name_id in the database
	//----------------------------------------------------------------------------------------------------

	formatex(g_sQuery, charsmax(g_sQuery), "SELECT name_id FROM player_names WHERE player_name = '%s'", Data[m_sPlayerName])
	fm_SQLAddThreadedQuery(g_sQuery, "Handle_SelectName", QUERY_DISPOSABLE, PRIORITY_LOWEST, Data, _:eNameData_t)
}

public Handle_SelectName(iFailState, Handle:hQuery, sError[], iError, Data[], iDataLen, Float:fQueueTime, iQueryIdent)
{
	fm_DebugPrintLevel(1, "Handle_SelectName: %f", fQueueTime)

	if(fm_SQLCheckThreadedError(iFailState, hQuery, sError, iError))
	{
		return PLUGIN_HANDLED
	}

	if (!SQL_NumResults(hQuery))
	{	
		//----------------------------------------------------------------------------------------------------
		// Name was not found in the database, add it
		//----------------------------------------------------------------------------------------------------

		formatex(g_sQuery, charsmax(g_sQuery), "INSERT INTO player_names (player_name) VALUES ('%s');", Data[m_sPlayerName])
		fm_SQLAddThreadedQuery(g_sQuery, "Handle_InsertName", QUERY_DISPOSABLE, PRIORITY_LOWEST, Data, _:eNameData_t)	
	}
	else
	{
		//----------------------------------------------------------------------------------------------------
		// Name was found in the database, add a record of the player using it using the name_id
		//----------------------------------------------------------------------------------------------------

		formatex(g_sQuery, charsmax(g_sQuery), "INSERT INTO player_names_link (player_id, name_id, last_used, times_used) VALUES ('%d', '%d', '%d', '1') ON DUPLICATE KEY UPDATE times_used = times_used + 1, last_used = %d;", Data[m_iPlayerNameIdent], SQL_ReadResult(hQuery, 0), Data[m_iPlayerNameTimeStamp], Data[m_iPlayerNameTimeStamp])
		fm_SQLAddThreadedQuery(g_sQuery, "Handle_InsertPlayerName", QUERY_DISPOSABLE, PRIORITY_LOWEST, Data, _:eNameData_t)
	}
	return PLUGIN_HANDLED
}

public Handle_InsertName(iFailState, Handle:hQuery, sError[], iError, Data[], iDataLen, Float:fQueueTime, iQueryIdent)
{
	fm_DebugPrintLevel(1, "Handle_InsertName: %f", fQueueTime)

	if(fm_SQLCheckThreadedError(iFailState, hQuery, sError, iError))
	{
		return PLUGIN_HANDLED
	}
	
	new iNameIndex = SQL_GetInsertId(hQuery)
	if (!iNameIndex)
	{
		fm_WarningLog("Unable to insert name into database. iNameIndex is 0")
	}
	else
	{
		formatex(g_sQuery, charsmax(g_sQuery), "INSERT INTO player_names_link (player_id, name_id, last_used, times_used) VALUES ('%d', '%d', '%d', '1') ON DUPLICATE KEY UPDATE times_used = times_used + 1, last_used = %d;", Data[m_iPlayerNameIdent], iNameIndex, Data[m_iPlayerNameTimeStamp], Data[m_iPlayerNameTimeStamp])
		fm_SQLAddThreadedQuery(g_sQuery, "Handle_InsertPlayerName", QUERY_DISPOSABLE, PRIORITY_LOWEST, Data, eNameData_t)
	}

	return PLUGIN_HANDLED
}

public Handle_InsertPlayerName(iFailState, Handle:hQuery, sError[], iError, Data[], iDataLen, Float:fQueueTime, iQueryIdent)
{
	fm_DebugPrintLevel(1, "Handle_InsertPlayerName: %f", fQueueTime)

	if(fm_SQLCheckThreadedError(iFailState, hQuery, sError, iError))
	{
		return PLUGIN_HANDLED
	}

	new iPlayerNameIndex = SQL_GetInsertId(hQuery)
	if (!iPlayerNameIndex)
	{
		fm_WarningLog("iPlayerNameIndex == 0")
	}

	return PLUGIN_HANDLED
}