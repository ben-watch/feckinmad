#include "feckinmad/fm_global"
#include "feckinmad/fm_admin_access"
#include "feckinmad/fm_stuck"

#include <fakemeta>

#define TELEPORT_SLOTS 16

new const g_sSpriteTeleportStart[] = "sprites/enter1.spr"
new const g_sSpriteTeleportEnd[] = "sprites/exit1.spr"

new const g_sTextNotValid[] = "Please enter a teleporter index between 0 and %d"
new const g_sTextExists[] = "Teleporter %s %d already exists. Remove it or use a different index"

new g_iTeleportStartEnt[TELEPORT_SLOTS]
new g_iTeleportEndEnt[TELEPORT_SLOTS]
new g_iTeleportStartCount

new g_iForward, g_iScreenFade, g_iMaxPlayers

CreateTeleportSprite(const sSprite[], Float:fOrigin[3])
{
	new iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_sprite")) 
	
	set_pev(iEnt, pev_model, sSprite)
	set_pev(iEnt, pev_framerate, 10.0)
	
	dllfunc(DLLFunc_Spawn, iEnt)

	engfunc(EngFunc_SetOrigin, iEnt, fOrigin)
	set_pev(iEnt, pev_rendermode, kRenderTransAdd)
	set_pev(iEnt, pev_renderamt, 255.0)	
	
	return iEnt
}

GetTeleportStartIndexByEnt(iEnt)
{
	for (new i = 0; i < TELEPORT_SLOTS; i++)
		if (g_iTeleportStartEnt[i] == iEnt)
			return i
	return -1
}

CheckValidTeleportIndex(iSlot)
{
	if (iSlot < 0 || iSlot >= TELEPORT_SLOTS)
		return 0	
	return 1
}

public plugin_precache() 
{
	engfunc(EngFunc_PrecacheModel, g_sSpriteTeleportStart)
	engfunc(EngFunc_PrecacheModel, g_sSpriteTeleportEnd)
}

public plugin_init() 
{
	fm_RegisterPlugin()
	
	g_iScreenFade = get_user_msgid("ScreenFade")
	g_iMaxPlayers = get_maxplayers()
	
	register_concmd("admin_tpstart","Admin_TeleStart", 0, "<index>")
	register_concmd("admin_tpend","Admin_TeleEnd", 0, "<index>")
	register_concmd("admin_tpkillstart","Admin_TeleKill", 0, "<index>")
	register_concmd("admin_tpkillend","Admin_TeleKill", 0, "<index>")
	register_concmd("admin_tpkill","Admin_TeleKill", 0, "<index>")
}

public Admin_TeleStart(id, iLevel, iCommand)
{
	if (!fm_CommandAccess(id, iLevel, false) || !fm_CommandUsage(id, iCommand, 2))
		return PLUGIN_HANDLED
	
	new sArgs[8]; read_args(sArgs, charsmax(sArgs))
	new iIndex = str_to_num(sArgs)
	
	if (!CheckValidTeleportIndex(iIndex))
	{
		console_print(id, g_sTextNotValid, TELEPORT_SLOTS - 1)
		return PLUGIN_HANDLED
	}
	
	if (g_iTeleportStartEnt[iIndex])
	{
		console_print(id, g_sTextExists, "start", iIndex)
		return PLUGIN_HANDLED
	}
		
	new Float:fOrigin[3]; pev(id, pev_origin, fOrigin)
	g_iTeleportStartEnt[iIndex] = CreateTeleportSprite(g_sSpriteTeleportStart, fOrigin)

	set_pev(g_iTeleportStartEnt[iIndex], pev_solid, SOLID_TRIGGER)
	engfunc(EngFunc_SetSize, g_iTeleportStartEnt[iIndex], { -16.0, -16.0, -16.0 } , { 16.0, 16.0, 16.0 } )
	
	if (!g_iTeleportStartCount)
		g_iForward = register_forward(FM_Touch, "Forward_Touch")
	g_iTeleportStartCount++

	new sAdminName[MAX_NAME_LEN]; get_user_name(id, sAdminName, charsmax(sAdminName))
	new sAdminAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAdminAuthid, charsmax(sAdminAuthid))
	new sAdminRealName[MAX_NAME_LEN]; fm_GetUserRealname(id, sAdminRealName, charsmax(sAdminRealName))

	client_print(0, print_chat, "* ADMIN #%d %s: created a teleport entrance with index %d", fm_GetUserIdent(id), sAdminRealName, iIndex)
	console_print(id, "You have created a teleport entrance with index %d", iIndex)
	log_amx("\"%s<%s>(%s)\" admin_tpstart. Index %d { %0.2f %0.2f %0.2f }", sAdminName, sAdminAuthid, sAdminRealName, iIndex, fOrigin[0], fOrigin[1], fOrigin[2])
	
	return PLUGIN_HANDLED
}

