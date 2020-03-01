#if defined _fm_sql_included
  #endinput
#endif
#define _fm_sql_included

#include <sqlx>
#include "feckinmad/fm_global" // fm_WarningLog()

#pragma reqlib fm_sql_api

stock const g_sSQLModule[] = "fm_sql_api"

native fm_SQLCheckFailLimit()
native Handle:fm_SQLGetHandle()

stock Handle:fm_BlockingQuery(const sQuery[])
{
	new Handle:SqlTuple = fm_SQLGetHandle()
	if (SqlTuple == Empty_Handle)
		return Empty_Handle

	new sError[256], iError
	new Handle:SqlConnection = SQL_Connect(SqlTuple, iError, sError, charsmax(sError))
	if(SqlConnection == Empty_Handle)
	{
		fm_WarningLog("Could not connect to database: (#%d) %s", iError, sError)
		fm_SQLCheckFailLimit()
		return Empty_Handle
	}

	new Handle:hQuery = SQL_PrepareQuery(SqlConnection, sQuery)
	if(!SQL_Execute(hQuery))
	{
		iError = SQL_QueryError(hQuery, sError, charsmax(sError))
		fm_WarningLog("Query failed: (#%d) %s.", iError, sError)
	
		SQL_FreeHandle(hQuery)
		SQL_FreeHandle(SqlConnection)	
		return Empty_Handle
	}
	SQL_FreeHandle(SqlConnection)
	return hQuery
}

stock fm_SQLMakeStringSafe(sString[], iLen)
{
	replace_all(sString, iLen, "\\", "\\\\")
	replace_all(sString, iLen, "'", "\\'")
	sString[iLen] = 0
}
