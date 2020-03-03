/*
DESCRIPTION
-Grant admins their access when they connect.

NOTES
-Provides natives for other plugins to access an admins "real" name, unique ident # and access level. This is used when checking if
a user can run a command, and when printing a command to all users when an an admin successfully runs it.
-Relies on a forward from FM_ADMIN_API, fm_AdminInfoUpdated()
-Provides password functionality for use in cases where a user shares their account.

COMMANDS
-"admin_refresh" - Allows a player to manually reload their access e.g. If their password failed.

AUTHOR:
-watch

DATE:
-2006 - 2010
*/

#include "feckinmad/fm_global"
#include "feckinmad/fm_admin_api"
#include "feckinmad/fm_admin_access"

new const g_sPasswordField[] = "_fm_auth_password"

new g_PlayerAdminInfo[MAX_PLAYERS + 1][eAdmin_t]
new g_iMaxPlayers

new Float:g_fPlayerNextAdminRefresh[MAX_PLAYERS + 1]

public plugin_init()
{
	fm_RegisterPlugin()
	register_concmd("admin_refresh", "Admin_Refresh")

	g_iMaxPlayers = get_maxplayers()

	copy(g_PlayerAdminInfo[0][m_sAdminName], 5, "RCON")
	g_PlayerAdminInfo[0][m_iAdminIdent] = -1
}

public Admin_Refresh(id)
{
	if (!id)
	{
		return PLUGIN_HANDLED
	}

	new Float:fGameTime = get_gametime()
	if (fGameTime < g_fPlayerNextAdminRefresh[id])
	{
		console_print(id, "Please wait another %d seconds before attempting to refresh your admin", floatround(g_fPlayerNextAdminRefresh[id] - fGameTime, floatround_ceil))	
		return PLUGIN_HANDLED
	}

	console_print(id, "Attempting to refresh your admin")
	g_fPlayerNextAdminRefresh[id] = fGameTime + 10.0
	client_authorized(id)

	return PLUGIN_HANDLED
}

public plugin_natives()
{
	register_native("fm_GetUserRealname","Native_GetRealName")
	register_native("fm_GetUserAccess","Native_GetAccess")
	register_native("fm_GetUserIdent","Native_GetIdentifier")

	register_library(g_sAdminAccessLibName)
}

public fm_AdminInfoUpdated()
{
	for (new i = 1; i <= g_iMaxPlayers; i++) 
	{
		if (is_user_connected(i) || is_user_connecting(i)) 
		{
			client_authorized(i)
		}
	}
}

public client_connect(id)
{
	arrayset(g_PlayerAdminInfo[id], 0, eAdmin_t)
}

public client_authorized(id)
{
	arrayset(g_PlayerAdminInfo[id], 0, eAdmin_t)

	new sName[MAX_NAME_LEN], sAuthid[MAX_AUTHID_LEN]
	get_user_authid(id, sAuthid, charsmax(sAuthid))
 
	new iCount = fm_GetAdminCount()
	new eBuffer[eAdmin_t], sPassword[32]

	for (new i = 0; i < iCount; i++)
	{	
		fm_GetAdminInfoByIndex(i, eBuffer)
		if(eBuffer[m_iAdminActive] && equali(sAuthid, eBuffer[m_sAdminAuthid])) 
		{
			get_user_name(id, sName, charsmax(sName))
			get_user_info(id, g_sPasswordField, sPassword, charsmax(sPassword))

			if (equal(eBuffer[m_sAdminPassword], sPassword))
			{
				fm_CopyStruc(eBuffer, g_PlayerAdminInfo[id], eAdmin_t)
				log_amx("\"%s\"<%s>(%s) authorized. Access: %d Ident: %d", sName, g_PlayerAdminInfo[id][m_sAdminAuthid], g_PlayerAdminInfo[id][m_sAdminName], g_PlayerAdminInfo[id][m_iAdminAccess], g_PlayerAdminInfo[id][m_iAdminIdent])			
				console_print(id, "You authorized using <%s> with access level %d", g_PlayerAdminInfo[id][m_sAdminAuthid], g_PlayerAdminInfo[id][m_iAdminAccess])		
			}
			else if (!sPassword[0])
			{
				console_print(id, "You must specify your password to authorize. Check the forum for more information")		
				log_amx("\"%s\"<%s>(%s) failed to authorize (No password specified). Access: %d Ident: %d", sName, eBuffer[m_sAdminAuthid], eBuffer[m_sAdminName], eBuffer[m_iAdminAccess], eBuffer[m_iAdminIdent])				
			}
			else
			{
				console_print(id, "Your authorization password was incorrect. Contact a senior admin for help")			
				log_amx("\"%s\"<%s>(%s) failed to authorize (Incorrect password). Access: %d Ident: %d", sName, eBuffer[m_sAdminAuthid], eBuffer[m_sAdminName], eBuffer[m_iAdminAccess], eBuffer[m_iAdminIdent])					
			}
			break
		}
	}	
}

public client_disconnect(id)
{
	if (g_PlayerAdminInfo[id][m_iAdminAccess] > 0)
	{
		new sName[MAX_NAME_LEN]; get_user_name(id, sName, charsmax(sName))
		log_amx("\"%s\"<%s>(%s) disconnected. Access: %d Ident: %d", sName, g_PlayerAdminInfo[id][m_sAdminAuthid], g_PlayerAdminInfo[id][m_sAdminName], g_PlayerAdminInfo[id][m_iAdminAccess], g_PlayerAdminInfo[id][m_iAdminIdent])	
	}
	arrayset(g_PlayerAdminInfo[id], 0, eAdmin_t)
}


public Native_GetRealName()
{		
	new id = get_param(1)
	
	if (id < 0 || id > g_iMaxPlayers)
	{
		log_error(AMX_ERR_NATIVE, "Player out of range (%d)", id)
		return 0
	}

	if (g_PlayerAdminInfo[id][m_sAdminName][0])
		set_string(2, g_PlayerAdminInfo[id][m_sAdminName], get_param(3))
	else 
		set_string(2, "Player", get_param(3))

	return 1
}

public Native_GetAccess()
{	
	new id = get_param(1)
	
	if (id < 1 || id > g_iMaxPlayers)
	{
		log_error(AMX_ERR_NATIVE, "Player out of range (%d)", id)
		return 0
	}
	return g_PlayerAdminInfo[id][m_iAdminAccess]
}

public Native_GetIdentifier()
{	
	new id = get_param(1)

	if (id < 0 || id > g_iMaxPlayers)
	{
		log_error(AMX_ERR_NATIVE, "Player out of range (%d)", id)
		return 0
	}
	return g_PlayerAdminInfo[id][m_iAdminIdent]
}