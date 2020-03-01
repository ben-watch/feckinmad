#include "feckinmad/fm_global"
#include "feckinmad/fm_admin_access"
#include "feckinmad/fm_player_get"

#include <fakemeta>

new g_sTextEnabled[] = "enabled"
new g_sTextDisabled[] = "disabled"
	
public plugin_init() 
{
	fm_RegisterPlugin()
	register_concmd("admin_godmode", "Admin_Godmode", ADMIN_HIGHER, "<target>")
}

public Admin_Godmode(id, iLevel, iCommand)
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

	new iTakeDamage = pev(iPlayer, pev_takedamage) 
	set_pev(iPlayer, pev_takedamage, iTakeDamage != DAMAGE_NO ? DAMAGE_NO : DAMAGE_AIM)

	new sPlayerName[MAX_NAME_LEN]; get_user_name(iPlayer, sPlayerName, charsmax(sPlayerName))
	new sPlayerAuthid[MAX_AUTHID_LEN]; get_user_authid(iPlayer, sPlayerAuthid, charsmax(sPlayerAuthid))
	new sAdminName[MAX_NAME_LEN]; get_user_name(id, sAdminName, charsmax(sAdminName))
	new sAdminAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAdminAuthid, charsmax(sAdminAuthid))
	new sAdminRealName[MAX_NAME_LEN]; fm_GetUserRealname(id, sAdminRealName, charsmax(sAdminRealName))

	client_print(0, print_chat, "* ADMIN #%d %s: %s godmode on %s<%s>", fm_GetUserIdent(id), sAdminRealName, iTakeDamage != DAMAGE_NO ? g_sTextEnabled : g_sTextDisabled, sPlayerName, sPlayerAuthid)
	console_print(id, "You have %s godmode on \"%s\" <%s>", iTakeDamage != DAMAGE_NO ? g_sTextEnabled : g_sTextDisabled, sPlayerName, sPlayerAuthid)
	log_amx("\"%s<%s>(%s)\" admin_godmode \"%s<%s>\" %s", sAdminName, sAdminAuthid, sAdminRealName, sPlayerName, sPlayerAuthid, iTakeDamage != DAMAGE_NO ? g_sTextEnabled : g_sTextDisabled)

	return PLUGIN_HANDLED
}
