#if defined _fm_global_included
  #endinput
#endif
#define _fm_global_included

#pragma ctrlchar '\'
#include <amxmodx>

#define MAX_PLAYERS 18 // [FM] Max. 
#define MAX_MAP_LEN 32
#define MAX_NAME_LEN 32
#define MAX_AUTHID_LEN 36
#define MAX_HUDMSG_LEN 480
#define MAX_RESOURCE_LEN 64 // sdk/engine/custom.h
#define MAX_CHAT_LEN 128
#define MAX_CONSOLE_LEN 128
#define MAX_HASH_LEN 34
#define MAX_SERVER_PRINT_LEN 255 // Pretty sure it crashes if more than this because amxx does checks in server_print

stock const FM_FOPEN_WARNING[] = "Failed to open file: \"%s\""
stock const FM_ENT_WARNING[] = "Failed to create entity"
stock const FM_LINE_WARNING[] = "Line #%d in \"%s\" is incomplete"
stock const FM_VAULT_WARNING[] = "Failed to open vault: \"%s\""
stock const FM_LICENSE_WARNING[] = "License key not valid"
stock const FM_FORWARD_WARNING[] = "Failed to create forward: \"%s\""

stock const FM_AMXX_LOCAL_CONFIGS[] = "amxx_configsdir"
stock const FM_AMXX_LOCAL_DATA[] = "amxx_datadir"

#define fm_ValidPlayer(%1) (1<=(%1)<=MAX_PLAYERS)
#define fm_PrintStar(%1) ((%1 == print_chat) ? "* " : "")
#define fm_Comment(%1) (!%1[0] || %1[0] == ';' || %1[0] == '#' || (%1[0] == '/' && %1[1] == '/' ))

#include "feckinmad/fm_debug" // A lot of plugins will use this. Also Required for fm_RegisterPlugin() included below
#include "feckinmad/fm_register_plugin"  // Every plugin will need this, also need FM_SCRIPT_NAME for fm_WarningLog

stock fm_GetRealPlayerNum()
{
	new iCount
	for (new i = 1, iMaxPlayers = get_maxplayers(); i <= iMaxPlayers; i++)
		if (is_user_connected(i) && !is_user_bot(i) && !is_user_hltv(i))
			iCount++
	return iCount
}

stock fm_BuildAMXFilePath(const sFile[], sStringOut[], iStringOutLen, const sLocalDir[])
{
	new sDirectory[64]; get_localinfo(sLocalDir, sDirectory, charsmax(sDirectory))
	formatex(sStringOut, iStringOutLen, "%s/%s", sDirectory, sFile)
}

stock fm_WarningLog(const sFormat[], any:...)
{
	static sMessage[512]; sMessage[0] = '\0'
	vformat(sMessage, charsmax(sMessage), sFormat, 2)

	new sLogFile[32]; get_time("warning_%Y%m%d.log", sLogFile, charsmax(sLogFile))
	log_to_file(sLogFile, "[%s] %s", FM_SCRIPT_NAME, sMessage)
	return 0
}

stock fm_PlaySound(id, const sSound[])
{
	client_cmd(id, "spk %s", sSound) // "play" plays at an origin so use "spk"
}

stock fm_CommandUsage(id, iCommand, iNum, iClient = 0)
{
	if (read_argc() < iNum)
	{
		new sCommand[32], sInfo[128], iFlag, iLevel
		if (iClient)
		{
			get_clcmd (iCommand, sCommand, charsmax(sCommand), iFlag, sInfo, charsmax(sInfo), iLevel)
		}
		else
		{
			get_concmd(iCommand, sCommand, charsmax(sCommand), iFlag, sInfo, charsmax(sInfo), iLevel)
		}

		console_print(id, "Not enough arguments supplied. Usage: %s %s", sCommand, sInfo)
		return 0
	}
	return 1
}


stock fm_CopyStruc(eStruct1[], eStruct2[], iStructLen)
{
	for (new i = 0; i <= iStructLen; i++)
	{
		eStruct2[i] = eStruct1[i]
	}
}

// Fix for is_str_num not detecting - or + by danielkza
stock bool:is_str_num2(const sString[])
{
	new i = 0, bool:bSigned

	if(sString[0] == '-' || sString[0] == '+')
	{
		bSigned = true
		++i
	}
	
	while (sString[i] && isdigit(sString[i]))
		++i

	return sString[i] == 0 && (!bSigned ? i != 0 : i > 1)
}

stock fm_GetFileNameFromPath(sPath[])
{
	for (new i = strlen(sPath); i >= 0; i--)
		if (sPath[i] == '\\' || sPath[i] == '/')
			return i + 1
	return 0
}

stock fm_FormatPosition(iNum, sPosition[], iLen) 
{
	if (iNum < 11 || iNum > 13)
	{
		switch(iNum % 10)
		{
			case 1: return formatex(sPosition, iLen, "%dst", iNum)
			case 2: return formatex(sPosition, iLen, "%dnd", iNum)
			case 3: return formatex(sPosition, iLen, "%drd", iNum)
		}
	}
	return formatex(sPosition, iLen, "%dth", iNum)
}