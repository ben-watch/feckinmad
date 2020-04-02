#include "feckinmad/fm_global"
#include "feckinmad/fm_idle_api"
#include "feckinmad/fm_admin_access"

// BUG BUG: Should we be removing rocks from idle players

new const Float:g_fRockPercent = 0.5 // Percent of players required to start map voting
new bool:g_bPlayerRocked[MAX_PLAYERS + 1] // Whether the player has rocked or not
new g_iRockCount, g_iIdleModule

public plugin_init() 
{
	fm_RegisterPlugin()
	
	register_clcmd("say","Handle_Say")
	register_clcmd("say_team","Handle_Say")

	g_iIdleModule = LibraryExists(g_sIdleAPILibName, LibType_Library)

	if (LibraryExists(g_sAdminAccessLibName, LibType_Library))
	{
		register_concmd("admin_rockthevote", "Admin_Rockthevote", ADMIN_HIGHER)
	}
}

public Admin_Rockthevote(id, iLevel, iCommand)
{
	if (!fm_CommandAccess(id, iLevel, false))
	{
		return PLUGIN_HANDLED
	}

	if (!UserRockVote(-1))
	{
		console_print(id, "Unable to rockthevote")
		return PLUGIN_HANDLED
	}

	RockVoteQuotaReached()

	new sAdminRealName[MAX_NAME_LEN]; fm_GetUserRealname(id, sAdminRealName, charsmax(sAdminRealName))
	new sAdminName[MAX_NAME_LEN]; get_user_name(id, sAdminName, charsmax(sAdminName))
	new sAdminAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAdminAuthid, charsmax(sAdminAuthid))
	
	client_print(0, print_chat, "* ADMIN #%d %s: forced mapvoting to start", fm_GetUserIdent(id), sAdminRealName)
	console_print(id, "You have forced mapvoting to start")		
	log_amx("\"%s<%s>(%s)\" admin_rockthevote", sAdminName, sAdminAuthid, sAdminRealName)
	
	return PLUGIN_HANDLED
}

public Handle_Say(id)
{  
	static sArgs[192]; read_args(sArgs, charsmax(sArgs)) 
	remove_quotes(sArgs)
	trim(sArgs)

	if (!sArgs[0])
	{
		return PLUGIN_CONTINUE
	}

	if (equali(sArgs, "rockthevote") || equali(sArgs, "rockthebadger"))
	{
		if (UserRockVote(id))
		{
			new iPlayerCount = g_iIdleModule ? fm_GetActiveRealPlayerNum() : fm_GetRealPlayerNum()	
			new iRequiredRocks = floatround(iPlayerCount * g_fRockPercent, floatround_ceil)

			fm_DebugPrintLevel(3, "id: %d attempted to rockthevote", id)
			fm_DebugPrintLevel(3, "iPlayerCount: %d iRequiredRocks: %d", iPlayerCount, iRequiredRocks)

			if(!g_bPlayerRocked[id])
			{ 
				g_bPlayerRocked[id] = true 
				g_iRockCount++

				fm_DebugPrintLevel(3, "id: %d success to rockthevote. g_iRockCount: %d iRequiredRocks: %d", id, g_iRockCount, iRequiredRocks)

				new sName[MAX_NAME_LEN]; get_user_name(id, sName, charsmax(sName))
				if (iRequiredRocks - g_iRockCount <= 0)
				{
					client_print(0, print_chat, "* %s has rocked the vote. Starting map vote as %d/%d (%d%%)%s players have rocked the vote", sName, g_iRockCount, iPlayerCount, floatround((float(g_iRockCount) / iPlayerCount) * 100), g_iIdleModule ? " active" : "")
					RockVoteQuotaReached()
				}
				else
					client_print(0, print_chat, "* %s has rocked the vote. %d more players must rockthevote to start a map vote", sName, iRequiredRocks - g_iRockCount)
			}
			else
			{
				fm_DebugPrintLevel(3, "id: %d denied. Has already rockthevote", id)
				client_print(id, print_chat, "* You have already rocked the vote. %d more players must rockthevote to start a map vote", iRequiredRocks - g_iRockCount)
				return PLUGIN_HANDLED

			}
		}
	}
	return PLUGIN_CONTINUE
}

