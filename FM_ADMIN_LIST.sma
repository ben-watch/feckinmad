#include "feckinmad/fm_global"
#include "feckinmad/fm_admin_access"

new g_iMaxPlayers

public plugin_init() 
{ 
	fm_RegisterPlugin()

	register_concmd("admin_list", "Admin_List", ADMIN_LIST)
	g_iMaxPlayers = get_maxplayers()
}

public Admin_List(id, iLevel, iCommand)
{
	if (!fm_CommandAccess(id, iLevel, true))
	{
		return PLUGIN_HANDLED
	}

	new sAuthId[MAX_AUTHID_LEN], sName[MAX_NAME_LEN], sRealName[MAX_NAME_LEN], iCount
	
	console_print(id, "\nAdmins:")
	for (new i = 1; i <= g_iMaxPlayers; i++) 
	{
		if (is_user_connected(i) && fm_GetUserAccess(i) > 0)
		{	
			get_user_authid(i, sAuthId, charsmax(sAuthId))
			get_user_name(i, sName, charsmax(sName))
			fm_GetUserRealname(i, sRealName, charsmax(sRealName))

			console_print(id, "\t\t#%d %s (%s) <%s>", fm_GetUserIdent(i), sName, sRealName, sAuthId)
			iCount++
		}
	}
	console_print(id, "Total: %d\n", iCount)
	
	return PLUGIN_HANDLED
}
