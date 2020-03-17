#include "feckinmad/fm_global"
#include "feckinmad/fm_admin_access"

public plugin_init()
{
	fm_RegisterPlugin()
	register_concmd("admin_publicchat","Admin_PublicChat", ADMIN_MEMBER, "<message>")
}

public Admin_PublicChat(id, iLevel, iCommand) 
{
	if (!fm_CommandAccess(id, iLevel, false) || !fm_CommandUsage(id, iCommand, 2))
		return PLUGIN_HANDLED
	
	new sArgs[192]; read_args(sArgs, charsmax(sArgs))
	remove_quotes(sArgs) // Remove the quotes associated with "messagemode" binds
	trim(sArgs)

	if (!sArgs[0]) // Avoid printing blank lines
		return PLUGIN_HANDLED  

	// Replace % characters with an actual % to avoid formatting errors
	replace_all(sArgs, charsmax(sArgs), "%", "%%%%")

	new sAdminName[MAX_NAME_LEN]; get_user_name(id, sAdminName, charsmax(sAdminName))
	new sAdminAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAdminAuthid, charsmax(sAdminAuthid))
	new sAdminRealName[MAX_NAME_LEN]; fm_GetUserRealname(id, sAdminRealName, charsmax(sAdminRealName))

	new sMessage[128]; formatex(sMessage, charsmax(sMessage), "* ADMIN #%d %s: %s", fm_GetUserIdent(id), sAdminRealName, sArgs)
	client_print(0, print_chat, sMessage)

	log_amx("\"%s<%s>(%s)\" admin_publicchat \"%s\"", sAdminName, sAdminAuthid, sAdminRealName, sArgs)

	return PLUGIN_HANDLED
}