public client_disconnected(id)
{ 
	// Remove their rock
	if (g_bPlayerRocked[id])
	{
		g_bPlayerRocked[id] = false
		g_iRockCount--
	}
	
	// Check if the percentage of rocks to players should trigger a mapvote
	ShouldMapVoteStart()
}

// A player has become idle
public fm_IdlePlayerAway(id)
{
	fm_DebugPrintLevel(1, "fm_IdlePlayerAway(%d) triggered", id)

	// Remove their rock
	if (g_bPlayerRocked[id])
	{
		g_bPlayerRocked[id] = false
		g_iRockCount--
	}

	ShouldMapVoteStart()
}

// A player has come back from being idle
public fm_IdlePlayerBack(id)
{
	fm_DebugPrintLevel(1, "fm_IdlePlayerBack(%d) triggered", id)
	ShouldMapVoteStart()
}

ShouldMapVoteStart()
{
	fm_DebugPrintLevel(1, "ShouldMapVoteStart() triggered")

	// Check that voting isn't already active and that enough time has passed to begin rocking the vote
	if (!UserRockVote(0))
	{
		return 0
	}

	// Check the playercount. Ignoring bots and HLTV, if the idle plugin is running, also ignore idle players.
	new iPlayerCount =  g_iIdleModule ? fm_GetActiveRealPlayerNum() : fm_GetRealPlayerNum()	

	// There is no point starting a vote if there are no players
	if (!iPlayerCount)
	{	
		return 0
	}

	// Calculate how many rocks would be required to start a mapvote
	new iRequiredRocks = floatround(iPlayerCount * g_fRockPercent, floatround_ceil)	

	fm_DebugPrintLevel(3, "g_iRockCount: %d iRequiredRocks: %d", g_iRockCount, iRequiredRocks)

	// Check the amount of rocks we have, start a mapvote if we have enough
	if (iRequiredRocks - g_iRockCount <= 0)
	{
		client_print(0, print_chat, "* Starting map vote as %d/%d (%d%%)%s players have rocked the vote", g_iRockCount, iPlayerCount, floatround((float(g_iRockCount) / iPlayerCount) * 100), g_iIdleModule ? " active" : "")
		RockVoteQuotaReached()
	}
	return 1	
}

public fm_ResetMapVote()
{
	fm_DebugPrintLevel(1, "fm_ResetMapVote() triggered")

	for (new i = 1, iMaxPlayers = get_maxplayers(); i <= iMaxPlayers; i++)
	{
		g_bPlayerRocked[i] = false
	}
}

// Runs a forward to check if other plugins have a problem with this player rocking the vote
UserRockVote(id)
{
	new iReturn, iForward = CreateMultiForward("fm_UserRockVote", ET_STOP, FP_CELL)
	ExecuteForward(iForward, iReturn, id)
	if (iReturn == PLUGIN_HANDLED)
	{
		return 0
	}
	return 1
}

// Runs a forward to tell other plugins that the rockthevote quota has been reached
RockVoteQuotaReached()
{
	fm_DebugPrintLevel(1, "RockVoteQuotaReached() triggered")

	new iReturn, iForward = CreateMultiForward("fm_RockVoteQuotaReached", ET_IGNORE)
	ExecuteForward(iForward, iReturn)
	DestroyForward(iForward)
}

public plugin_natives()
{
	set_module_filter("Module_Filter")
	set_native_filter("Native_Filter")
}

public Module_Filter(sModule[])
{
	if (equal(sModule, g_sIdleAPILibName))
	{
		return PLUGIN_HANDLED 
	}

	if (equal(sModule, g_sAdminAccessLibName))
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