public Admin_TeleEnd(id, iLevel, iCommand)
{
	if (!fm_CommandAccess(id, iLevel, false) || !fm_CommandUsage(id, iCommand, 2))
		return PLUGIN_HANDLED

	new sArgs[8]; read_args(sArgs, charsmax(sArgs))
	new iIndex = str_to_num(sArgs)
	
	if (!CheckValidTeleportIndex(iIndex))
	{
		console_print(id, g_sTextNotValid, TELEPORT_SLOTS - 1)
		return PLUGIN_HANDLED
	}
	
	if (g_iTeleportEndEnt[iIndex])
	{
		console_print(id, g_sTextExists, "end", iIndex)
		return PLUGIN_HANDLED
	}
	
	new Float:fOrigin[3]; pev(id, pev_origin, fOrigin)
	engfunc(EngFunc_TraceHull, fOrigin, fOrigin, IGNORE_MONSTERS, HULL_HUMAN, id, 0)

	if (get_tr2(0, TR_StartSolid) || get_tr2(0, TR_AllSolid) || !get_tr2(0, TR_InOpen))
	{
		console_print(id, "Creating a teleport exit here would cause the player to get stuck")
		return PLUGIN_HANDLED	
	}
		
	g_iTeleportEndEnt[iIndex] = CreateTeleportSprite(g_sSpriteTeleportEnd, fOrigin)

	new sAdminName[MAX_NAME_LEN]; get_user_name(id, sAdminName, charsmax(sAdminName))
	new sAdminAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAdminAuthid, charsmax(sAdminAuthid))
	new sAdminRealName[MAX_NAME_LEN]; fm_GetUserRealname(id, sAdminRealName, charsmax(sAdminRealName))

	client_print(0, print_chat, "* ADMIN #%d %s: created a teleport exit with index %d", fm_GetUserIdent(id), sAdminRealName, iIndex)
	console_print(id, "You have created a teleport exit with index %d", iIndex)
	log_amx("\"%s<%s>(%s)\" admin_tpend. Index %d { %0.2f %0.2f %0.2f }", sAdminName, sAdminAuthid, sAdminRealName, iIndex, fOrigin[0], fOrigin[1], fOrigin[2])
	
	return PLUGIN_HANDLED
}

new Float:g_fPlayerNextMessage[MAX_PLAYERS + 1]

