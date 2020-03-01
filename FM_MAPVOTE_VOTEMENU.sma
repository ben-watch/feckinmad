#include "feckinmad/fm_global"
#include "feckinmad/fm_menu"
#include "feckinmad/fm_precache"
#include "feckinmad/fm_mapfile_api"
#include "feckinmad/mapvote/fm_mapvote_nominate"
#include "feckinmad/mapvote/fm_mapvote_changelevel"
#include "feckinmad/mapvote/fm_mapvote_previous"

#include <fakemeta>

#define MAX_MAP_SLOTS 10 // Maximum number of maps that can appear in the vote

new const g_sSoundNominate[] = "fm/mapvote/nominate.wav"
new const g_sSoundGetReady[] = "fm/mapvote/getready.wav"
new const g_sSoundCountdown[] = "fm/mapvote/countdown.wav" 
new const g_sSoundVoteStart[] = "fm/mapvote/startvote.wav"
new const g_sSoundRemain[] = "fm/mapvote/remain.wav"
new const g_sSoundChange[] = "fm/mapvote/change.wav"
new const g_sSoundRevote[] = "fm/mapvote/revote.wav"

stock const g_sTextNextMap[] = "* Players have voted for \"%s\" as the next map and it will be loaded shortly"
stock const g_sTextInProgress[] = "Map voting is currently in progress"

enum {
	VOTING_INACTIVE, // Nothing is happening
	VOTING_STARTING, // Vote is starting up. Countdown etc
	VOTING_SELECT, // Vote has started. Players are selecting the map
	VOTING_CHANGING // Players have selected to change the map
}

new g_iVotingStatus = VOTING_INACTIVE
new g_iRemainingVoteTime // Seconds left to vote
new g_iVoteTime = 20

new g_sVoteMaps[MAX_MAP_SLOTS][MAX_MAP_LEN] // Maps in the vote
new g_iMapVotes[MAX_MAP_SLOTS]  // Vote count for each map

new g_sCurrentMap[MAX_MAP_LEN], g_sNextMap[MAX_MAP_LEN]
new g_iMaxPlayers

//----------------------------------------------------------------------------------------------------
// Precache the sounds used by the vote plugin
// Technically these do not need to be precached as they are playing locally
// But I just do it so clients download the files
//----------------------------------------------------------------------------------------------------

public plugin_precache()
{
	fm_SafePrecacheSound(g_sSoundNominate)
	fm_SafePrecacheSound(g_sSoundGetReady)
	fm_SafePrecacheSound(g_sSoundCountdown)
	fm_SafePrecacheSound(g_sSoundVoteStart)
	fm_SafePrecacheSound(g_sSoundRemain)
	fm_SafePrecacheSound(g_sSoundChange)
	fm_SafePrecacheSound(g_sSoundRevote)
}

public plugin_init() 
{
	fm_RegisterPlugin()
	get_mapname(g_sCurrentMap, charsmax(g_sCurrentMap))	
	register_menucmd(register_menuid("Choose the next map"), ALL_MENU_KEYS, "Command_MapVote")
	g_iMaxPlayers = get_maxplayers()
}

//----------------------------------------------------------------------------------------------------
// Forwards from the FM_MAPVOTE_ROCKTHEVOTE plugin
//----------------------------------------------------------------------------------------------------

//----------------------------------------------------------------------------------------------------
// Called when a player rocksthevote
// Return PLUGIN_CONTINUE to allow the rock to continue, PLUGIN_HANDLED to block the rock
//----------------------------------------------------------------------------------------------------
public fm_UserRockVote(id)
{
	//----------------------------------------------------------------------------------------------------
	// Check if it's a player rocking the vote
	//----------------------------------------------------------------------------------------------------

	if (1 <= id <= g_iMaxPlayers)
	{
		switch(g_iVotingStatus)		
		{
			case VOTING_CHANGING: client_print(id, print_chat, g_sTextNextMap, g_sNextMap)
			case VOTING_STARTING, VOTING_SELECT: client_print(id, print_chat, "* %s", g_sTextInProgress)
			default: return PLUGIN_CONTINUE
		}
	}

	//----------------------------------------------------------------------------------------------------
	// Else allow the server to rock as long as a mapvote isn't already running
	//----------------------------------------------------------------------------------------------------

	else if (g_iVotingStatus == VOTING_INACTIVE)
	{
		return PLUGIN_CONTINUE
	}

	return PLUGIN_HANDLED
}

