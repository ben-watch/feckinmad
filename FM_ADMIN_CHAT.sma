#include "feckinmad/fm_global"
#include "feckinmad/fm_admin_access"

new g_iMaxPlayers

public plugin_init()
{
	fm_RegisterPlugin()

	register_concmd("admin_chat", "Admin_Chat", ADMIN_HIGHER, "<message>")
	g_iMaxPlayers = get_maxplayers()
}

public Admin_Chat(id, iLevel, iCommand) 
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

	new sMessage[MAX_CHAT_LEN]
	if (equali(sAdminName, sAdminRealName))	
		formatex(sMessage, charsmax(sMessage), "(ADMIN) #%d %s: %s", fm_GetUserIdent(id), sAdminName, sArgs)
	else
		formatex(sMessage, charsmax(sMessage), "(ADMIN) #%d %s (%s): %s", fm_GetUserIdent(id), sAdminName, sAdminRealName, sArgs)

	for (new i = 1; i <= g_iMaxPlayers; i++)
		if (is_user_connected(i) && (fm_GetUserAccess(i) & iLevel)) // Display the message to players that have access to this command
			client_print(i, print_chat, sMessage)
	
	log_amx("\"%s<%s>(%s)\" admin_chat \"%s\"", sAdminName, sAdminAuthid, sAdminRealName, sArgs)
	
	return PLUGIN_HANDLED
}