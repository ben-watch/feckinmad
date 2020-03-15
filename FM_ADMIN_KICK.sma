#include "feckinmad/fm_global"
#include "feckinmad/fm_admin_access"
#include "feckinmad/fm_player_get"

public plugin_init() 
{
	fm_RegisterPlugin()
	register_concmd("admin_kick", "Admin_Kick", ADMIN_MEMBER, "<target> [reason]")
}

public Admin_Kick(id, iLevel, iCommand)
{
	if (!fm_CommandAccess(id, iLevel, false) || !fm_CommandUsage(id, iCommand, 2))
	{
		return PLUGIN_HANDLED
	}
		
	new sArgs[192]; read_args(sArgs, charsmax(sArgs))	
	new sTarget[32], sReason[128]
	argbreak(sArgs, sTarget, charsmax(sTarget), sReason, charsmax(sReason))
	
	new iPlayer = fm_CommandGetPlayer(id, sTarget)
	if (!iPlayer || !fm_CommandCheckPlayer(id, iPlayer, CMD_PLAYER_DENY_SELF))
	{
		return PLUGIN_HANDLED
	}

	new sPlayerName[MAX_NAME_LEN]; get_user_name(iPlayer, sPlayerName, charsmax(sPlayerName))
	new sPlayerAuthid[MAX_AUTHID_LEN]; get_user_authid(iPlayer, sPlayerAuthid, charsmax(sPlayerAuthid))
	new sAdminName[MAX_NAME_LEN]; get_user_name(id, sAdminName, charsmax(sAdminName))
	new sAdminAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAdminAuthid, charsmax(sAdminAuthid))
	new sAdminRealName[MAX_NAME_LEN]; fm_GetUserRealname(id, sAdminRealName, charsmax(sAdminRealName))

	if (sReason[0])
	{
		server_cmd("kick #%d \"%s\"", get_user_userid(iPlayer), sReason)
		client_print(0, print_chat, "* ADMIN #%d %s: kicked %s<%s> Reason: \"%s\"", fm_GetUserIdent(id), sAdminRealName, sPlayerName, sPlayerAuthid, sReason)
		console_print(id, "You have kicked \"%s\" <%s> Reason: \"%s\"", sPlayerName, sPlayerAuthid, sReason)
		log_amx("\"%s<%s>(%s)\" admin_kick \"%s<%s>\" Reason: \"%s\"", sAdminName, sAdminAuthid, sAdminRealName, sPlayerName, sPlayerAuthid, sReason)
	}	
	else
	{
		server_cmd("kick #%d", get_user_userid(iPlayer))
		client_print(0, print_chat, "* ADMIN #%d %s: kicked %s<%s>", fm_GetUserIdent(id), sAdminRealName, sPlayerName, sPlayerAuthid)
		console_print(id, "You have kicked \"%s\" <%s>", sPlayerName, sPlayerAuthid)
		log_amx("\"%s<%s>(%s)\" admin_kick \"%s<%s>\"", sAdminName, sAdminAuthid, sAdminRealName, sPlayerName, sPlayerAuthid)

	}	
	return PLUGIN_HANDLED
}
