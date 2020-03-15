#include "feckinmad/fm_global"
#include "feckinmad/fm_player_get"
#include "feckinmad/fm_admin_api"
#include "feckinmad/fm_admin_access"
#include "feckinmad/fm_ban"

new Array:g_BanList = Invalid_Array
new g_iCurrentBanIdent

new const g_sBanFile[] = "fm_bans.dat"
new g_sBanFilePath[128]

public plugin_init()
{
	fm_RegisterPlugin()

	g_BanList = fm_CreateBanList()

	fm_BuildAMXFilePath(g_sBanFile, g_sBanFilePath, charsmax(g_sBanFilePath), "amxx_datadir")
	g_iCurrentBanIdent = fm_ReadBanFile(g_BanList, g_sBanFilePath)

	if (g_iCurrentBanIdent > 0)
	{
		new iPruned = fm_PruneTimedBans(g_BanList)
		if (iPruned > 0)
		{
			fm_WriteBanFile(g_BanList, g_sBanFilePath, g_iCurrentBanIdent)
		}

		log_amx("Loaded %d bans from \"%s\"", ArraySize(g_BanList), g_sBanFilePath)

		register_concmd("admin_ban", "Admin_Ban", ADMIN_MEMBER, "<target|steamid> [length] [reason]")
		register_concmd("admin_unban", "Admin_UnBan", ADMIN_MEMBER, "<steamid>")
		register_concmd("admin_listbans", "Admin_ListBans", ADMIN_MEMBER)
	}
	else
	{
		fm_WarningLog("g_iCurrentBanIdent <= 0 (%d)", g_iCurrentBanIdent)
	}

	register_concmd("addbansfromtxt", "ReadTempBanTxt")
}

public client_authorized(id)
{
	new BanInfo[eBanInfo_t], sAuthid[MAX_AUTHID_LEN]
	get_user_authid(id, sAuthid, charsmax(sAuthid))

	if (fm_GetBanInfoByAuth(g_BanList, sAuthid, BanInfo) != -1)
	{
		if (fm_HasTimedBanExpired(BanInfo))
		{
			fm_RemoveBanByIdent(g_BanList, fm_GetBanIdent(BanInfo))
			fm_WriteBanFile(g_BanList, g_sBanFilePath, g_iCurrentBanIdent)	
		}
		else
		{
			new sLength[64]; fm_FormatBanLength(BanInfo, sLength, charsmax(sLength))
			server_cmd("kick #%d \"You are banned %s\"", get_user_userid(id), sLength)	
		}
	}
}

public Admin_ListBans(id, iLevel, iCommand)
{
	// Check the user has access
	if (!fm_CommandAccess(id, iLevel, true))
	{
		return PLUGIN_HANDLED
	}

	// Check and remove expired time bans before listing
	if (fm_PruneTimedBans(g_BanList) > 0)
	{
		fm_WriteBanFile(g_BanList, g_sBanFilePath, g_iCurrentBanIdent)
	}

	new iCount = ArraySize(g_BanList)
	new sArgs[8]; read_args(sArgs, charsmax(sArgs))
	new iStart = str_to_num(sArgs) - 1

	if (iStart < 0)
	{
		iStart = 0
	}

	if (iStart >= iCount)
	{
		iStart = iCount - 1
	}

	new iEnd = iStart + 10
	if (iEnd > iCount)
	{
		iEnd = iCount
	}

	new Buffer[eBanInfo_t], sType[128], AdminInfo[eAdmin_t]

	console_print(id, "\n\nCurrent Bans:")

	for (new i = iStart; i < iEnd; i++)
	{
		ArrayGetArray(g_BanList, i, Buffer)

		fm_GetAdminInfoByIdent(Buffer[m_iBanAdmin], AdminInfo)
		fm_FormatBanType(Buffer, sType, charsmax(sType))
		console_print(id, "#%d %s<%s> %s - Admin: #%d %s - Reason: %s",  Buffer[m_iBanIdent], Buffer[m_sBanName], Buffer[m_sBanAuthid], sType, Buffer[m_iBanAdmin], AdminInfo[m_sAdminName], Buffer[m_sBanReason])
	}

	if (iEnd < iCount)
	{
		console_print(id, "Displaying bans %d to %d. Type \"admin_listbans %d\" for more\n", iStart + 1, iEnd, iEnd + 1)
	}

	return PLUGIN_HANDLED
}

