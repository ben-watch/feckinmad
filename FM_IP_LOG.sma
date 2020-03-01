#include "feckinmad/fm"
#include "feckinmad/fm_sql_player"
#include "feckinmad/fm_sql_tquery"

#include <fakemeta>

#define MAX_ADDRESS_LEN 16
enum eAddressData_t
{
	m_sPlayerAddress[MAX_ADDRESS_LEN],
	m_iPlayerAddressIdent,
	m_iPlayerAddressTimeStamp
}

new g_sQuery[MAX_QUERY_LEN]

public fm_SQLPlayerIdent(id, iPlayerIdent)
{
	if (!is_dedicated_server()) // loopback
	{
		return PLUGIN_CONTINUE
	}

	new Data[eAddressData_t]
	get_user_ip(id, Data[m_sPlayerAddress], MAX_ADDRESS_LEN - 1, 1)
	Data[m_iPlayerAddressIdent] = iPlayerIdent
	Data[m_iPlayerAddressTimeStamp] = get_systime()
		
	formatex(g_sQuery, charsmax(g_sQuery), "SELECT address_id FROM player_address WHERE player_address = INET_ATON('%s')", Data[m_sPlayerAddress])
	fm_SQLAddThreadedQuery(g_sQuery, "Handle_SelectAddress", QUERY_DISPOSABLE, PRIORITY_LOWEST, Data, _:eAddressData_t)

	return PLUGIN_CONTINUE
}

public Handle_SelectAddress(iFailState, Handle:hQuery, sError[], iError, Data[], iDataLen, Float:fQueueTime, iQueryIdent)
{
	fm_DebugPrintLevel(1, "Handle_SelectAddress: %f", fQueueTime)

	if(fm_SQLCheckThreadedError(iFailState, hQuery, sError, iError))
	{
		return PLUGIN_HANDLED
	}

	if (!SQL_NumResults(hQuery))
	{	
		formatex(g_sQuery, charsmax(g_sQuery), "INSERT INTO player_address (player_address) VALUES (INET_ATON('%s'));", Data[m_sPlayerAddress])
		fm_SQLAddThreadedQuery(g_sQuery, "Handle_InsertAddress", QUERY_DISPOSABLE, PRIORITY_LOWEST, Data, _:eAddressData_t)	

		return PLUGIN_HANDLED
	}
	else
	{
		new iAddressIndex = SQL_ReadResult(hQuery, 0)
		formatex(g_sQuery, charsmax(g_sQuery), "INSERT INTO player_address_link (player_id, address_id, last_used, times_used) VALUES ('%d', '%d', '%d', '1') ON DUPLICATE KEY UPDATE times_used = times_used + 1, last_used = %d;", Data[m_iPlayerAddressIdent], iAddressIndex, Data[m_iPlayerAddressTimeStamp], Data[m_iPlayerAddressTimeStamp])
		fm_SQLAddThreadedQuery(g_sQuery, "Handle_InsertPlayerAddress", QUERY_DISPOSABLE, PRIORITY_LOWEST, Data, _:eAddressData_t)
	}
	return PLUGIN_HANDLED
}

public Handle_InsertAddress(iFailState, Handle:hQuery, sError[], iError, Data[], iDataLen, Float:fQueueTime, iQueryIdent)
{
	fm_DebugPrintLevel(1, "Handle_InsertAddress: %f", fQueueTime)

	if(fm_SQLCheckThreadedError(iFailState, hQuery, sError, iError))
	{
		return PLUGIN_HANDLED
	}
	
	new iAddressIndex = SQL_GetInsertId(hQuery)
	if (!iAddressIndex)
	{
		fm_WarningLog("iAddressIndex == 0")
		return PLUGIN_HANDLED
	}

	formatex(g_sQuery, charsmax(g_sQuery), "INSERT INTO player_address_link (player_id, address_id, last_used, times_used) VALUES ('%d', '%d', '%d', '1') ON DUPLICATE KEY UPDATE times_used = times_used + 1, last_used = %d;", Data[m_iPlayerAddressIdent], iAddressIndex, Data[m_iPlayerAddressTimeStamp], Data[m_iPlayerAddressTimeStamp])
	fm_SQLAddThreadedQuery(g_sQuery, "Handle_InsertPlayerAddress", QUERY_DISPOSABLE, PRIORITY_LOWEST, Data, eAddressData_t)

	return PLUGIN_HANDLED
}

public Handle_InsertPlayerAddress(iFailState, Handle:hQuery, sError[], iError, Data[], iDataLen, Float:fQueueTime, iQueryIdent)
{
	fm_DebugPrintLevel(1, "Handle_InsertPlayerAddress: %f", fQueueTime)

	if(fm_SQLCheckThreadedError(iFailState, hQuery, sError, iError))
	{
		return PLUGIN_HANDLED
	}

	new iPlayerAddressIndex = SQL_GetInsertId(hQuery)
	if (!iPlayerAddressIndex)
	{
		fm_WarningLog("iPlayerAddressIndex == 0")
		return PLUGIN_HANDLED
	}

	return PLUGIN_HANDLED
}