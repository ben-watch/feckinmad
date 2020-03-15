#include "feckinmad/fm_global"
#include "feckinmad/fm_player_get"
#include "feckinmad/fm_admin_api"
#include "feckinmad/fm_admin_access"
#include "feckinmad/fm_ban"
#include "feckinmad/fm_voice_api"

#include <fakemeta>

new Array:g_MuteList = Invalid_Array
new g_PlayerBanInfo[MAX_PLAYERS + 1][eBanInfo_t]
new g_iCurrentMuteIdent

new const g_sMuteFile[] = "fm_mutes.dat"
new g_sMuteFilePath[128]

new g_iEnt, g_iThinkForward, g_iMaxPlayers

public plugin_init()
{
	fm_RegisterPlugin()

	g_MuteList = fm_CreateBanList()

	fm_BuildAMXFilePath(g_sMuteFile, g_sMuteFilePath, charsmax(g_sMuteFilePath), "amxx_datadir")
	g_iCurrentMuteIdent = fm_ReadBanFile(g_MuteList, g_sMuteFilePath)

	if (g_iCurrentMuteIdent > 0)
	{
		log_amx("Loaded %d mutes from \"%s\"", ArraySize(g_MuteList), g_sMuteFilePath)

		new iPruned = fm_PruneTimedBans(g_MuteList)
		if (iPruned > 0)
		{
			log_amx("Pruned %d mutes from \"%s\"", iPruned, g_sMuteFilePath)
			fm_WriteBanFile(g_MuteList, g_sMuteFilePath, g_iCurrentMuteIdent)
		}

		register_concmd("admin_mute", "Admin_Mute", ADMIN_MEMBER, "<target> <length> [reason]")
		register_concmd("admin_unmute", "Admin_UnMute", ADMIN_MEMBER, "<target>")
		register_concmd("admin_listmutes", "Admin_ListMutes", ADMIN_MEMBER)
	}
	else
		fm_WarningLog("g_iCurrentMuteIdent <= 0 (%d)", g_iCurrentMuteIdent)

	g_iMaxPlayers = get_maxplayers()
}


public plugin_end()
{
	if (g_MuteList != Invalid_Array)
	{
		ArrayDestroy(g_MuteList)
	}
}

public client_authorized(id)
{
	new sAuthId[MAX_AUTHID_LEN]; get_user_authid(id, sAuthId, charsmax(sAuthId))

	if (fm_GetBanInfoByAuth(g_MuteList, sAuthId, g_PlayerBanInfo[id]) != -1)
	{
		if (fm_HasTimedBanExpired(g_PlayerBanInfo[id]))
		{
			fm_RemoveBanByIdent(g_MuteList, fm_GetBanIdent(g_PlayerBanInfo[id]))
			fm_ClearBanInfo(g_PlayerBanInfo[id])
			fm_WriteBanFile(g_MuteList, g_sMuteFilePath, g_iCurrentMuteIdent)	
		}
		else
		{
			fm_SetVoiceListening(0, id, SPEAK_MUTED)

			if (!g_iEnt && fm_GetBanType(g_PlayerBanInfo[id]) == BANTYPE_TIMED)
			{
				CreateMuteTimer()
			}
		}
	}	
}

public client_disconnect(id)
{
	fm_ClearBanInfo(g_PlayerBanInfo[id])
}

public Admin_ListMutes(id, iLevel, iCommand)
{
	if (!fm_CommandAccess(id, iLevel, false))
		return PLUGIN_HANDLED

	if (fm_PruneTimedBans(g_MuteList))
		fm_WriteBanFile(g_MuteList, g_sMuteFilePath, g_iCurrentMuteIdent)

	new iCount = ArraySize(g_MuteList)
	new Buffer[eBanInfo_t], sType[128], AdminInfo[eAdmin_t]

	console_print(id, "\n\nCurrent Mutes:")

	for (new i = 0; i < iCount; i++)
	{
		ArrayGetArray(g_MuteList, i, Buffer)

		fm_GetAdminInfoByIdent(Buffer[m_iBanAdmin], AdminInfo)
		fm_FormatBanType(Buffer, sType, charsmax(sType))
		console_print(id, "#%d %s<%s> %s - Admin: #%d %s - Reason: %s",  Buffer[m_iBanIdent], Buffer[m_sBanName], Buffer[m_sBanAuthid], sType, Buffer[m_iBanAdmin], AdminInfo[m_sAdminName], Buffer[m_sBanReason])
	}

	console_print(id, "Total: %d", iCount)

	return PLUGIN_HANDLED
}

