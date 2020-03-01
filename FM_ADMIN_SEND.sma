#include "feckinmad/fm_global"
#include "feckinmad/fm_admin_access"
#include "feckinmad/fm_player_get"
#include "feckinmad/fm_stuck"

#include <fakemeta>

public plugin_init() 
{
	fm_RegisterPlugin()
	
	register_concmd("admin_userorigin","Admin_UserOrigin", ADMIN_MEMBER, "[target]")
	register_concmd("admin_teleport","Admin_Teleport", ADMIN_HIGHER, "<target> <x> <y> <z>")
	register_concmd("admin_send","Admin_Send", ADMIN_HIGHER, "<target> <target>")
	register_concmd("admin_viewsend","Admin_ViewSend", ADMIN_HIGHER, "<target>")
}

public Admin_UserOrigin(id, iLevel, iCommand)
{
	if (!fm_CommandAccess(id, iLevel, false))
		return PLUGIN_HANDLED

	new sArgs[64]; read_args(sArgs, charsmax(sArgs))	
	new iPlayer

	trim(sArgs)
	if (!sArgs[0]) 
	{
		iPlayer = id
	}
	else
	{
		iPlayer = fm_CommandGetPlayer(id, sArgs)
		if (!iPlayer)
			return PLUGIN_HANDLED
	}
	
	new Float:fOrigin[3]; pev(iPlayer, pev_origin, fOrigin)
	console_print(id, "Origin: %0.2f %0.2f %0.2f", fOrigin[0], fOrigin[1], fOrigin[2])
	
	return PLUGIN_HANDLED
}

public Admin_Send(id, iLevel, iCommand)
{
	if (!fm_CommandAccess(id, iLevel, false) || !fm_CommandUsage(id, iCommand, 3))
		return PLUGIN_HANDLED

	new sArg1[64]; read_argv(1, sArg1, charsmax(sArg1))
	new sArg2[64]; read_argv(2, sArg2, charsmax(sArg2))
		
	new iPlayer = fm_CommandGetPlayer(id, sArg1)
	if (!iPlayer || !fm_CommandCheckPlayer(id, iPlayer, CMD_PLAYER_ONLY_ALIVE))
		return PLUGIN_HANDLED
	
	new iTarget = fm_CommandGetPlayer(id, sArg2)
	if (!iTarget || !fm_CommandCheckPlayer(id, iTarget, CMD_PLAYER_ONLY_ALIVE))
		return PLUGIN_HANDLED
	
	if (iPlayer == iTarget)
	{
		console_print(id, "You cannot teleport a player to themself")
		return PLUGIN_HANDLED
	}

	new Float:fOrigin[3]; pev(iTarget, pev_origin, fOrigin)
	fOrigin[2] += 96 // Player height

	set_pev(iPlayer, pev_origin, fOrigin)
	fm_UnstickPlayer(iPlayer)
		
	new sPlayerName[MAX_NAME_LEN]; get_user_name(iPlayer, sPlayerName, charsmax(sPlayerName))
	new sTargetName[MAX_NAME_LEN]; get_user_name(iTarget, sTargetName, charsmax(sTargetName))

	new sPlayerAuthid[MAX_AUTHID_LEN]; get_user_authid(iPlayer, sPlayerAuthid, charsmax(sPlayerAuthid))
	new sTargetAuthid[MAX_AUTHID_LEN]; get_user_authid(iTarget, sTargetAuthid, charsmax(sTargetAuthid))

	new sAdminName[MAX_NAME_LEN]; get_user_name(id, sAdminName, charsmax(sAdminName))
	new sAdminAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAdminAuthid, charsmax(sAdminAuthid))
	new sAdminRealName[MAX_NAME_LEN]; fm_GetUserRealname(id, sAdminRealName, charsmax(sAdminRealName))

	client_print(0, print_chat, "* ADMIN #%d %s: teleported %s<%s> to %s<%s>", fm_GetUserIdent(id), sAdminRealName, sPlayerName, sPlayerAuthid, sTargetName, sTargetAuthid)
	console_print(id, "You have teleported %s<%s> to %s<%s>", sPlayerName, sPlayerAuthid, sTargetName, sTargetAuthid)
	log_amx("\"%s<%s>(%s)\" admin_send \"%s<%s>\" to \"%s<%s>\"", sAdminName, sAdminAuthid, sAdminRealName, sPlayerName, sPlayerAuthid, sTargetName, sTargetAuthid)

	return PLUGIN_HANDLED
}

