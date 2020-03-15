#include "feckinmad/fm_global"
#include "feckinmad/fm_admin_access"
#include "feckinmad/mapvote/fm_mapvote_rockthevote"
#include "feckinmad/fm_idle_api"
#include "feckinmad/fm_time"

new Float:g_fBeginRocking // When rocking the vote can begin
new const Float:g_fWaitTime = 600.0

new g_iMaxPlayers

new bool:g_bPlayerAttemptedToRock[MAX_PLAYERS + 1] // Whether the player has attempted to rock
new g_iAttemptedRockCount

new g_iIdleModule

public plugin_init()
{
	fm_RegisterPlugin()
	
	g_fBeginRocking = get_gametime() + g_fWaitTime

	g_iIdleModule = LibraryExists("fm_idle_api", LibType_Library)
	if (LibraryExists(g_sAdminAccessLibName, LibType_Library))
	{
		register_concmd("admin_cleartimelimit", "Admin_ClearTimeLimit", ADMIN_HIGHER)
	}

	g_iMaxPlayers = get_maxplayers()
}

public client_disconnected(id)
{
	if (g_bPlayerAttemptedToRock[id])
	{
		g_bPlayerAttemptedToRock[id] = false
		g_iAttemptedRockCount--
	}

	// Rockthevote plugin takes care of checking if mapvote should start when players become idle / disconnect
}

// A player has become idle
public fm_IdlePlayerAway(id)
{
	if (g_bPlayerAttemptedToRock[id])
	{
		g_iAttemptedRockCount--
	}
}

// A player has come back from being idle
public fm_IdlePlayerBack(id)
{
	if (g_bPlayerAttemptedToRock[id])
	{
		g_iAttemptedRockCount++
	}
}


public Admin_ClearTimeLimit(id, iLevel, iCommand)
{
	if (!fm_CommandAccess(id, iLevel, false))
	{
		return PLUGIN_HANDLED
	}

	if (GetSecondsUntilRocking() <= 0)
	{
		console_print(id, "There is no active timelimit")
		return PLUGIN_HANDLED
	}

	g_fBeginRocking = 0.0

	new sAdminRealName[MAX_NAME_LEN]; fm_GetUserRealname(id, sAdminRealName, charsmax(sAdminRealName))
	new sAdminName[MAX_NAME_LEN]; get_user_name(id, sAdminName, charsmax(sAdminName))
	new sAdminAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAdminAuthid, charsmax(sAdminAuthid))
	
	client_print(0, print_chat, "* ADMIN #%d %s: cleared rockthevote timelimit", fm_GetUserIdent(id), sAdminRealName)
	console_print(id, "You have cleared rockthevote timelimit")		
	log_amx("\"%s<%s>(%s)\" admin_cleartimelimit", sAdminName, sAdminAuthid, sAdminRealName)

	return PLUGIN_HANDLED
}

public fm_UserRockVote(id)
{
	new iSecs = GetSecondsUntilRocking()
	if (iSecs > 0) 
	{
		// Allow if it is forced, e.g. from admin_rockthevote
		if (id == FORCE_MAPVOTE_ID)
		{
			return PLUGIN_CONTINUE // Allow rockthevote
		}
	
		// Log that they attempted, even if it fails. This allows us to overwrite the timelimit if everyone wants to change
		if (1 <= id <= g_iMaxPlayers)
		{	
			if (!g_bPlayerAttemptedToRock[id])
			{
				client_print(id, print_chat, "* It's too early to rockthevote right now, but if 100% of active players attempt it the timelimit will be skipped.")
				g_bPlayerAttemptedToRock[id] = true
				g_iAttemptedRockCount++
			}
		}

		new iPlayerCount =  g_iIdleModule ? fm_GetActiveRealPlayerNum() : fm_GetRealPlayerNum()
		if (g_iAttemptedRockCount >= iPlayerCount)
		{
			client_print(0, print_chat, "* 100%%%% of active players have attempted to rockthevote. Skipping timelimit") 
			return PLUGIN_CONTINUE // Allow rockthevote
		}

		// If this is a player send them a message detailing how long they have to wait
		if (1 <= id <= g_iMaxPlayers)
		{
			new sTime[64]; fm_SecondsToText(iSecs, sTime, charsmax(sTime))
			client_print(0, print_chat, "* %s before you can rockthevote", sTime) 
		}

		// Else it is just a check to see if mapvoting can start, probably from a trigger such as a client disconnecting or becoming idle etc
		return PLUGIN_HANDLED // Block rockthevote
	}
	return PLUGIN_CONTINUE // Allow rockthevote
}

public fm_RockVoteQuotaReached()
{
	// Remove the timelimit if rocking the vote quota is complete, this should already be the case, unless the mapvote was forced
	g_fBeginRocking = 0.0

	new iMaxplayers = get_maxplayers() // Don't really need to use maxplayers here.
	for (new i = 1; i <= iMaxplayers; i++)
	{
		g_bPlayerAttemptedToRock[i] = false
	}

	g_iAttemptedRockCount = 0
}

public fm_ResetMapVote()
{
	g_fBeginRocking = get_gametime() + g_fWaitTime
}

GetSecondsUntilRocking()
{
	return floatround(g_fBeginRocking - get_gametime(), floatround_ceil)
}

public plugin_natives()
{
	set_module_filter("Module_Filter")
	set_native_filter("Native_Filter")
}

public Module_Filter(sModule[])
{
	if (equal(sModule, g_sAdminAccessLibName))
	{
		return PLUGIN_HANDLED
	}
	if (equal(sModule, "fm_idle_api"))
	{
		return PLUGIN_HANDLED
	}

	return PLUGIN_CONTINUE
}

public Native_Filter(sName[], iIndex, iTrap)
{
	if (!iTrap)
	{
		return PLUGIN_HANDLED
	}
	return PLUGIN_CONTINUE
}


/*
	else if (equali(sArgs, "timeleft"))
	{
		switch(fm_GetMapVoteStatus())
		{
			case VOTING_INACTIVE: client_print(0, print_chat, "* The map will change when another map is voted. Type \"rockthevote\" to begin a mapvote")
			case VOTING_CHANGING: 
			{
				new sNextMap[MAX_MAP_LEN]; fm_GetNextMapName(sNextMap, charsmax(sNextMap))
				client_print(0, print_chat, g_sTextNextMap, sNextMap)
			}
			case VOTING_STARTING, VOTING_SELECT: client_print(0, print_chat, "* %s. The map will change if another map is selected", g_sTextInProgress)
		}
	}
*/