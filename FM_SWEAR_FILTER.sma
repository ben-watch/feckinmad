#include "feckinmad/fm_global"

#include <nvault>

#define MAX_BAD_WORDS 64
#define MAX_BAD_WORD_LEN 32

new const g_sBadWordFile[] = "fm_chat_filter.ini"

new g_sBadWords[MAX_BAD_WORDS][MAX_BAD_WORD_LEN] // List of bad words loaded from the file
new g_iBadWordLen[MAX_BAD_WORDS] // Length of each bad word
new g_iBadWordCount // Number of bad words loaded

new const g_sVaultName[] = "fm_player_chat_filter"
new g_iVault = INVALID_HANDLE

new bool:g_bPlayerChatFilter[MAX_PLAYERS + 1]
new Float:g_fPlayerNextToggle[MAX_PLAYERS + 1]

public plugin_init()
{
	fm_RegisterPlugin()

	ReadBadWordFile()

	register_message(get_user_msgid("SayText"), "Handle_SayText")

	register_clcmd("say /swear", "Toggle_Swear")
	register_clcmd("say_team /swear", "Toggle_Swear")

	g_iVault = nvault_open(g_sVaultName)
	if (g_iVault != INVALID_HANDLE)
		nvault_prune(g_iVault, 0, get_systime() - 7776000) // 90 days
	else
	{
		fm_WarningLog(FM_VAULT_WARNING, g_sVaultName)
		set_fail_state("Failed to open vault")
	}

	return PLUGIN_CONTINUE
}

ReadBadWordFile()
{
	new sFile[128]; fm_BuildAMXFilePath(g_sBadWordFile, sFile, charsmax(sFile), "amxx_configsdir")
	new iFileHandle = fopen(sFile, "rt")
	if (!iFileHandle)
	{	
		fm_WarningLog(FM_FOPEN_WARNING, sFile)
		set_fail_state("Failed to open file")
		return 0
	}

	new sData[32]
	while (!feof(iFileHandle))
	{
		fgets(iFileHandle, sData, charsmax(sData))
		trim(sData)

		if(!sData[0] || sData[0] == ';' || sData[0] == '#' || equal(sData, "//", 2))
			continue

		if (g_iBadWordCount >= MAX_BAD_WORDS)
		{
			fm_WarningLog("Maximum bad words reached")	
			break
		}
		
		copy(g_sBadWords[g_iBadWordCount], MAX_BAD_WORD_LEN - 1, sData)
		g_iBadWordLen[g_iBadWordCount] = strlen(sData) // Cache the length so save repeatedly calling strlen later
		g_iBadWordCount++

	}
	fclose(iFileHandle)
	return 1
}

public client_putinserver(id)
{
	if (g_iVault == INVALID_HANDLE)
		return PLUGIN_CONTINUE

	if (is_user_bot(id) || is_user_hltv(id))
		return PLUGIN_CONTINUE

	new sAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAuthid, charsmax(sAuthid))
	g_bPlayerChatFilter[id] = nvault_get(g_iVault, sAuthid) ? true : false

	// Update the timestamp
	if (g_bPlayerChatFilter[id])
		nvault_touch(g_iVault, sAuthid)

	return PLUGIN_CONTINUE
}

public client_disconnect(id)
{
	g_bPlayerChatFilter[id] = false
	g_fPlayerNextToggle[id] = 0.0
}

public Handle_SayText(iMsgId, iDest, iReciever)
{
	if (!g_bPlayerChatFilter[iReciever])
		return PLUGIN_CONTINUE

	new sArgs[MAX_CHAT_LEN]; get_msg_arg_string(2, sArgs, charsmax(sArgs))

	new iSender = get_msg_arg_int(1)
	new sName[MAX_NAME_LEN]; get_user_name(iSender, sName, charsmax(sName))
	new iStart = strlen(sName)

	new i, iPos, iLen
	while (i < g_iBadWordCount)
	{
		iPos = containi(sArgs[iStart], g_sBadWords[i])
		if (iPos != -1)
		{
			iLen = g_iBadWordLen[i]
			while (iLen--) sArgs[iStart + iPos++] = '*'
			continue // Continue without incrementing incase the bad word is in the string more than once		
		}
		i++
	}

	set_msg_arg_string(2, sArgs)
	return PLUGIN_CONTINUE	
}

public Toggle_Swear(id)
{
	fm_DebugPrintLevel(1, "Toggle_Swear(%d)", id)

	new Float:fGameTime = get_gametime()

	if (g_fPlayerNextToggle[id] < fGameTime)
	{
		new sAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAuthid, charsmax(sAuthid))	

		if (g_bPlayerChatFilter[id])
		{
			g_bPlayerChatFilter[id] = false
			nvault_remove(g_iVault, sAuthid)
		}
		else
		{		
			g_bPlayerChatFilter[id] = true
			nvault_set(g_iVault, sAuthid, "1")
		}
	
		client_print(id, print_chat, "* Offensive words will now be %s on your client", g_bPlayerChatFilter[id] ? "hidden" : "visible")
		g_fPlayerNextToggle[id] = fGameTime + 1.0
	}
	return PLUGIN_HANDLED
}
