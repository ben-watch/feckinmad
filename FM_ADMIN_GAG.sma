#include "feckinmad/fm_global"
#include "feckinmad/fm_admin_api" // fm_GetAdminInfoByIdent
#include "feckinmad/fm_player_get"
#include "feckinmad/fm_admin_access"
#include "feckinmad/fm_ban"

new Array:g_GagList = Invalid_Array
new g_PlayerBanInfo[MAX_PLAYERS + 1][eBanInfo_t]
new g_iCurrentGagIdent

new const g_sGagFile[] = "fm_gags.dat"
new g_sGagFilePath[128]

public plugin_init()
{
	fm_RegisterPlugin()

	g_GagList = fm_CreateBanList()

	fm_BuildAMXFilePath(g_sGagFile, g_sGagFilePath, charsmax(g_sGagFilePath), "amxx_datadir")
	g_iCurrentGagIdent = fm_ReadBanFile(g_GagList, g_sGagFilePath)

	if (g_iCurrentGagIdent > 0)
	{
		log_amx("Loaded %d gags from \"%s\"", ArraySize(g_GagList), g_sGagFilePath)

		new iPruned = fm_PruneTimedBans(g_GagList)/*, true)*/
		if (iPruned > 0)
		{
			log_amx("Pruned %d gags from \"%s\"", iPruned, g_sGagFilePath)
			fm_WriteBanFile(g_GagList, g_sGagFilePath, g_iCurrentGagIdent)
		}

		register_concmd("admin_gag", "Admin_Gag", ADMIN_MEMBER, "<target> <length> [reason]")
		register_concmd("admin_ungag", "Admin_UnGag", ADMIN_MEMBER, "<target>")
		register_concmd("admin_listgags", "Admin_ListGags", ADMIN_MEMBER)

		register_clcmd("say", "Handle_Say")
		register_clcmd("say_team", "Handle_Say")

		register_message(get_user_msgid("SayText"), "Message_SayText") // To block change name messages
	}
	else
		fm_WarningLog("g_iCurrentGagIdent <= 0 (%d)", g_iCurrentGagIdent)
}

public plugin_end()
{
	if (g_GagList != Invalid_Array)
	{
		ArrayDestroy(g_GagList)
	}
}

public Handle_Say(id) 
{
	static sArgs[192]; read_args(sArgs, charsmax(sArgs))
	remove_quotes(sArgs)
	
	if (!sArgs[0]) 
		return PLUGIN_HANDLED
	
	new iType = fm_GetBanType(g_PlayerBanInfo[id])
	switch(iType)
	{
		case BANTYPE_NONE: return PLUGIN_CONTINUE
		case BANTYPE_PERMANENT, BANTYPE_MAP: client_print(id, print_chat, "* You are gagged %s", g_sTextBanLength[iType])
		case BANTYPE_TIMED:
		{
			if (fm_HasTimedBanExpired(g_PlayerBanInfo[id]))
			{
				fm_RemoveBanByIdent(g_GagList, fm_GetBanIdent(g_PlayerBanInfo[id]))
				fm_ClearBanInfo(g_PlayerBanInfo[id])
				fm_WriteBanFile(g_GagList, g_sGagFilePath, g_iCurrentGagIdent)

				return PLUGIN_CONTINUE
			}

			new sTime[64]; fm_SecondsToText(fm_GetBanTimeRemaining(g_PlayerBanInfo[id]), sTime, charsmax(sTime))
			client_print(id, print_chat, "* You are gagged for %s", sTime)
		}
	}
	return PLUGIN_HANDLED_MAIN // Pass to other plugins so they can still trigger things like rockthevote
}

