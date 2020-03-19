#include "feckinmad/fm_global"
#include "feckinmad/fm_mapfile_api"
#include "feckinmad/fm_mapfunc"
#include "feckinmad/fm_time"
#include "feckinmad/mapvote/fm_mapvote_mapmenu"

#define NOMINATION_DELAY 3.0
#define MAX_MAP_SLOTS 10 // Maximum number of maps that can appear in the vote

new g_sCurrentMap[MAX_MAP_LEN], g_iMaxPlayers
new Float:g_fPlayerNextNomination[MAX_PLAYERS + 1] // Gametime a player can next nominate a map

new g_sNominatedMapList[MAX_MAP_SLOTS][MAX_MAP_LEN] // Nominated maps
new g_iNominatedMapPlayer[MAX_MAP_SLOTS] = { -1, ...} // The player that nominated the map
new Float:g_fNominatedTime[MAX_MAP_SLOTS]// Gametime the nomination was made

public fm_PluginInit() 
{
	get_mapname(g_sCurrentMap, charsmax(g_sCurrentMap))
	g_iMaxPlayers = get_maxplayers()

	register_clcmd("say","Handle_Say")
	register_clcmd("say_team","Handle_Say")

	register_concmd("fm_setnomination", "Server_SetNomination")

	// Add the extend currentmap nomination to the last nomination slot
	SetNomination(0, MAX_MAP_SLOTS - 1, g_sCurrentMap)
}

public Server_SetNomination(id)
{
	if (id == (is_dedicated_server() ? 0 : 1))
	{
		new sArg1[2]; read_argv(1, sArg1, charsmax(sArg1))
		new iIndex = str_to_num(sArg1)

		if (iIndex < 1 || iIndex > MAX_MAP_SLOTS)
			return PLUGIN_HANDLED
	
		new sArg2[MAX_MAP_LEN]; read_argv(2, sArg2, charsmax(sArg2))

		if (!is_map_valid(sArg2) || GetNominatedMapIndex(sArg2) != -1 || g_sNominatedMapList[iIndex-1][0]) 
			return PLUGIN_HANDLED

		SetNomination(0, iIndex-1, sArg2)
		
		log_amx("Set nomination slot %d to \"%s\"", iIndex, sArg2)
	}
	return PLUGIN_HANDLED
}

public plugin_natives()
{
	register_native("fm_GetNominatedMapByIndex", "Native_GetNominatedMapByIndex")
	register_native("fm_NominateMap", "Native_NominateMap")
	register_native("fm_IsMapNominated", "Native_IsMapNominated")
	register_native("fm_PrintNominations", "Native_PrintNominations")

	register_library("fm_mapvote_nominate")
}

public Native_NominateMap()
{
	new id = get_param(1)

	if (id < 1 || id > g_iMaxPlayers)
	{
		log_error(AMX_ERR_NATIVE, "Player out of range (%d)", id)
		return 0
	}

	if (!is_user_connected(id))
	{
		log_error(AMX_ERR_NATIVE, "Invalid player (%d)", id)
		return 0
	}

	new sMap[MAX_MAP_LEN]; get_string(2, sMap, charsmax(sMap))
	Nominate(id, sMap)
	return 1
}

public Native_IsMapNominated()
{
	new sMap[MAX_MAP_LEN]; get_string(1, sMap, charsmax(sMap))
	return GetNominatedMapIndex(sMap) != -1 ? 1 : 0
}

public Native_PrintNominations()
	PrintNominatedMaps()

PrintNominatedMaps()
{	
	// Build a list of nominations
	new iNominationIndexList[MAX_MAP_SLOTS]
	new iNominationCount
	for (new i = 0; i < MAX_MAP_SLOTS; i++)
		if (g_sNominatedMapList[i][0] && g_iNominatedMapPlayer[i] != 0) // Ignore server nominations
			iNominationIndexList[iNominationCount++] = i
	
	if (!iNominationCount)
		client_print(0, print_chat, "* No maps have been nominated so far, type \"nominate <mapname>\" to nominate a map") 	
	else
	{
		new sBuffer[128], i, iIndex
		new iLen = formatex(sBuffer, charsmax(sBuffer), "* Maps nominated for voting: ")

		while(i < iNominationCount)
		{		
			iIndex = iNominationIndexList[i]
	
			if (charsmax(sBuffer) - iLen < strlen(g_sNominatedMapList[iIndex]) + 2)
			{
				client_print(0, print_chat, sBuffer)
				sBuffer[0] = iLen = 0 
			}
			else
			{
				iLen += add(sBuffer[iLen], charsmax(sBuffer) - iLen, g_sNominatedMapList[iIndex])
				switch (iNominationCount - ++i)
				{
					case 0: client_print(0, print_chat, sBuffer)
					case 1: iLen += add(sBuffer[iLen], charsmax(sBuffer) - iLen, " & ")
					default: iLen += add(sBuffer[iLen], charsmax(sBuffer) - iLen, ", ")
				}	
			}			
		}
	}
}

