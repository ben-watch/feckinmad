#include "feckinmad/fm_global"
#include "feckinmad/fm_admin_access"

public plugin_init()
{
	fm_RegisterPlugin()
	register_concmd("admin_rcon","Admin_Rcon", ADMIN_ADMIN, "<command>")
}

public Admin_Rcon(id, iLevel, iCommand)
{
	if (!fm_CommandAccess(id, iLevel, false) || !fm_CommandUsage(id, iCommand, 2))
		return PLUGIN_HANDLED
	
	new sArgs[192]; read_args(sArgs, charsmax(sArgs))
	trim(sArgs)
	if (!sArgs[0])
		return PLUGIN_HANDLED

	new sAdminName[MAX_NAME_LEN]; get_user_name(id, sAdminName, charsmax(sAdminName))
	new sAdminAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAdminAuthid, charsmax(sAdminAuthid))
	new sAdminRealName[MAX_NAME_LEN]; fm_GetUserRealname(id, sAdminRealName, charsmax(sAdminRealName))

	client_print(0, print_chat, "* ADMIN #%d %s: ran command \"%s\" on the server console", fm_GetUserIdent(id), sAdminRealName, sArgs)
	log_amx("\"%s<%s>(%s)\" admin_rcon \"%s\"", sAdminName, sAdminAuthid, sAdminRealName, sArgs)

	server_cmd(sArgs)
		
	return PLUGIN_HANDLED
}