public Admin_UnMute(id, iLevel, iCommand)
{
	if (!fm_CommandAccess(id, iLevel, false) || !fm_CommandUsage(id, iCommand, 2))
		return PLUGIN_HANDLED
	
	new sArgs[192]; read_args(sArgs, charsmax(sArgs))
	new sPlayerName[MAX_NAME_LEN], sPlayerAuthid[MAX_AUTHID_LEN]

	new iPlayer = fm_CommandGetPlayer(id, sArgs)
	if (!iPlayer)
	{
		if (!equal(sArgs, "STEAM_", 6)) 
			return PLUGIN_HANDLED

		new BanInfo[eBanInfo_t], iIndex = fm_GetBanInfoByAuth(g_MuteList, sArgs, BanInfo)
		if (iIndex != -1)
		{	
			copy(sPlayerName, charsmax(sPlayerName), BanInfo[m_sBanName])
			copy(sPlayerAuthid, charsmax(sPlayerAuthid), BanInfo[m_sBanAuthid])
			fm_RemoveBanByIndex(g_MuteList, iIndex)	
		}
		else
		{
			console_print(id, "No mute found for \"%s\"", sArgs)	
			return PLUGIN_HANDLED
		}			
	}
	else
	{
		get_user_name(iPlayer, sPlayerName, charsmax(sPlayerName))
		get_user_authid(iPlayer, sPlayerAuthid, charsmax(sPlayerAuthid))

		if (fm_GetBanType(g_PlayerBanInfo[iPlayer]) == BANTYPE_NONE)
		{
			console_print(id,"%s <%s> is not muted", sPlayerName, sPlayerAuthid)
			return PLUGIN_HANDLED
		}
		
		fm_RemoveBanByIdent(g_MuteList, fm_GetBanIdent(g_PlayerBanInfo[iPlayer]))
		fm_ClearBanInfo(g_PlayerBanInfo[iPlayer])

		fm_SetVoiceListening(0, iPlayer, SPEAK_NORMAL)
	}
		
	fm_WriteBanFile(g_MuteList, g_sMuteFilePath, g_iCurrentMuteIdent)

	new sAdminName[MAX_NAME_LEN]; get_user_name(id, sAdminName, charsmax(sAdminName))
	new sAdminAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAdminAuthid, charsmax(sAdminAuthid))
	new sAdminRealName[MAX_NAME_LEN]; fm_GetUserRealname(id, sAdminRealName, charsmax(sAdminRealName))
	
	client_print(0, print_chat, "* ADMIN #%d %s: unmuted %s<%s>", fm_GetUserIdent(id), sAdminRealName, sPlayerName, sPlayerAuthid)
	console_print(id, "You have unmuted %s<%s>", sPlayerName, sPlayerAuthid)

	new sCommand[32]; read_argv(0, sCommand, charsmax(sCommand))
	log_amx("\"%s<%s>(%s)\" %s \"%s<%s>\"", sAdminName, sAdminAuthid, sAdminRealName, sCommand, sPlayerName, sPlayerAuthid)

	return PLUGIN_HANDLED
}

