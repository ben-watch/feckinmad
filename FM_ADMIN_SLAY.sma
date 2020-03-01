#include "feckinmad/fm_global"
#include "feckinmad/fm_admin_access"
#include "feckinmad/fm_player_get"

#include <fakemeta>

public plugin_init() 
{
	fm_RegisterPlugin()
	register_concmd("admin_slay", "Admin_Slay", ADMIN_MEMBER, "<target>")
}

public Admin_Slay(id, iLevel, iCommand)
{
	if (!fm_CommandAccess(id, iLevel, false) || !fm_CommandUsage(id, iCommand, 2))
	{
		return PLUGIN_HANDLED
	}
		
	new sArgs[MAX_NAME_LEN]; read_args(sArgs, charsmax(sArgs))
	new iPlayer = fm_CommandGetPlayer(id, sArgs)
	if (!iPlayer || !fm_CommandCheckPlayer(id, iPlayer, CMD_PLAYER_ONLY_ALIVE | CMD_PLAYER_DENY_SELF))
	{
		return PLUGIN_HANDLED
	}

	dllfunc(DLLFunc_ClientKill, iPlayer)

	// Create the red dots
	new Float:fOrigin[3]; pev(iPlayer, pev_origin, fOrigin)
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(10)
	write_coord(floatround(fOrigin[0]))
	write_coord(floatround(fOrigin[1]))
	write_coord(floatround(fOrigin[2]))
	message_end()
	
	fm_PlaySound(0, "ambience/thunder_clap.wav")

	new sPlayerName[MAX_NAME_LEN]; get_user_name(iPlayer, sPlayerName, charsmax(sPlayerName))
	new sPlayerAuthid[MAX_AUTHID_LEN]; get_user_authid(iPlayer, sPlayerAuthid, charsmax(sPlayerAuthid))
	new sAdminName[MAX_NAME_LEN]; get_user_name(id, sAdminName, charsmax(sAdminName))
	new sAdminAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAdminAuthid, charsmax(sAdminAuthid))
	new sAdminRealName[MAX_NAME_LEN]; fm_GetUserRealname(id, sAdminRealName, charsmax(sAdminRealName))

	client_print(0, print_chat, "* ADMIN #%d %s: slayed %s<%s>", fm_GetUserIdent(id), sAdminRealName, sPlayerName, sPlayerAuthid)
	console_print(id, "You have slayed \"%s\" <%s>", sPlayerName, sPlayerAuthid)
	log_amx("\"%s<%s>(%s)\" admin_slay \"%s<%s>\"", sAdminName, sAdminAuthid, sAdminRealName, sPlayerName, sPlayerAuthid)
	
	return PLUGIN_HANDLED
}