//----------------------------------------------------------------------------------------------------
// Called when the number of rocks equals the required quota
//----------------------------------------------------------------------------------------------------
public fm_RockVoteQuotaReached()
{
	fm_PlaySound(0, g_sSoundNominate)
	client_print(0, print_chat, "* Nominate the map you want to play. Type \"nominate <mapname>\" or \"listmaps\" for full list")
	g_iVotingStatus = VOTING_STARTING

	set_task(10.0, "DisplayGetReady", 1)	
}


//----------------------------------------------------------------------------------------------------
// Forward from the FM_MAPVOTE_NOMINATE plugin
//----------------------------------------------------------------------------------------------------
public fm_CanUserNominate(id, sMap)
{
	if (1 <= id <= g_iMaxPlayers)
	{
		switch(g_iVotingStatus)		
		{
			case VOTING_CHANGING: client_print(id, print_chat, g_sTextNextMap, g_sNextMap)
			case VOTING_SELECT: client_print(id, print_chat, "* %s", g_sTextInProgress)
			default: return PLUGIN_CONTINUE
		}
	}
	else if (g_iVotingStatus == VOTING_STARTING || g_iVotingStatus == VOTING_INACTIVE)
	{
		return PLUGIN_CONTINUE	
	}

	return PLUGIN_HANDLED
}

public DisplayGetReady(iFill)
{
	fm_PrintNominations()
	fm_PlaySound(0, g_sSoundGetReady)
	client_print(0, print_chat, "* Get ready to vote for a map")

	set_task(5.0, "StartCountDown", iFill)
}

public StartCountDown(iFill)
{
	fm_PlaySound(0, g_sSoundCountdown)

	set_task(4.5, "StartVote", iFill)
}

public StartVote(iFill)
{
	fm_PlaySound(0, g_sSoundVoteStart)
	if (iFill)
		FillVote()

	g_iRemainingVoteTime = g_iVoteTime

	ShowVoteMenu()
	ShowHudMessage()

	g_iVotingStatus = VOTING_SELECT

	set_task(1.0, "VoteTimer", 0, "", 0, "a", g_iVoteTime + 1)
}

//----------------------------------------------------------------------------------------------------
// Fill the vote list with randomly selected maps
//----------------------------------------------------------------------------------------------------
FillVote()
{
	fm_DebugPrintLevel(1, "FillVote()")

	//----------------------------------------------------------------------------------------------------
	// Copy the entire maplist into a new dynamic array
	//----------------------------------------------------------------------------------------------------

	new Array:MapList = ArrayCreate(MAX_MAP_LEN)
	new sMap[MAX_MAP_LEN], iMapCount = fm_GetMapCount()
	for (new i = 0; i < iMapCount; i++)
	{
		fm_GetMapNameByIndex(i, sMap, charsmax(sMap))
		ArrayPushString(MapList, sMap)
	}

	//----------------------------------------------------------------------------------------------------
	// Loop through all the vote slots and attempt to fill them
	// Even if we run out of maps in the array, continue going since there may be nominated maps in any index
	//----------------------------------------------------------------------------------------------------

	new iRandom, bool:bDone
	for (new i = 0; i < MAX_MAP_SLOTS; i++)
	{
		//----------------------------------------------------------------------------------------------------
		// If no nomination exists in the slot...
		//----------------------------------------------------------------------------------------------------
		if (!fm_GetNominatedMapByIndex(i, sMap, charsmax(sMap)))
		{
			bDone = false

			//----------------------------------------------------------------------------------------------------
			// ...attempt to fill the vote slot with a random map...
			//----------------------------------------------------------------------------------------------------

			while (iMapCount > 0 && !bDone)
			{
				iRandom = random(iMapCount)
				ArrayGetString(MapList, iRandom, sMap, charsmax(sMap))

				//----------------------------------------------------------------------------------------------------
				// Check it isn't already nominated, played recently or the current map
				//----------------------------------------------------------------------------------------------------

				if (!fm_IsPreviousMap(sMap) && !fm_IsMapNominated(sMap) && !equal(g_sCurrentMap, sMap))
				{
					//----------------------------------------------------------------------------------------------------
					// Copy the randomly selected map into the vote slot
					//----------------------------------------------------------------------------------------------------

					copy(g_sVoteMaps[i], MAX_MAP_LEN - 1, sMap)
					bDone = true
				}

				//----------------------------------------------------------------------------------------------------
				// Delete the map from the array so it isn't selected again
				//----------------------------------------------------------------------------------------------------

				ArrayDeleteItem(MapList, iRandom)
				iMapCount--
			}
		}
		else
		{
			//----------------------------------------------------------------------------------------------------
			// ...else copy the nominated map into the vote slot
			//----------------------------------------------------------------------------------------------------

			copy(g_sVoteMaps[i], MAX_MAP_LEN - 1, sMap)
		}
	}
	ArrayDestroy(MapList)
}

