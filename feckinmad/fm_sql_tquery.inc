#if defined _fm_sql_tquery_included
  #endinput
#endif
#define _fm_sql_tquery_included

#pragma reqlib fm_sql_tquery

#include "feckinmad/fm_sql_api"

#define QUERY_DISPOSABLE 1
#define QUERY_NOT_DISPOSABLE 0

#define MAX_QUERY_LEN 512
#define MAX_QUERY_DATA_LEN 512

enum 
{
	PRIORITY_LOWEST = 0,
	PRIORITY_LOW,
	PRIORITY_NORMAL,
	PRIORITY_HIGH,
	PRIORITY_HIGHEST
}

native fm_SQLAddThreadedQuery(const sQuery[], sForward[], iDisposable, iPriority, Data[] = "", iDataLen = 0)
native fm_SQLRemoveThreadedQuery(iIdent)

// Failstates from sqlx.inc
//#define TQUERY_CONNECT_FAILED	-2
//#define TQUERY_QUERY_FAILED	-1
//#define TQUERY_SUCCESS		0

// Create a new failstate, as the query handler is called with ExecuteForward() in the FM_TQUERY_BASE plugin if the tuple is empty
// Instead of each plugin having to check the tuple before they attempt to query the database which just adds more error checking
#define TQUERY_TUPLE_FAILED -3

// Checks whether a threaded query was completed successfully and logs unsuccessful ones
stock fm_SQLCheckThreadedError(iFailState, Handle:hQuery, sError[], iError)
{
	if (iFailState == TQUERY_SUCCESS)
		return 0

	switch(iFailState) 
	{
		case TQUERY_TUPLE_FAILED:
		{
			fm_WarningLog("Connection tuple is not valid")
			fm_WarningLog(sError) // The query is sent in the err msg 
			return 1
		}
		case TQUERY_CONNECT_FAILED: 
		{
			fm_WarningLog("Could not connect to database: (#%d) %s", iError, sError)
			//fm_SQLCheckFailLimit() No longer required since plugins are queued outside of the sqlx module with FM_SQL_TQUERY
		}
		case TQUERY_QUERY_FAILED: fm_WarningLog("Query failed: (#%d) %s", iError, sError)
	}
	
	new sQuery[512]; SQL_GetQueryString(hQuery, sQuery, charsmax(sQuery))
	fm_WarningLog(sQuery) // Log the query so it can be manually added to the database if required

	return 1
}