public Message_SayText(iMsgId, iDest, iEnt)
{
	// Check it's the server sending the message
	if (iEnt)
		return PLUGIN_CONTINUE 
	
	new sMessage[MAX_CHAT_LEN]; get_msg_arg_string(2, sMessage, charsmax(sMessage))
	if (contain(sMessage, "changed name to") != -1)
	{
		new id = get_msg_arg_int(1)
		new iType = fm_GetBanType(g_PlayerBanInfo[id])

		if (iType == BANTYPE_NONE)
			return PLUGIN_CONTINUE 

		if (fm_HasTimedBanExpired(g_PlayerBanInfo[id]))
		{
			fm_RemoveBanByIdent(g_GagList, fm_GetBanIdent(g_PlayerBanInfo[id]))
			fm_ClearBanInfo(g_PlayerBanInfo[id])
			fm_WriteBanFile(g_GagList, g_sGagFilePath, g_iCurrentGagIdent)

			return PLUGIN_CONTINUE 
		}

		fm_DebugPrintLevel(3, "Blocked message: \"%s\"", sMessage)
		return PLUGIN_HANDLED // Block name change message from appearing
	}
	return PLUGIN_CONTINUE 
}

public client_connect(id)
{
	fm_ClearBanInfo(g_PlayerBanInfo[id])
}

public client_authorized(id)
{
	new sAuthId[MAX_AUTHID_LEN]; get_user_authid(id, sAuthId, charsmax(sAuthId))
	fm_GetBanInfoByAuth(g_GagList, sAuthId, g_PlayerBanInfo[id])
}

public client_disconnect(id)
{
	fm_ClearBanInfo(g_PlayerBanInfo[id])
}

public Admin_ListGags(id, iLevel, iCommand)
{
	if (!fm_CommandAccess(id, iLevel, false))
		return PLUGIN_HANDLED

	if (fm_PruneTimedBans(g_GagList)) /*, false))*/
		fm_WriteBanFile(g_GagList, g_sGagFilePath, g_iCurrentGagIdent)

	new iCount = ArraySize(g_GagList)
	new Buffer[eBanInfo_t], sType[128], AdminInfo[eAdmin_t]

	console_print(id, "\n\nCurrent Gags:")

	for (new i = 0; i < iCount; i++)
	{
		ArrayGetArray(g_GagList, i, Buffer)

		fm_GetAdminInfoByIdent(Buffer[m_iBanAdmin], AdminInfo)
		fm_FormatBanType(Buffer, sType, charsmax(sType))
		console_print(id, "#%d %s<%s> %s - Admin: #%d %s - Reason: %s",  Buffer[m_iBanIdent], Buffer[m_sBanName], Buffer[m_sBanAuthid], sType, Buffer[m_iBanAdmin], AdminInfo[m_sAdminName], Buffer[m_sBanReason])
	}

	console_print(id, "Total: %d", iCount)

	return PLUGIN_HANDLED
}

public Admin_UnGag(id, iLevel, iCommand)
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

		new BanInfo[eBanInfo_t], iIndex = fm_GetBanInfoByAuth(g_GagList, sArgs, BanInfo)
		if (iIndex != -1)
		{	
			copy(sPlayerName, charsmax(sPlayerName), BanInfo[m_sBanName])
			copy(sPlayerAuthid, charsmax(sPlayerAuthid), BanInfo[m_sBanAuthid])
			fm_RemoveBanByIndex(g_GagList, iIndex)	
		}
		else
		{
			console_print(id, "No gag found for \"%s\"", sArgs)	
			return PLUGIN_HANDLED
		}			
	}
	else
	{
		get_user_name(iPlayer, sPlayerName, charsmax(sPlayerName))
		get_user_authid(iPlayer, sPlayerAuthid, charsmax(sPlayerAuthid))

		if (fm_GetBanType(g_PlayerBanInfo[iPlayer]) == BANTYPE_NONE)
		{
			console_print(id,"%s <%s> is not gagged", sPlayerName, sPlayerAuthid)
			return PLUGIN_HANDLED
		}
		
		fm_RemoveBanByIdent(g_GagList, fm_GetBanIdent(g_PlayerBanInfo[iPlayer]))
		fm_ClearBanInfo(g_PlayerBanInfo[iPlayer])
	}
		
	fm_WriteBanFile(g_GagList, g_sGagFilePath, g_iCurrentGagIdent)

	new sAdminName[MAX_NAME_LEN]; get_user_name(id, sAdminName, charsmax(sAdminName))
	new sAdminAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAdminAuthid, charsmax(sAdminAuthid))
	new sAdminRealName[MAX_NAME_LEN]; fm_GetUserRealname(id, sAdminRealName, charsmax(sAdminRealName))
	
	client_print(0, print_chat, "* ADMIN #%d %s: ungagged %s<%s>", fm_GetUserIdent(id), sAdminRealName, sPlayerName, sPlayerAuthid)
	console_print(id, "You have ungagged %s<%s>", sPlayerName, sPlayerAuthid)

	new sCommand[32]; read_argv(0, sCommand, charsmax(sCommand))
	log_amx("\"%s<%s>(%s)\" %s \"%s<%s>\"", sAdminName, sAdminAuthid, sAdminRealName, sCommand, sPlayerName, sPlayerAuthid)

	return PLUGIN_HANDLED
}