ShowVoteMenu()
{
	fm_DebugPrintLevel(1, "ShowVoteMenu()")

	new sMenuBody[512], iMenuKeys

	new iLen = formatex(sMenuBody, charsmax(sMenuBody), "Choose the next map:\n")
	for (new i = 0; i < MAX_MAP_SLOTS; i++)
	{
		if (g_sVoteMaps[i][0]) // Skip unfilled slots
		{
			iLen += formatex(sMenuBody[iLen], charsmax(sMenuBody) - iLen, "\n%d) %s%s", fm_GetMenuKeyNum(i), equali(g_sVoteMaps[i], g_sCurrentMap) ? "extend " : "", g_sVoteMaps[i])
			iMenuKeys |= (1<<i)
		}
	}
	show_menu(0, iMenuKeys, sMenuBody, g_iVoteTime)
}

public Command_MapVote(id, iKey)
{ 
	fm_DebugPrintLevel(1, "Command_MapVote(%d, %d)", id, iKey)

	new sName[MAX_NAME_LEN]; get_user_name(id, sName, charsmax(sName))
	client_print(0, print_chat, "* %s voted for %d) %s%s", sName, fm_GetMenuKeyNum(iKey), equali(g_sVoteMaps[iKey], g_sCurrentMap) ? "extend " : "", g_sVoteMaps[iKey])		 
	g_iMapVotes[iKey]++	

	ShowHudMessage()

	fm_PlaySound(id, FM_MENU_SELECT_SOUND)
}

public VoteTimer()
{
	g_iRemainingVoteTime--

	if (g_iRemainingVoteTime < 0)
	{
		EvaluateVotes()
	}
	else
		ShowHudMessage()
}


ShowHudMessage()
{
	static sHudMessage[MAX_HUDMSG_LEN]

	new iLeadingMapIndexList[MAX_MAP_SLOTS] = { -1, ...}
	new iLeadingMapVotes[MAX_MAP_SLOTS]
	
	for (new i = 0; i < MAX_MAP_SLOTS; i++)
	{		
		if (!g_sVoteMaps[i][0])
			continue

		for (new j = 0; j < MAX_MAP_SLOTS; j++)
		{
			if (g_iMapVotes[i] > iLeadingMapVotes[j] || iLeadingMapIndexList[j] == -1)
			{	
				for (new k = MAX_MAP_SLOTS - 1; k > j ;k--) // Move everything down one place
				{
					iLeadingMapIndexList[k] = iLeadingMapIndexList[k - 1]
					iLeadingMapVotes[k] = iLeadingMapVotes[k - 1]	
				}		
				iLeadingMapIndexList[j] = i
				iLeadingMapVotes[j] = g_iMapVotes[i]	
				break
			}		
		}
	}

	new iLen = formatex(sHudMessage, charsmax(sHudMessage), "Results:\n\n")
	for (new i = 0, iIndex; i < MAX_MAP_SLOTS; i++)
	{
		iIndex = iLeadingMapIndexList[i]
		if (iIndex != -1)
			iLen += formatex(sHudMessage[iLen], charsmax(sHudMessage) - iLen, "%d) %s%s (votes: %d)\n", fm_GetMenuKeyNum(iIndex), equali(g_sVoteMaps[iIndex], g_sCurrentMap) ? "extend " : "", g_sVoteMaps[iIndex], g_iMapVotes[iIndex])		
	}

	iLen += formatex(sHudMessage[iLen], charsmax(sHudMessage) - iLen, "\nTimeleft: %d", g_iRemainingVoteTime)


	// Calculate the colour values to fade from green through to red as the time to vote runs out
	new Float:fHalfMax = g_iVoteTime / 2.0
	if (fHalfMax == 0.0) fHalfMax = 1.0

	new Float:fMultiplyer = 255.0 / fHalfMax
	new Float:fRemain = g_iRemainingVoteTime - fHalfMax

	new iRed   = fRemain > 0 ? 255 - floatround( fRemain * fMultiplyer) : 255
	new iGreen = fRemain < 0 ? 255 - floatround(-fRemain * fMultiplyer) : 255

	set_hudmessage(iRed, iGreen, 0, 0.6, 0.1, 0, 0.0, 600.0, 0.0, 0.0, 3)
	show_hudmessage(0, sHudMessage)	

	return 1
}