public Native_GetNominatedMapByIndex()
{
	new iIndex = get_param(1)
	if (iIndex < 0 || iIndex >= MAX_MAP_SLOTS)
	{
		log_error(AMX_ERR_NATIVE, "Invalid nominated map index (%d)", iIndex)
		return 0
	}

	if (!g_sNominatedMapList[iIndex][0])
		return 0

	set_string(2, g_sNominatedMapList[iIndex], get_param(3))
	return 1
}


GetNominatedMapIndex(sMap[])
{ 
	for(new i = 0; i < MAX_MAP_SLOTS; i++)
		if(equali(sMap, g_sNominatedMapList[i])) 
			return i
	return -1
}


SetNomination(id, iIndex, sMap[])
{
	fm_DebugPrintLevel(1, "SetNomination(%d, %d, %s)", id, iIndex, sMap)

	copy(g_sNominatedMapList[iIndex], MAX_MAP_LEN - 1, sMap)
	g_iNominatedMapPlayer[iIndex] = id

	new Float:fGameTime = get_gametime()
	g_fPlayerNextNomination[id] = fGameTime + NOMINATION_DELAY
	g_fNominatedTime[iIndex] = fGameTime
}

RemoveNomination(iIndex)
{
	fm_DebugPrintLevel(1, "RemoveNomination(%d)", iIndex)

	g_sNominatedMapList[iIndex][0] = 0
	g_iNominatedMapPlayer[iIndex] = -1
	g_fNominatedTime[iIndex] = 0.0
}

GetFreeNominationSlot()
{
	fm_DebugPrintLevel(1, "GetFreeNominationSlot()")

	for (new i = 0; i < MAX_MAP_SLOTS; i++)
		if (!g_sNominatedMapList[i][0])
			return i
	return -1
}

CanUserNominate(id, sMap[])
{
	new iReturn, iForward = CreateMultiForward("fm_CanUserNominate", ET_STOP, FP_CELL, FP_STRING)
	ExecuteForward(iForward, iReturn, id, sMap)
	if (iReturn == PLUGIN_HANDLED)
	{
		return 0
	}
	return 1
}

Nominate(id, sMap[])
{  	
	if (equali(sMap, g_sCurrentMap)) 
	{
		client_print(id, print_chat, "* This map is \"%s\". A vote will determine whether or not the map is extended", sMap)
		return 0
	}

	if (!CanUserNominate(id, sMap))
	{
		return 0
	}

	if (!fm_IsMapInMapsFile(sMap))
	{
		client_print(id, print_chat, "* Map \"%s\" is not availiable for vote", sMap)
		return 0
	}

	new sName[MAX_NAME_LEN]

	new iNominationIndex = GetNominatedMapIndex(sMap)
	if (iNominationIndex != -1) // Check if the map is already nominated
	{
		// Find out who nominated it
		new iNominationPlayer = g_iNominatedMapPlayer[iNominationIndex]

		if (iNominationPlayer == id)
			client_print(id, print_chat, "* You have already nominated \"%s\"", sMap)

		else if (iNominationPlayer > 0 && iNominationPlayer <= g_iMaxPlayers)
		{
			get_user_name(iNominationPlayer, sName, charsmax(sName)) 
			client_print(id, print_chat, "* \"%s\" has already been nominated by \"%s\"", sMap, sName) 
		}
		else // This should only occur if a map nomination that was set by the server is also in the maplist.
			client_print(id, print_chat, "* \"%s\" has already been nominated", sMap, sName)

		return 0
	}

	// Enforce nomination delay to avoid a malicious player spamming a load of shitty maps with a bind just before the selection menu appears
	new Float:fGameTime = get_gametime()
	if (g_fPlayerNextNomination[id] > fGameTime)
	{
		new sTime[64]; fm_SecondsToText(floatround(g_fPlayerNextNomination[id] - fGameTime, floatround_ceil), sTime, charsmax(sTime))
		client_print(id, print_chat, "* Please wait another %s before making another nomination", sTime) 
		return 0
	}

	strtolower(sMap) // More consistent for case sensitive http downloads

	new iIndex = GetFreeNominationSlot() // Check if there is room for the new nomination
	if (iIndex != -1)
	{
		new sName[32]; get_user_name(id, sName, charsmax(sName))
		client_print(0, print_chat,"* %s has nominated \"%s\"", sName, sMap)

		SetNomination(id, iIndex, sMap)
		return 1
	}
	else
	{
		// Build the array of nomination counts for each player
		new iPlayerNominationCount[MAX_PLAYERS + 1]
		for (new i = 0; i < MAX_MAP_SLOTS; i++)
			if (g_iNominatedMapPlayer[i] != -1)
				iPlayerNominationCount[i]++

		// Build a list of players with the most nominations. 
		new iHighestNominationCount // Highest nomination count by a player
		new iHighestNominaters[MAX_PLAYERS] = { -1, ... } // Player(s) with the most nominations
		new iHighestCount // Number of players in the above list

		for (new i = 1; i <= g_iMaxPlayers; i++) // Not including nominations set by the server, as these are not to be replaced
		{
			if (iHighestNominationCount < iPlayerNominationCount[i])
			{
				iHighestNominationCount = iPlayerNominationCount[i]
				iHighestNominaters[0] = i
				iHighestCount = 1
			}
			else if (iPlayerNominationCount[i] > 0 && iHighestNominationCount == iPlayerNominationCount[i]) 
				iHighestNominaters[iHighestCount++] = i 
		}
		
		// Check that there are players in the list
		if (!iHighestCount)
		{
			// This could occur if the nomination list consists solely of maps nominated by the server
			client_print(id, print_chat, "* Sorry, there are no free nomination slots")
			return 0
		}
		
		new iTarget // The player whose nomination we are going to replace

		// Replace their own nomination if will join the player(s) with the most nominations
		if (iPlayerNominationCount[id] + 1 >= iHighestNominationCount)
			iTarget = id 
		else
			iTarget = iHighestNominaters[random(iHighestCount)] 

		// Replace the oldest nomination by the selected target
		new Float:fOldest
		for (new i = 0; i < MAX_MAP_SLOTS; i++)
		{
			if (g_iNominatedMapPlayer[i] == iTarget && (g_fNominatedTime[i] < fOldest || iIndex == -1))
			{
				iIndex = i
				fOldest = g_fNominatedTime[i]
			}
		}

		get_user_name(id, sName, charsmax(sName))
		new sTargetName[MAX_NAME_LEN]; get_user_name(iTarget, sTargetName, charsmax(sTargetName))

		if (id == iTarget)
			client_print(0, print_chat,"* %s has nominated \"%s\". Replacing their own nomination of \"%s\" to make room", sName, sMap, g_sNominatedMapList[iIndex])
		else
			client_print(0, print_chat,"* %s has nominated \"%s\". Replacing the nomination of \"%s\" by \"%s\" to make room", sName, sMap, g_sNominatedMapList[iIndex], sTargetName)
				
		SetNomination(id, iIndex, sMap)
	}

	return 1
}

