#include "feckinmad/fm_global"
#include "feckinmad/fm_admin_access"
#include "feckinmad/fm_player_get"

new g_sTextJoinTeam[] = "jointeam"

public plugin_init() 
{
	fm_RegisterPlugin()

	register_concmd("admin_blue", "Admin_Team", ADMIN_MEMBER, "<target>")
	register_concmd("admin_red", "Admin_Team", ADMIN_MEMBER, "<target>")
	register_concmd("admin_yellow", "Admin_Team", ADMIN_MEMBER, "<target>")
	register_concmd("admin_green", "Admin_Team", ADMIN_MEMBER, "<target>")
	register_concmd("admin_spectate", "Admin_Team", ADMIN_MEMBER, "<target>")
}

public Admin_Team(id, iLevel, iCommand)
{
	if (!fm_CommandAccess(id, iLevel, false) || !fm_CommandUsage(id, iCommand, 2))
		return PLUGIN_HANDLED
		
	new sArgs[MAX_NAME_LEN]; read_args(sArgs, charsmax(sArgs))
	new iPlayer = fm_CommandGetPlayer(id, sArgs)
	if (!iPlayer || !fm_CommandCheckPlayer(id, iPlayer, CMD_PLAYER_ONLY_ALIVE | CMD_PLAYER_DENY_SELF))
		return PLUGIN_HANDLED
	
	new sCommand[32]; read_argv(0, sCommand, charsmax(sCommand))
	switch(sCommand[6])
	{
		case 'b': engclient_cmd(iPlayer, g_sTextJoinTeam, "1")
		case 'r': engclient_cmd(iPlayer, g_sTextJoinTeam, "2")
		case 'y': engclient_cmd(iPlayer, g_sTextJoinTeam, "3")
		case 'g': engclient_cmd(iPlayer, g_sTextJoinTeam, "4")
		case 's': engclient_cmd(iPlayer, "spectate")

	}

	new sPlayerName[MAX_NAME_LEN]; get_user_name(iPlayer, sPlayerName, charsmax(sPlayerName))
	new sPlayerAuthid[MAX_AUTHID_LEN]; get_user_authid(iPlayer, sPlayerAuthid, charsmax(sPlayerAuthid))
	new sAdminRealName[MAX_NAME_LEN]; fm_GetUserRealname(id, sAdminRealName, charsmax(sAdminRealName))
	new sAdminName[MAX_NAME_LEN]; get_user_name(id, sAdminName, charsmax(sAdminName))
	new sAdminAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAdminAuthid, charsmax(sAdminAuthid))
				
	client_print(0, print_chat, "* ADMIN #%d %s: switched \"%s\" to %s", fm_GetUserIdent(id), sAdminRealName, sPlayerName, sCommand[6])
	console_print(id, "You switched \"%s\" <%s> to %s", sPlayerName, sPlayerAuthid, sCommand[6])
	log_amx("\"%s<%s>(%s)\" %s \"%s<%s>\"", sAdminName, sAdminAuthid, sAdminRealName, sCommand, sPlayerName, sPlayerAuthid)

	return PLUGIN_HANDLED
}