public Admin_ViewSend(id, iLevel, iCommand)
{
	if (!fm_CommandAccess(id, iLevel, false) || !fm_CommandUsage(id, iCommand, 2))
		return PLUGIN_HANDLED
	
	new sArgs[64]; read_args(sArgs, charsmax(sArgs))
	new iPlayer = fm_CommandGetPlayer(id, sArgs)
	if (!iPlayer || !fm_CommandCheckPlayer(id, iPlayer, CMD_PLAYER_ONLY_ALIVE))
		return PLUGIN_HANDLED
	
	new Float:fPlayerOrigin[3]; pev(id, pev_origin, fPlayerOrigin)
	new Float:fPlayerViewOff[3]; pev(id, pev_view_ofs, fPlayerViewOff)
	new Float:fAngles[3]; pev(id, pev_v_angle, fAngles)
	new Float:fEnd[3]

	engfunc(EngFunc_MakeVectors, fAngles)
	global_get(glb_v_forward, fEnd) 

	for (new i = 0; i < 3; i++)
	{
		fPlayerOrigin[i] += fPlayerViewOff[i]
		fEnd[i] = fPlayerOrigin[i] + (fEnd[i] * 4096.0) // Scale up normalised vector
	}
	
	// Trace a line from the players view	
	engfunc(EngFunc_TraceLine, fPlayerOrigin, fEnd, IGNORE_MONSTERS, id, 0)

	// Check we hit something
	new Float:fFraction; get_tr2(0, TR_flFraction, fFraction)
	if (fFraction == 1.0)
	{
		console_print(id, "Unable to teleport to view origin")
		return PLUGIN_HANDLED
	}

	// Teleport the player to the origin
	new Float:fOrigin[3]; get_tr2(0, TR_vecEndPos, fOrigin)
	set_pev(iPlayer, pev_origin, fOrigin)

	fm_UnstickPlayer(iPlayer)

	new sPlayerName[MAX_NAME_LEN]; get_user_name(iPlayer, sPlayerName, charsmax(sPlayerName))
	new sPlayerAuthid[MAX_AUTHID_LEN]; get_user_authid(iPlayer, sPlayerAuthid, charsmax(sPlayerAuthid))
	new sAdminName[MAX_NAME_LEN]; get_user_name(id, sAdminName, charsmax(sAdminName))
	new sAdminAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAdminAuthid, charsmax(sAdminAuthid))
	new sAdminRealName[MAX_NAME_LEN]; fm_GetUserRealname(id, sAdminRealName, charsmax(sAdminRealName))

	client_print(0, print_chat, "* ADMIN #%d %s: teleported %s<%s> to %0.2f %0.2f %0.2f", fm_GetUserIdent(id), sAdminRealName, sPlayerName, sPlayerAuthid, fOrigin[0], fOrigin[1], fOrigin[2])
	console_print(id, "You have teleported %s<%s> to %0.2f %0.2f %0.2f", sPlayerName, sPlayerAuthid, fOrigin[0], fOrigin[1], fOrigin[2])
	log_amx("\"%s<%s>(%s)\" admin_viewsend \"%s<%s>\" to %0.2f %0.2f %0.2f", sAdminName, sAdminAuthid, sAdminRealName, sPlayerName, sPlayerAuthid, fOrigin[0], fOrigin[1], fOrigin[2])

	return PLUGIN_HANDLED
}

public Admin_Teleport(id, iLevel, iCommand)
{
	if (!fm_CommandAccess(id, iLevel, false) || !fm_CommandUsage(id, iCommand, 4))
		return PLUGIN_HANDLED

	new sArgs[192]; read_args(sArgs, charsmax(sArgs))

	new sTarget[64], X[16], Y[16], Z[16] 
	parse(sArgs, sTarget, charsmax(sTarget), X, charsmax(X), Y, charsmax(Y), Z,  charsmax(Z))
	
	new iPlayer = fm_CommandGetPlayer(id, sTarget)
	if (!iPlayer || !fm_CommandCheckPlayer(id, iPlayer, CMD_PLAYER_ONLY_ALIVE))
		return PLUGIN_HANDLED
	
	new Float:fOrigin[3]
	fOrigin[0] = str_to_float(X)
	fOrigin[1] = str_to_float(Y)
	fOrigin[2] = str_to_float(Z)
	set_pev(iPlayer, pev_origin, fOrigin)
	
	new sPlayerName[MAX_NAME_LEN]; get_user_name(iPlayer, sPlayerName, charsmax(sPlayerName))
	new sPlayerAuthid[MAX_AUTHID_LEN]; get_user_authid(iPlayer, sPlayerAuthid, charsmax(sPlayerAuthid))
	new sAdminName[MAX_NAME_LEN]; get_user_name(id, sAdminName, charsmax(sAdminName))
	new sAdminAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAdminAuthid, charsmax(sAdminAuthid))
	new sAdminRealName[MAX_NAME_LEN]; fm_GetUserRealname(id, sAdminRealName, charsmax(sAdminRealName))

	client_print(0, print_chat, "* ADMIN #%d %s: teleported %s<%s> to %0.2f %0.2f %0.2f", fm_GetUserIdent(id), sAdminRealName, sPlayerName, sPlayerAuthid, fOrigin[0], fOrigin[1], fOrigin[2])
	console_print(id, "You have teleported %s<%s> to %0.2f %0.2f %0.2f", sPlayerName, sPlayerAuthid, fOrigin[0], fOrigin[1], fOrigin[2])
	log_amx("\"%s<%s>(%s)\" admin_teleport \"%s<%s>\" to %0.2f %0.2f %0.2f", sAdminName, sAdminAuthid, sAdminRealName, sPlayerName, sPlayerAuthid, fOrigin[0], fOrigin[1], fOrigin[2])

	return PLUGIN_HANDLED
}

