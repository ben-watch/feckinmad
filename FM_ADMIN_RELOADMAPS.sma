#include "feckinmad/fm_global"
#include "feckinmad/fm_admin_access"
#include "feckinmad/fm_mapfile_api"

public plugin_init() 
{
	fm_RegisterPlugin()
	register_concmd("admin_reloadmaps", "Admin_ReloadMaps", ADMIN_HIGHER, "- Reloads map list")
}

public Admin_ReloadMaps(id, iLevel, iCommand)
{
	if (!fm_CommandAccess(id, iLevel, true))
	{
		return PLUGIN_HANDLED
	}

	new iMapCount = fm_ReloadMapList()

	new sAdminRealName[MAX_NAME_LEN]; fm_GetUserRealname(id, sAdminRealName, charsmax(sAdminRealName))
	new sAdminName[MAX_NAME_LEN]; get_user_name(id, sAdminName, charsmax(sAdminName))
	new sAdminAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAdminAuthid, charsmax(sAdminAuthid))
				
	log_amx("\"%s<%s>(%s)\" admin_reloadmaps", sAdminName, sAdminAuthid, sAdminRealName)
	console_print(id, "Loaded %d maps from file", iMapCount)

	return PLUGIN_HANDLED 
}
