#include "feckinmad/fm_global"
#include "feckinmad/fm_admin_access"
#include "feckinmad/mapvote/fm_mapvote_changelevel"


public plugin_init()
{
	fm_RegisterPlugin()
	register_concmd("admin_map", "Admin_Map", ADMIN_HIGHER, "<map> - Changes to specified map")
}

public Admin_Map(id, iLevel, iCommand)
{
	if (!fm_CommandAccess(id, iLevel, true) || !fm_CommandUsage(id, iCommand, 2))
	{
		return PLUGIN_HANDLED
	}

	new sMap[MAX_MAP_LEN]; read_args(sMap, charsmax(sMap))
	trim(sMap)

	if (!fm_ChangeLevel(sMap)) 
	{
		console_print(id, "Failed to change to \"%s\"", sMap)
		return PLUGIN_HANDLED 
	}

	new sAdminRealName[MAX_NAME_LEN]; fm_GetUserRealname(id, sAdminRealName, charsmax(sAdminRealName))
	new sAdminName[MAX_NAME_LEN]; get_user_name(id, sAdminName, charsmax(sAdminName))
	new sAdminAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAdminAuthid, charsmax(sAdminAuthid))
	
	client_print(0, print_chat, "* ADMIN #%d %s: changing map to %s", fm_GetUserIdent(id), sAdminRealName, sMap)			
	console_print(id, "Changing map to \"%s\"", sMap)
	log_amx("\"%s<%s>(%s)\" admin_map \"%s\"", sAdminName, sAdminAuthid, sAdminRealName, sMap)

	return PLUGIN_HANDLED 
}
