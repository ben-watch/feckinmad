/*
DESCRIPTION
-Reads admin users from a config file, instead of SQL

NOTES
-An alternative to the FM_ADMIN_SQL / FM_ADMIN_CACHE for servers where the SQL solution is too heavy, or there is a desire to be managed locally.

COMMANDS
-"admin_reloadadmins" - Allows a admin to manually reload the admin file mid-game

AUTHOR:
-watch

DATE:
-2006 - 2010
*/

#include "feckinmad/fm_global"
#include "feckinmad/fm_admin_api"
#include "feckinmad/fm_admin_access" // for fm_CommandAccess(...)

new const g_sAdminFile[] = "fm_admins.ini"

new const g_sTextFileSuccess[] = "Loaded %d admins from \"%s\""
new const g_sTextFileFailed[] = "Failed to load admins from \"%s\""

public plugin_init()
{
	fm_RegisterPlugin()
	register_concmd("admin_reloadadmins", "Admin_ReloadAdmins", ADMIN_HIGHER, "- Reloads admins from the admin config file")
	fm_ReadAdminsFromFile()
}

public Admin_ReloadAdmins(id, iLevel, iCommand)
{
	if (!fm_CommandAccess(id, iLevel, true))
	{
		return PLUGIN_HANDLED
	}

	new iAdminCount = fm_ReadAdminsFromFile()	
	console_print(id, iAdminCount == -1 ? g_sTextFileFailed: g_sTextFileSuccess, iAdminCount, g_sAdminFile)

	new sAdminName[MAX_NAME_LEN]; get_user_name(id, sAdminName, charsmax(sAdminName))
	new sAdminAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAdminAuthid, charsmax(sAdminAuthid))
	new sAdminRealName[MAX_NAME_LEN]; fm_GetUserRealname(id, sAdminRealName, charsmax(sAdminRealName))

	log_amx("\"%s<%s>(%s)\" admin_reloadadmins", sAdminName, sAdminAuthid, sAdminRealName)
	
	return PLUGIN_HANDLED
}

fm_ReadAdminsFromFile()
{
	new sFile[128]; fm_BuildAMXFilePath(g_sAdminFile, sFile, charsmax(sFile), "amxx_configsdir")
	new iFileHandle = fopen(sFile, "rt")
	if (!iFileHandle)
	{	
		fm_WarningLog(FM_FOPEN_WARNING, sFile)
		return -1
	}

	// ------------------------------------------------------------------------------------------------------------------------------
	// Run this function in FM_ADMIN_API.amxx to clear existing admin info stored 
	// ------------------------------------------------------------------------------------------------------------------------------
	fm_ClearAdminInfo()

	new sData[128], sAdminIdent[16], sAdminActive[2], sAdminAccess[16]
	new Buffer[eAdmin_t], iAdminCount
	while (!feof(iFileHandle))
	{
		fgets(iFileHandle, sData, charsmax(sData))
		trim(sData)		

		if(!sData[0] || sData[0] == ';' || sData[0] == '#' || equal(sData, "//", 2)) 
			continue
	
		parse(sData, sAdminIdent, charsmax(sAdminIdent), sAdminActive, charsmax(sAdminActive), Buffer[m_sAdminAuthid], MAX_AUTHID_LEN - 1, sAdminAccess, charsmax(sAdminAccess), Buffer[m_sAdminName], MAX_NAME_LEN - 1,Buffer[m_sAdminPassword], 31)
		Buffer[m_iAdminIdent] = str_to_num(sAdminIdent)
		Buffer[m_iAdminActive] = str_to_num(sAdminActive)
		Buffer[m_iAdminAccess] = str_to_num(sAdminAccess) 

		// ------------------------------------------------------------------------------------------------------------------------------
		// Add admin to the dynamic array in FM_ADMIN_API.amxx
		// ------------------------------------------------------------------------------------------------------------------------------
		fm_AddAdminInfo(Buffer) 
		iAdminCount++
	}
	
	fclose(iFileHandle)

	// ------------------------------------------------------------------------------------------------------------------------------
	// Tell FM_ADMIN_API.amxx that we have updated admin information so it can run a forward to tell other plugins
	// ------------------------------------------------------------------------------------------------------------------------------
	// FM_ADMIN_CACHE.amxx will use this to write the updated list to the cache file
	// FM_ADMIN_ACCESS.amxx will refresh access for players connected
	// ------------------------------------------------------------------------------------------------------------------------------
	fm_InfoAdminUpdated()

	log_amx(g_sTextFileSuccess, iAdminCount, g_sAdminFile)

	return iAdminCount
}