public Admin_Mute(id, iLevel, iCommand) 
{
	if (!fm_CommandAccess(id, iLevel, false) || !fm_CommandUsage(id, iCommand, 3))
		return PLUGIN_HANDLED

	new sTarget[64], sArgs[192]; read_args(sArgs, charsmax(sArgs)) 
	argbreak(sArgs, sTarget, charsmax(sTarget), sArgs, charsmax(sArgs))

	new iPlayer = fm_CommandGetPlayer(id, sTarget)
	if (!iPlayer)
		return PLUGIN_HANDLED

	new sPlayerName[MAX_NAME_LEN]; get_user_name(iPlayer, sPlayerName, charsmax(sPlayerName))
	if (fm_GetBanType(g_PlayerBanInfo[iPlayer]) != BANTYPE_NONE)
	{
		if (fm_HasTimedBanExpired(g_PlayerBanInfo[iPlayer]))
		{
			fm_RemoveBanByIdent(g_MuteList, fm_GetBanIdent(g_PlayerBanInfo[iPlayer]))
			fm_ClearBanInfo(g_PlayerBanInfo[iPlayer])
			fm_WriteBanFile(g_MuteList, g_sMuteFilePath, g_iCurrentMuteIdent)	
		}
		else
		{
			new AdminInfo[eAdmin_t]; fm_GetAdminInfoByIdent(g_PlayerBanInfo[iPlayer][m_iBanAdmin], AdminInfo)
			new sType[128]; fm_FormatBanType(g_PlayerBanInfo[iPlayer], sType, charsmax(sType))

			console_print(id, "%s has already been muted by Admin: #%d %s", sPlayerName, g_PlayerBanInfo[iPlayer][m_iBanAdmin], AdminInfo[m_sAdminName])
			console_print(id, "%s Reason: %s", sType, g_PlayerBanInfo[iPlayer][m_sBanReason])
		}
		return PLUGIN_HANDLED
	}

	new sLength[64], sReason[MAX_REASON_LEN]
	strbreak(sArgs, sLength, charsmax(sLength), sReason, charsmax(sReason))

	if (!is_str_num2(sLength))
	{
		console_print(id, "Length must be a number")
		return PLUGIN_HANDLED
	}

	trim(sReason)
	if (!sReason[0])
		copy(sReason, charsmax(sReason), "None")

	new sPlayerAuthid[MAX_AUTHID_LEN]; get_user_authid(iPlayer, sPlayerAuthid, charsmax(sPlayerAuthid))
	new sAdminName[MAX_NAME_LEN]; get_user_name(id, sAdminName, charsmax(sAdminName))
	new sAdminAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAdminAuthid, charsmax(sAdminAuthid))
	new sAdminRealName[MAX_NAME_LEN]; fm_GetUserRealname(id, sAdminRealName, charsmax(sAdminRealName))

	new iLength = str_to_num(sLength) 

	if (iLength < 0)
	{
		fm_SetBanType(g_PlayerBanInfo[iPlayer], BANTYPE_MAP)
		copy(sLength, charsmax(sLength), g_sTextBanLength[BANTYPE_MAP])
	}
	else if (!iLength)
	{
		fm_SetBanType(g_PlayerBanInfo[iPlayer], BANTYPE_PERMANENT)
		copy(sLength, charsmax(sLength), g_sTextBanLength[BANTYPE_PERMANENT])
	}
	else
	{
		fm_SetBanType(g_PlayerBanInfo[iPlayer], BANTYPE_TIMED)

		if (iLength > MAX_BAN_LEN_MINS)
			iLength = MAX_BAN_LEN_MINS

		iLength *= 60 // Convert minutes to seconds
		g_PlayerBanInfo[iPlayer][m_iBanLength] = iLength

		new sTime[64]; fm_SecondsToText(iLength , sTime, charsmax(sTime))
		formatex(sLength, charsmax(sLength), "for %s", sTime)
	}

	fm_SetVoiceListening(0, iPlayer, SPEAK_MUTED)

	copy(g_PlayerBanInfo[iPlayer][m_sBanReason], MAX_REASON_LEN - 1, sReason)
	copy(g_PlayerBanInfo[iPlayer][m_sBanAuthid], MAX_AUTHID_LEN - 1, sPlayerAuthid)
	copy(g_PlayerBanInfo[iPlayer][m_sBanName], MAX_NAME_LEN - 1, sPlayerName)
	g_PlayerBanInfo[iPlayer][m_iBanIdent] = g_iCurrentMuteIdent++
	g_PlayerBanInfo[iPlayer][m_iBanTime] = get_systime()
	g_PlayerBanInfo[iPlayer][m_iBanAdmin] = fm_GetUserIdent(id)

	fm_AddBanByStruct(g_MuteList, g_PlayerBanInfo[iPlayer])
	fm_WriteBanFile(g_MuteList, g_sMuteFilePath, g_iCurrentMuteIdent)

	client_print(0, print_chat, "* ADMIN #%d %s: muted %s<%s> %s Reason: %s", fm_GetUserIdent(id), sAdminRealName, sPlayerName, sPlayerAuthid, sLength, sReason)
	console_print(id, "You have muted %s<%s> %s", sPlayerName, sPlayerAuthid, sLength)
	log_amx("\"%s<%s>(%s)\" admin_mute \"%s<%s>\" %s", sAdminName, sAdminAuthid, sAdminRealName, sPlayerName, sPlayerAuthid, sLength)

	return PLUGIN_HANDLED
}

CreateMuteTimer()
{
	g_iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target")) 
	if (!g_iEnt)
	{
		fm_WarningLog(FM_ENT_WARNING)
	}
	else
	{
		g_iThinkForward = register_forward(FM_Think, "Forward_Think")
		set_pev(g_iEnt, pev_nextthink, get_gametime() + 1.0)		
	}
}

public Forward_Think(iEnt)
{	
	if (iEnt != g_iEnt)
	{
		return FMRES_IGNORED
	}

	new bool:bRepeat
	
	for (new i = 1; i <= g_iMaxPlayers; i++)
	{
		if (fm_GetBanType(g_PlayerBanInfo[i]) != BANTYPE_TIMED)
		{
			continue
		}

		if (fm_HasTimedBanExpired(g_PlayerBanInfo[i]))
		{
			fm_SetVoiceListening(0, i, SPEAK_NORMAL)

			fm_RemoveBanByIdent(g_MuteList, fm_GetBanIdent(g_PlayerBanInfo[i]))
			fm_ClearBanInfo(g_PlayerBanInfo[i])
			fm_WriteBanFile(g_MuteList, g_sMuteFilePath, g_iCurrentMuteIdent)
		}
		else
		{
			bRepeat = true
		}
	}
			
	if (!bRepeat)
	{
		engfunc(EngFunc_RemoveEntity, iEnt)
		unregister_forward(FM_Think, g_iThinkForward)
		g_iThinkForward = g_iEnt = 0
	}
	else
	{
		set_pev(iEnt, pev_nextthink, get_gametime() + 1.0)
	}
			
	return FMRES_IGNORED
}	