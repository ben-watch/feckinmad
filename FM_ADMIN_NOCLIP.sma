#include "feckinmad/fm_global"
#include "feckinmad/fm_admin_access"
#include "feckinmad/fm_player_get"

#include <fakemeta>

new g_sTextEnabled[] = "enabled"
new g_sTextDisabled[] = "disabled"

public plugin_init() 
{
	fm_RegisterPlugin()
	register_concmd("admin_noclip", "Admin_Noclip", ADMIN_HIGHER, "<target>")
}

public Admin_Noclip(id, iLevel, iCommand)
{
	if (!fm_CommandAccess(id, iLevel, false) || !fm_CommandUsage(id, iCommand, 2))
	{
		return PLUGIN_HANDLED
	}
	
	new sArgs[MAX_NAME_LEN]; read_args(sArgs, charsmax(sArgs))
	new iPlayer = fm_CommandGetPlayer(id, sArgs)	
	if (!iPlayer || !fm_CommandCheckPlayer(id, iPlayer, CMD_PLAYER_ONLY_ALIVE))
	{
		return PLUGIN_HANDLED
	}

	new iMoveType = pev(iPlayer, pev_movetype) 
	set_pev(iPlayer, pev_movetype, iMoveType != MOVETYPE_NOCLIP ? MOVETYPE_NOCLIP : MOVETYPE_WALK)
	
	new sPlayerName[MAX_NAME_LEN]; get_user_name(iPlayer, sPlayerName, charsmax(sPlayerName))
	new sPlayerAuthid[MAX_AUTHID_LEN]; get_user_authid(iPlayer, sPlayerAuthid, charsmax(sPlayerAuthid))
	new sAdminName[MAX_NAME_LEN]; get_user_name(id, sAdminName, charsmax(sAdminName))
	new sAdminAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAdminAuthid, charsmax(sAdminAuthid))
	new sAdminRealName[MAX_NAME_LEN]; fm_GetUserRealname(id, sAdminRealName, charsmax(sAdminRealName))

	client_print(0, print_chat, "* ADMIN #%d %s: %s noclip on %s<%s>", fm_GetUserIdent(id), sAdminRealName, iMoveType != MOVETYPE_NOCLIP ? g_sTextEnabled : g_sTextDisabled, sPlayerName, sPlayerAuthid)
	console_print(id, "You have %s noclip on \"%s\" <%s>", iMoveType != MOVETYPE_NOCLIP ? g_sTextEnabled : g_sTextDisabled, sPlayerName, sPlayerAuthid)
	log_amx("\"%s<%s>(%s)\" admin_noclip \"%s<%s>\" %s", sAdminName, sAdminAuthid, sAdminRealName, sPlayerName, sPlayerAuthid, iMoveType != MOVETYPE_NOCLIP ? g_sTextEnabled : g_sTextDisabled)

	return PLUGIN_HANDLED
}