// admin_unban <steamid>
public Admin_UnBan(id, iLevel, iCommand)
{
	// Check the user has access and entered the correct number of parameters
	if (!fm_CommandAccess(id, iLevel, true) || !fm_CommandUsage(id, iCommand, 2))
	{
		return PLUGIN_HANDLED
	}

	// Check the user entered a steam ID
	new sArgs[192]; read_args(sArgs, charsmax(sArgs))
	trim(sArgs)

	if (!equal(sArgs, "STEAM_", 6)) 
	{
		console_print(id, "Please provide a valid steam ID to unban")
		return PLUGIN_HANDLED
	}

	// Check the steam ID has been banned
	new BanInfo[eBanInfo_t], iIndex = fm_GetBanInfoByAuth(g_BanList, sArgs, BanInfo)
	if (iIndex == -1)
	{
		console_print(id, "No ban found for \"%s\"", sArgs)	
		return PLUGIN_HANDLED
	}			

	// Remove the ban from the array and update the ban file
	fm_RemoveBanByIndex(g_BanList, iIndex)
	fm_WriteBanFile(g_BanList, g_sBanFilePath, g_iCurrentBanIdent)

	// Notify user/clients
	new sAdminName[MAX_NAME_LEN]; get_user_name(id, sAdminName, charsmax(sAdminName))
	new sAdminAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAdminAuthid, charsmax(sAdminAuthid))
	new sAdminRealName[MAX_NAME_LEN]; fm_GetUserRealname(id, sAdminRealName, charsmax(sAdminRealName))
	
	client_print(0, print_chat, "* ADMIN #%d %s: unbanned %s<%s>", fm_GetUserIdent(id), sAdminRealName, BanInfo[m_sBanName], BanInfo[m_sBanAuthid])
	console_print(id, "You have unbanned %s<%s>", BanInfo[m_sBanName], BanInfo[m_sBanAuthid])
	log_amx("\"%s<%s>(%s)\" admin_unban \"%s<%s>\"", sAdminName, sAdminAuthid, sAdminRealName, BanInfo[m_sBanName], BanInfo[m_sBanAuthid])

	return PLUGIN_HANDLED
}

// admin_ban <target|steamid> <length> [reason]
public Admin_Ban(id, iLevel, iCommand) 
{
	// Check the user has access and entered the correct number of parameters
	if (!fm_CommandAccess(id, iLevel, true) || !fm_CommandUsage(id, iCommand, 2))
	{
		return PLUGIN_HANDLED
	}

	new sArgs[192], sTarget[64]; read_args(sArgs, charsmax(sArgs)) 
	strbreak(sArgs, sTarget, charsmax(sTarget), sArgs, charsmax(sArgs))

	new BanInfo[eBanInfo_t]

	// Try and find the target player
	new iPlayer = fm_CommandGetPlayer(id, sTarget)
	if (!iPlayer)
	{
		// Cannot find target, check if the user entered a steam ID
		if (!equal(sTarget, "STEAM_", 6)) 
		{
			return PLUGIN_HANDLED
		}

		console_print(id, "Banning via steam ID instead")

		// Check if the steam ID is banned
		new iIndex = fm_GetBanInfoByAuth(g_BanList, sTarget, BanInfo)
		if (iIndex != -1)
		{
			if (fm_HasTimedBanExpired(BanInfo))
			{
				fm_RemoveBanByIndex(g_BanList, iIndex)
				fm_WriteBanFile(g_BanList, g_sBanFilePath, g_iCurrentBanIdent)					
			}
			else
			{
				console_print(id, "%s is already banned:", sTarget)
				fm_PrintBanInfo(id, BanInfo)
				return PLUGIN_HANDLED
			}	
		}

		copy(BanInfo[m_sBanName], MAX_NAME_LEN - 1, "n/a")
		copy(BanInfo[m_sBanAuthid], MAX_AUTHID_LEN - 1, sTarget)
	}
	else
	{
		get_user_name(iPlayer, BanInfo[m_sBanName], MAX_NAME_LEN - 1)
		get_user_authid(iPlayer, BanInfo[m_sBanAuthid], MAX_AUTHID_LEN - 1)
		
		new iIndex = fm_GetBanInfoByAuth(g_BanList, BanInfo[m_sBanAuthid], BanInfo)
		if (iIndex != -1)
		{
			fm_WarningLog("Attempted to create a duplicate ban on player %s<%s>", BanInfo[m_sBanName], BanInfo[m_sBanAuthid])
			return PLUGIN_HANDLED
		}
	}

	new sLength[128]
	strbreak(sArgs, sLength, charsmax(sLength), BanInfo[m_sBanReason], MAX_REASON_LEN - 1)

	trim(BanInfo[m_sBanReason])
	if (!BanInfo[m_sBanReason][0])
	{
		copy(BanInfo[m_sBanReason], MAX_REASON_LEN - 1, "None")
	}
	
	new iLength
	if (sLength[0])
	{
		// check the user actually entered a number for the length
		if (!is_str_num2(sLength))
		{
			console_print(id, "Length must be a number")
			return PLUGIN_HANDLED
		}
		iLength = str_to_num(sLength) 
	}
	else
	{
		// If the the user didn't specify a length, default to map based ban
		iLength = -1
	}
	
	if (iLength < 0)
	{
		fm_SetBanType(BanInfo, BANTYPE_MAP)
		
	}
	else if (!iLength)
	{
		/*
		if (fm_GetUserAccess(id) & ADMIN_HIGHER)
		{
		*/
			fm_SetBanType(BanInfo, BANTYPE_PERMANENT)
		/*
		}
		else
		{
			console_print(id, "You do not have access to permanently ban players")
			return PLUGIN_HANDLED
		}
		*/
	}
	else
	{
		fm_SetBanType(BanInfo, BANTYPE_TIMED)

		if (iLength > MAX_BAN_LEN_MINS)
		{
			iLength = MAX_BAN_LEN_MINS
		}

		iLength *= 60 // Convert minutes to seconds
		BanInfo[m_iBanLength] = iLength
	}

	BanInfo[m_iBanIdent] = g_iCurrentBanIdent++
	BanInfo[m_iBanTime] = get_systime()
	BanInfo[m_iBanAdmin] = fm_GetUserIdent(id)

	// Add the ban to the array
	fm_AddBanByStruct(g_BanList, BanInfo)
	
	// Update the ban file if required
	if (fm_GetBanType(BanInfo) != BANTYPE_MAP)
	{
		fm_WriteBanFile(g_BanList, g_sBanFilePath, g_iCurrentBanIdent)
	}

	// Kick the target player if they are connected
	fm_FormatBanLength(BanInfo, sLength, charsmax(sLength))
	if (iPlayer)
	{
		server_cmd("kick #%d \"You are banned %s\"", get_user_userid(iPlayer), sLength)
	}

	// Notify user/clients
	new sAdminName[MAX_NAME_LEN]; get_user_name(id, sAdminName, charsmax(sAdminName))
	new sAdminAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAdminAuthid, charsmax(sAdminAuthid))
	new sAdminRealName[MAX_NAME_LEN]; fm_GetUserRealname(id, sAdminRealName, charsmax(sAdminRealName))

	client_print(0, print_chat, "* ADMIN #%d %s: banned %s<%s> %s Reason: %s", fm_GetUserIdent(id), sAdminRealName, BanInfo[m_sBanName], BanInfo[m_sBanAuthid], sLength, BanInfo[m_sBanReason])
	console_print(id, "You have banned %s<%s> %s", BanInfo[m_sBanName], BanInfo[m_sBanAuthid], sLength)
	log_amx("\"%s<%s>(%s)\" admin_ban \"%s<%s>\" %s", sAdminName, sAdminAuthid, sAdminRealName, BanInfo[m_sBanName], BanInfo[m_sBanAuthid], sLength)

	return PLUGIN_HANDLED
}

