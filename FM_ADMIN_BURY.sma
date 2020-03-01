#include "feckinmad/fm_global"
#include "feckinmad/fm_admin_access"
#include "feckinmad/fm_player_get"

#include <fakemeta>

new g_iUnBuryCommand

public plugin_init() 
{
	fm_RegisterPlugin()
	register_concmd("admin_bury", "Admin_Bury", 0, "<target>")
	g_iUnBuryCommand = register_concmd("admin_unbury", "Admin_Bury", 0, "<target>")
}

public Admin_Bury(id, iLevel, iCommand)
{
	if (!fm_CommandAccess(id, iLevel, false) || !fm_CommandUsage(id, iCommand, 2))
		return PLUGIN_HANDLED

	new sArgs[MAX_NAME_LEN]; read_args(sArgs, charsmax(sArgs))
	new iPlayer = fm_CommandGetPlayer(id, sArgs)
	if (!iPlayer || !fm_CommandCheckPlayer(id, iPlayer, CMD_PLAYER_ONLY_ALIVE | CMD_PLAYER_DENY_SELF))
		return PLUGIN_HANDLED
	
	new Float:fOrigin[3]; pev(iPlayer, pev_origin, fOrigin)	
	if (iCommand == g_iUnBuryCommand)
		fOrigin[2] += 30
	else
		fOrigin[2] -= 30

	engfunc(EngFunc_SetOrigin, iPlayer, fOrigin)

	new sPlayerName[MAX_NAME_LEN]; get_user_name(iPlayer, sPlayerName, charsmax(sPlayerName))
	new sPlayerAuthid[MAX_AUTHID_LEN]; get_user_authid(iPlayer, sPlayerAuthid, charsmax(sPlayerAuthid))
	new sAdminName[MAX_NAME_LEN]; get_user_name(id, sAdminName, charsmax(sAdminName))
	new sAdminAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAdminAuthid, charsmax(sAdminAuthid))
	new sAdminRealName[MAX_NAME_LEN]; fm_GetUserRealname(id, sAdminRealName, charsmax(sAdminRealName))

	client_print(0, print_chat, "* ADMIN #%d %s: %s %s<%s>", fm_GetUserIdent(id), sAdminRealName, iCommand == g_iUnBuryCommand ? "unburied" : "buried", sPlayerName, sPlayerAuthid)
	console_print(id, "You have %s \"%s\" <%s>", iCommand == g_iUnBuryCommand ? "unburied" : "buried", sPlayerName, sPlayerAuthid)
	log_amx("\"%s<%s>(%s)\" admin_%s \"%s<%s>\"", sAdminName, sAdminAuthid, sAdminRealName, iCommand == g_iUnBuryCommand ? "unbury" : "bury",sPlayerName, sPlayerAuthid)
	
	return PLUGIN_HANDLED
}


