#include "feckinmad/fm_global"
#include "feckinmad/fm_admin_access"
#include "feckinmad/fm_player_get"

#include <fakemeta>

new Float:g_fPlayerNextSlap[MAX_PLAYERS + 1]

public plugin_init() 
{
	fm_RegisterPlugin()
	register_concmd("admin_slap", "Admin_Slap", ADMIN_MEMBER, "<target>")
}

public Admin_Slap(id, iLevel, iCommand)
{
	if (!fm_CommandAccess(id, iLevel, false) || !fm_CommandUsage(id, iCommand, 2))
	{
		return PLUGIN_HANDLED
	}
		
	new sArgs[MAX_NAME_LEN]; read_args(sArgs, charsmax(sArgs))
	new iPlayer = fm_CommandGetPlayer(id, sArgs)
	if (!iPlayer || !fm_CommandCheckPlayer(id, iPlayer, CMD_PLAYER_ONLY_ALIVE | CMD_PLAYER_DENY_SELF))
		return PLUGIN_HANDLED

	new Float:fGameTime = get_gametime()
	if(g_fPlayerNextSlap[id] > fGameTime)
	{
		console_print(id, "You cannot slap again so soon")
		return PLUGIN_HANDLED
	}

	new Float:fVector[3]
	fVector[0] = random_float(-750.0, 750.0)
	fVector[1] = random_float(-750.0, 750.0)

	if (pev(iPlayer, pev_flags) & FL_ONGROUND)
	{
		fVector[2] = 300.0	
	}

	set_pev(iPlayer, pev_velocity, fVector)
	g_fPlayerNextSlap[id] = fGameTime + 1.0

	new sPlayerName[MAX_NAME_LEN]; get_user_name(iPlayer, sPlayerName, charsmax(sPlayerName))
	new sPlayerAuthid[MAX_AUTHID_LEN]; get_user_authid(iPlayer, sPlayerAuthid, charsmax(sPlayerAuthid))
	new sAdminName[MAX_NAME_LEN]; get_user_name(id, sAdminName, charsmax(sAdminName))
	new sAdminAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAdminAuthid, charsmax(sAdminAuthid))
	new sAdminRealName[MAX_NAME_LEN]; fm_GetUserRealname(id, sAdminRealName, charsmax(sAdminRealName))

	client_print(0, print_chat, "* ADMIN #%d %s: slapped %s<%s>", fm_GetUserIdent(id), sAdminRealName, sPlayerName, sPlayerAuthid)
	console_print(id, "You have slapped \"%s\" <%s>", sPlayerName, sPlayerAuthid)
	log_amx("\"%s<%s>(%s)\" admin_slap \"%s<%s>\"", sAdminName, sAdminAuthid, sAdminRealName, sPlayerName, sPlayerAuthid)
	
	return PLUGIN_HANDLED
}
