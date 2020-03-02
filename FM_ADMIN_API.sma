#include "feckinmad/fm_global"
#include "feckinmad/fm_admin_api"

new Array:g_aAdminList, g_iAdminCount, g_iForward
new g_sAdminUpdatedForward[] = "fm_AdminInfoUpdated"

public plugin_init() 
{
	fm_RegisterPlugin()

	g_aAdminList = ArrayCreate(eAdmin_t)

	g_iForward = CreateMultiForward(g_sAdminUpdatedForward, ET_IGNORE)
	if (g_iForward < 0)
	{
		fm_WarningLog(FM_FORWARD_WARNING, g_sAdminUpdatedForward)
	}
}

public plugin_end()
{
	if (g_aAdminList != Invalid_Array)
	{
		ArrayDestroy(g_aAdminList)
	}
	
	if (g_iForward > 0)
	{
		DestroyForward(g_iForward)
	}

}

public plugin_natives()
{
	register_native("fm_AddAdminInfo", "Native_AddAdminInfo")
	register_native("fm_ClearAdminInfo", "Native_ClearAdminInfo")
	register_native("fm_InfoAdminUpdated", "Native_InfoAdminUpdated")

	register_native("fm_GetAdminInfoByIndex", "Native_GetAdminInfoByIndex")
	register_native("fm_GetAdminInfoByIdent", "Native_GetAdminInfoByIdent") 
	register_native("fm_GetAdminCount", "Native_GetAdminCount") // Returns the number of admins in the array

	register_library(g_sAdminAPILibName)
}

// A native called by plugins to let other plugins know that the admin information has been updated and to act on it
public Native_InfoAdminUpdated(iPlugin, iParams)
{
	if (g_aAdminList != Invalid_Array && g_iForward > 0)
	{
		new iReturn; ExecuteForward(g_iForward, iReturn)
	}
}

// Clears all admin entries
public Native_ClearAdminInfo(iPlugin, iParams)
{
	if (g_aAdminList != Invalid_Array)
	{
		ArrayClear(g_aAdminList)
		g_iAdminCount = 0
	}
}

public Native_GetAdminCount(iPlugin, iParams)
{
	return g_iAdminCount
}

public Native_GetAdminInfoByIndex(iPlugin, iParams)
{
	if (g_aAdminList != Invalid_Array)
	{	
		new iIndex = get_param(1)

		if (iIndex < 0 || iIndex >= g_iAdminCount)
		{
			log_error(AMX_ERR_NATIVE, "Invalid admin index (%d)", iIndex)
			return 0
		}

		new Buffer[eAdmin_t]; ArrayGetArray(g_aAdminList, iIndex, Buffer)
		set_array(2, Buffer, eAdmin_t)
		return 1
	}
	return 0	
}

public Native_GetAdminInfoByIdent(iPlugin, iParams)
{
	new Buffer[eAdmin_t]

	if (g_aAdminList != Invalid_Array)
	{
		new iIdent = get_param(1)

		if (iIdent == -1)
		{
			copy(Buffer[m_sAdminName], MAX_NAME_LEN - 1, "RCON")
		}
		else
		{
			for (new i = 0; i < g_iAdminCount; i++)
			{	
				ArrayGetArray(g_aAdminList, i, Buffer)
				if(Buffer[m_iAdminIdent] == iIdent) 
				{
					set_array(2, Buffer, eAdmin_t)
					return i
				}
			}
		}
	}

	// Zero fill to prevent possible bugs
	arrayset(Buffer, 0, eAdmin_t)
	set_array(2, Buffer, eAdmin_t)

	return -1
}

public Native_AddAdminInfo(iPlugin, iParams)
{
	if (g_aAdminList != Invalid_Array)
	{
		new Buffer[eAdmin_t]; get_array(1, Buffer, eAdmin_t)
		fm_DebugPrintLevel(2, "Adding Admin - Ident: %d Active: %d Authid: \"%s\" Access: %d Name: \"%s\"", Buffer[m_iAdminIdent], Buffer[m_iAdminActive], Buffer[m_sAdminAuthid], Buffer[m_iAdminAccess], Buffer[m_sAdminName])	

		ArrayPushArray(g_aAdminList, Buffer)
		g_iAdminCount++
	}

	return 1
}