public Forward_Touch(iTeleport, iPlayer)
{
	if ((iPlayer < 1 || iPlayer > g_iMaxPlayers) || !is_user_alive(iPlayer))
		return FMRES_IGNORED

	static iIndex
	if (!pev_valid(iTeleport) || (iIndex = GetTeleportStartIndexByEnt(iTeleport)) == -1 )
		return FMRES_IGNORED
				
	if (!g_iTeleportEndEnt[iIndex])
	{
		static Float:fGameTime; fGameTime = get_gametime()
		if (fGameTime > g_fPlayerNextMessage[iPlayer])
		{
			client_print(iPlayer, print_center, "There is no exit for this teleporter")
			g_fPlayerNextMessage[iPlayer] = fGameTime + 3.0
		}
		return FMRES_IGNORED
	}

	message_begin(MSG_ONE, g_iScreenFade, { 0, 0, 0 }, iPlayer) 
	write_short(1<<9) // Duration 
	write_short(1<<9) // Holde 
	write_short(SF_FADE_IN)
	write_byte(random_num(100, 200)) // Red 
	write_byte(255) // Green 
	write_byte(0) // Blue 
	write_byte(175) // Alpha 
	message_end()  
	
	new Float:fOrigin[3]; pev(g_iTeleportEndEnt[iIndex], pev_origin, fOrigin)			
	set_pev(iPlayer, pev_origin, fOrigin)
	fm_UnstickPlayer(iPlayer)

	set_pev(iPlayer, pev_velocity, { 0.0, 0.0, 0.0 })
	fm_PlaySound(iPlayer, "debris/beamstart1.wav")
		
	return FMRES_IGNORED	
}

public Admin_TeleKill(id, iLevel, iCommand)
{
	if (!fm_CommandAccess(id, iLevel, false) || !fm_CommandUsage(id, iCommand, 2))
		return PLUGIN_HANDLED

	new sArgs[8]; read_args(sArgs, charsmax(sArgs))
	new iIndex = str_to_num(sArgs) 
	new sCommand[32]; read_argv(0, sCommand, charsmax(sCommand))

	new sAdminName[MAX_NAME_LEN]; get_user_name(id, sAdminName, charsmax(sAdminName))
	new sAdminAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAdminAuthid, charsmax(sAdminAuthid))
	new sAdminRealName[MAX_NAME_LEN]; fm_GetUserRealname(id, sAdminRealName, charsmax(sAdminRealName))

	new iCommand = equal(sCommand[12], "start") ? 1 : equal(sCommand[12], "end") ? 2 : 3
	if (iCommand == 3 || iCommand == 1)  // admin_tpkill || admin_tpkillstart
	{
		if (g_iTeleportStartEnt[iIndex])
		{
			RemoveTeleportStart(iIndex)
			client_print(0, print_chat, "* ADMIN #%d %s: removed a teleport start with index %d", fm_GetUserIdent(id), sAdminRealName, iIndex)
			console_print(id, "You have removed a teleport start with index %d", iIndex)
			log_amx("\"%s<%s>(%s)\" %s. Index %d", sAdminName, sAdminAuthid, sAdminRealName,  sCommand,iIndex)
		}
		else
		{
			console_print(id,"Teleporter start index %d not found", iIndex)	
		}
	}
	
	if (iCommand == 3 || iCommand == 2) // admin_tpkill || admin_tpkillend
	{
		if (g_iTeleportEndEnt[iIndex])
		{
			RemoveTeleportEnd(iIndex)
			client_print(0, print_chat, "* ADMIN #%d %s: removed a teleport end with index %d", fm_GetUserIdent(id), sAdminRealName, iIndex)
			console_print(id, "You have removed a teleport end with index %d", iIndex)
			log_amx("\"%s<%s>(%s)\" %s. Index %d", sAdminName, sAdminAuthid, sAdminRealName,  sCommand,iIndex)
		}
		else
		{
			console_print(id, "Teleporter end index %d not found", iIndex)
		}	
	}
	return PLUGIN_HANDLED
}

RemoveTeleportStart(iIndex)
{
	engfunc(EngFunc_RemoveEntity, g_iTeleportStartEnt[iIndex])
	g_iTeleportStartEnt[iIndex] = 0
	g_iTeleportStartCount--
	
	if (!g_iTeleportStartCount)
		unregister_forward(FM_Touch, g_iForward)
}

RemoveTeleportEnd(iIndex)
{
	engfunc(EngFunc_RemoveEntity, g_iTeleportEndEnt[iIndex])
	g_iTeleportEndEnt[iIndex] = 0		
}