public plugin_end()
{
	if (g_BanList != Invalid_Array)
	{
		ArrayDestroy(g_BanList)
	}
}

public ReadTempBanTxt(id)
{
	new iFileHandle = fopen("banlistedit.txt", "rt")
	if (iFileHandle)
	{
		new sData[512]

		while (!feof(iFileHandle))
		{
			fgets(iFileHandle, sData, charsmax(sData))
			trim(sData) // Clean spaces and line breaks from either end

			new BanInfo[eBanInfo_t]
			strtok(sData, BanInfo[m_sBanName], MAX_NAME_LEN -1, sData, charsmax(sData), ';')
			strtok(sData, BanInfo[m_sBanAuthid], MAX_AUTHID_LEN - 1, sData, charsmax(sData), ';')

			new iIndex = fm_GetBanInfoByAuth(g_BanList, BanInfo[m_sBanAuthid], BanInfo)
			if (iIndex != -1)
			{
				console_print(id, "Ban \"%s\" already exists", BanInfo[m_sBanAuthid])
				continue
			}

			strtok(sData, BanInfo[m_sBanReason], MAX_REASON_LEN - 1, sData, charsmax(sData), ';')

			new sBuffer[32]
			strtok(sData, sBuffer, charsmax(sBuffer), sData, charsmax(sData), ';')		
			BanInfo[m_iBanAdmin] = str_to_num(sBuffer)

			strtok(sData, sBuffer, charsmax(sBuffer), sData, charsmax(sData), ';')	
			BanInfo[m_iBanTime] = str_to_num(sBuffer)

			BanInfo[m_iBanType] = BANTYPE_PERMANENT
			BanInfo[m_iBanIdent] = g_iCurrentBanIdent++

			fm_AddBanByStruct(g_BanList, BanInfo)
		}
		fm_WriteBanFile(g_BanList, g_sBanFilePath, g_iCurrentBanIdent)
	}
}