public Handle_Say(id)
{  
	static sArgs[192]; read_args(sArgs, charsmax(sArgs)) 
	remove_quotes(sArgs)
	trim(sArgs)
	if (!sArgs[0]) 
		return PLUGIN_CONTINUE

	if (equali(sArgs, "nominations"))
	{
		if (CanUserNominate(id, ""))
		{
			PrintNominatedMaps()
		}
	}
	else if(equali(sArgs, "nominate", 8))
	{		
		if (!sArgs[8]) 
		{
			fm_ShowMapMenu(id)
			return PLUGIN_HANDLED
		}
		
		if (sArgs[8] == ' ')
		{
			if (!sArgs[9])
			{
				client_print(id, print_chat, "* You must supply a map name to nominate. e.g. \"nominate 2fort\"")
				return PLUGIN_HANDLED
			}
			else if (!is_map_valid(sArgs[9]))
			{
				client_print(id, print_chat, "* Map: \"%s\" does not exist", sArgs[9])
				return PLUGIN_HANDLED
			}
			else if (!Nominate(id, sArgs[9]))
				return PLUGIN_HANDLED			
		}
	}
	else if (read_argc() == 2 && fm_IsMapValid(sArgs))
	{
		if(!Nominate(id, sArgs))
			return PLUGIN_HANDLED 
	}
	return PLUGIN_CONTINUE
}

public client_disconnected(id)
{
	g_fPlayerNextNomination[id] = 0.0

	// Build a list of the nominations by this player
	new iPlayerNominationList[MAX_MAP_SLOTS]
	new iPlayerNominationCount 
	for (new i = 0; i < MAX_MAP_SLOTS; i++)
		if (g_iNominatedMapPlayer[i] == id)
			iPlayerNominationList[iPlayerNominationCount++] = i

	if (iPlayerNominationCount > 0)
	{
		// Print the list of nominations removed due to this player leaving the game
		new sBuffer[128], i, iIndex
		new iLen = formatex(sBuffer, charsmax(sBuffer), "* Removing nominations: ")

		while(i < iPlayerNominationCount)
		{		
			iIndex = iPlayerNominationList[i]
	
			if (charsmax(sBuffer) - iLen < strlen(g_sNominatedMapList[iIndex]) + 2)
			{
				client_print(0, print_chat, sBuffer)
				sBuffer[0] = iLen = 0 
			}
			else
			{
				iLen += add(sBuffer[iLen], charsmax(sBuffer) - iLen, g_sNominatedMapList[iIndex])
				switch (iPlayerNominationCount - ++i)
				{
					case 0: client_print(0, print_chat, sBuffer)
					case 1: iLen += add(sBuffer[iLen], charsmax(sBuffer) - iLen, " & ")
					default: iLen += add(sBuffer[iLen], charsmax(sBuffer) - iLen, ", ")
				}	
			}			
		}

		// Remove the nomination
		for (new i = 0; i < iPlayerNominationCount; i++)
			RemoveNomination(iPlayerNominationList[i])
	}
	return PLUGIN_CONTINUE
}