EvaluateVotes()
{
	fm_DebugPrintLevel(1, "EvaluateVotes()")

	// Build a list of maps with the most votes
	new iHighestMapVotes
	new iHighestMapList[MAX_MAP_SLOTS][MAX_MAP_LEN] // Store whole mapname as it means less fucking about later
	new iHighestCount, iCount, iZeroCount, iVotes

	for (new i = 0; i < MAX_MAP_SLOTS; i++)
	{
		// Ignore if map vote slot is empty
		if (!g_sVoteMaps[i][0])
			continue

		iVotes = g_iMapVotes[i]
		if (!iVotes) iZeroCount++

		if (iHighestMapVotes < iVotes)
		{
			iHighestMapVotes = iVotes
			copy(iHighestMapList[0], MAX_MAP_LEN - 1, g_sVoteMaps[i])
			iHighestCount = 1
		}
		else if (iHighestMapVotes == iVotes) 
			copy(iHighestMapList[iHighestCount++], MAX_MAP_LEN - 1, g_sVoteMaps[i])

		iCount++
	}


	// More than 1 map with top votes
	if (iHighestCount > 1) 
	{
		// If there are no votes, extend the map
		if (iZeroCount == iCount) 
		{
			for (new i = 0; i < iHighestCount; i++)
			{	
				// Check extend was actually an option in the vote. If not we fall through to selecting a random map from the vote
				if (!equal(iHighestMapList[i], g_sCurrentMap))
					continue

				VoteResult(iHighestMapList[i])
				return
			}
		}
		// If not all the maps that got votes are drawn, create a revote to allow the player(s) who selected a non drawing map to revote
		else if (iHighestCount < iCount - iZeroCount)
		{
			ResetMapVote()

			for (new i = 0; i < iHighestCount; i++)
			{
				if (equal(iHighestMapList[i], g_sCurrentMap)) // Always put extend in the last slot for consistency
					copy(g_sVoteMaps[MAX_MAP_SLOTS - 1], MAX_MAP_LEN - 1, iHighestMapList[i])
				else
					copy(g_sVoteMaps[i], MAX_MAP_LEN - 1, iHighestMapList[i])
			}
			fm_PlaySound(0, g_sSoundRevote)
			client_print(0, print_chat, "* You have voted for more than one map, a re-vote is about to begin")

			set_task(3.5, "StartCountDown", 0)
			return
		}

		new iRandom = random(iHighestCount) 
		client_print(0, print_chat, "* Map vote is a draw, randomly selected %s", iHighestMapList[iRandom])
		VoteResult(iHighestMapList[iRandom])	
	}
	else 
		VoteResult(iHighestMapList[0])

}

ResetMapVote()
{
	new iReturn, iForward = CreateMultiForward("fm_ResetMapVote", ET_IGNORE)
	ExecuteForward(iForward, iReturn)
	DestroyForward(iForward)

	for (new i = 0; i < MAX_MAP_SLOTS; i++)
	{	
		g_sVoteMaps[i][0] = 0
		g_iMapVotes[i] = 0
	}
}

VoteResult(sMap[])
{
	fm_DebugPrintLevel(1, "VoteResult(\"%s\")", sMap)

	fm_PlaySound(0, "doop")

	if (equal(sMap, g_sCurrentMap))
	{		
		client_print(0, print_chat,"* You have voted to remain on this map") 
		fm_PlaySound(0, g_sSoundRemain)	

		ResetMapVote()
		g_iVotingStatus = VOTING_INACTIVE
	}
	else
	{
		copy(g_sNextMap, MAX_MAP_LEN - 1, sMap)

		client_print(0, print_chat, "* You have voted to change map to %s", sMap)
		fm_PlaySound(0, g_sSoundChange)
	
		fm_ChangeLevel(sMap)
		g_iVotingStatus = VOTING_CHANGING
	}
}

/*
	else if (equali(sArgs, "nextmap"))
	{
		switch(fm_GetMapVoteStatus())
		{
			case VOTING_INACTIVE: client_print(0, print_chat, "* The next map will be decided by a vote. Type \"rockthevote\" to begin a mapvote")
			case VOTING_CHANGING: 
			{
				new sNextMap[MAX_MAP_LEN]; fm_GetNextMapName(sNextMap, charsmax(sNextMap))
				client_print(0, print_chat, g_sTextNextMap, sNextMap)
			}
			case VOTING_STARTING, VOTING_SELECT: client_print(0, print_chat,  "* %s", g_sTextInProgress)
		}
	}
*/