public Admin_Gag(id, iLevel, iCommand) 
{
	if (!fm_CommandAccess(id, iLevel, false) || !fm_CommandUsage(id, iCommand, 3))
		return PLUGIN_HANDLED

	new sTarget[64], sArgs[192]; read_args(sArgs, charsmax(sArgs)) 
	strbreak(sArgs, sTarget, charsmax(sTarget), sArgs, charsmax(sArgs))

	new iPlayer = fm_CommandGetPlayer(id, sTarget)
	if (!iPlayer)
		return PLUGIN_HANDLED

	new sPlayerName[MAX_NAME_LEN]; get_user_name(iPlayer, sPlayerName, charsmax(sPlayerName))
	if (fm_GetBanType(g_PlayerBanInfo[iPlayer]) != BANTYPE_NONE)
	{
		if (fm_HasTimedBanExpired(g_PlayerBanInfo[iPlayer]))
		{
			fm_RemoveBanByIdent(g_GagList, fm_GetBanIdent(g_PlayerBanInfo[iPlayer]))
			fm_ClearBanInfo(g_PlayerBanInfo[iPlayer])
			fm_WriteBanFile(g_GagList, g_sGagFilePath, g_iCurrentGagIdent)	
		}
		else
		{
			new AdminInfo[eAdmin_t]; fm_GetAdminInfoByIdent(g_PlayerBanInfo[iPlayer][m_iBanAdmin], AdminInfo)
			new sType[128]; fm_FormatBanType(g_PlayerBanInfo[iPlayer], sType, charsmax(sType))

			console_print(id, "%s has already been gagged by Admin: #%d %s", sPlayerName, g_PlayerBanInfo[iPlayer][m_iBanAdmin], AdminInfo[m_sAdminName])
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

	copy(g_PlayerBanInfo[iPlayer][m_sBanReason], MAX_REASON_LEN - 1, sReason)
	copy(g_PlayerBanInfo[iPlayer][m_sBanAuthid], MAX_AUTHID_LEN - 1, sPlayerAuthid)
	copy(g_PlayerBanInfo[iPlayer][m_sBanName], MAX_NAME_LEN - 1, sPlayerName)
	g_PlayerBanInfo[iPlayer][m_iBanIdent] = g_iCurrentGagIdent++
	g_PlayerBanInfo[iPlayer][m_iBanTime] = get_systime()
	g_PlayerBanInfo[iPlayer][m_iBanAdmin] = fm_GetUserIdent(id)

	fm_AddBanByStruct(g_GagList, g_PlayerBanInfo[iPlayer])
	fm_WriteBanFile(g_GagList, g_sGagFilePath, g_iCurrentGagIdent)

	client_print(0, print_chat, "* ADMIN #%d %s: gagged %s<%s> %s Reason: %s", fm_GetUserIdent(id), sAdminRealName, sPlayerName, sPlayerAuthid, sLength, sReason)
	console_print(id, "You have gagged %s<%s> %s", sPlayerName, sPlayerAuthid, sLength)
	log_amx("\"%s<%s>(%s)\" admin_gag \"%s<%s>\" %s", sAdminName, sAdminAuthid, sAdminRealName, sPlayerName, sPlayerAuthid, sLength)

	return PLUGIN_HANDLED
}
