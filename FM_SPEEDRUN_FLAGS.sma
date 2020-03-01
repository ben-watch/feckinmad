#include "feckinmad/fm_global"
#include "feckinmad/fm_sql_tquery"
#include "feckinmad/fm_admin_access"
#include "feckinmad/fm_speedrun_api"
#include "feckinmad/fm_precache"
#include "feckinmad/fm_sql_map"

#include <fakemeta>

#define PC_CIVILIAN 11

new bool:g_bPlayerSpeedRunning[MAX_PLAYERS] // Local cache of speedrunning status

new const g_sFlagModel[] = "models/fm/speedrun/flag_hires.mdl"
new const g_sFlagQuery[] = "SELECT load_flags, startflag_x, startflag_y, startflag_z, endflag_x, endflag_y, endflag_z FROM maps WHERE map_id = %d LIMIT 1;"
enum
{
	FLAG_SKIN_START,
	FLAG_SKIN_END
}

enum
{
	SPEED_FLAGS_QUERY = -2,
	SPEED_FLASS_FAILURE,
	SPEED_FLAGS_DISABLED,
	SPEED_FLAGS_ALLOWED,
	SPEED_FLAGS_LOADED
}

new g_iFlagStatus = SPEED_FLAGS_QUERY

new g_iStartFlagEnt, g_iEndFlagEnt
new Float:g_fStartFlagOrigin[3]
new Float:g_fEndFlagOrigin[3]

new Float:g_fPlayerNextMessage[MAX_PLAYERS + 1]
new g_iMaxPlayers

public plugin_precache()
{
	fm_SafePrecacheModel(g_sFlagModel)
}
	
public plugin_init()
{
	fm_RegisterPlugin()
	g_iMaxPlayers = get_maxplayers()

	register_concmd("admin_addendflag", "Admin_Flag", ADMIN_ADMIN)
	register_concmd("admin_addstartflag", "Admin_Flag", ADMIN_ADMIN)
}

public fm_SQLMapIdent(iMapId, iRootMapId)
{
	new sQuery[256]; formatex(sQuery, charsmax(sQuery), g_sFlagQuery, iMapId)
	fm_SQLAddThreadedQuery(sQuery, "Handle_SelectFlags", QUERY_DISPOSABLE, PRIORITY_HIGH)
}

public Handle_SelectFlags(iFailState, Handle:hQuery, sError[], iError, sData[], iLen, Float:fQueueTime, iQueryIdent)
{
	fm_DebugPrintLevel(1, "Handle_SelectFlags: %f", fQueueTime)

	if(fm_SQLCheckThreadedError(iFailState, hQuery, sError, iError))
	{
		fm_WarningLog("Failed to query database for flag data")
		g_iFlagStatus = SPEED_FLASS_FAILURE
		return PLUGIN_HANDLED
	}

	//server_print("%d %d %d", SQL_NumResults(hQuery), SQL_IsNull(hQuery, 0), SQL_ReadResult(hQuery, 0))

	// There are no results (Although there should be if FM_MAP_IDENT is working right!) Could be a new map, in which case it will get assigned an ident		
	if (!SQL_NumResults(hQuery))
	{	
		g_iFlagStatus = SPEED_FLAGS_ALLOWED	
		return PLUGIN_HANDLED
	}

	switch (SQL_ReadResult(hQuery, 0))
	{
		case -1: g_iFlagStatus = SPEED_FLAGS_DISABLED
		case  0: g_iFlagStatus = SPEED_FLAGS_ALLOWED
		case  1:
		{
			g_iFlagStatus = SPEED_FLAGS_LOADED
			
			for (new i = 0; i < 3; i++)
			{
				SQL_ReadResult(hQuery, i + 1, g_fStartFlagOrigin[i]) 
				SQL_ReadResult(hQuery, i + 4, g_fEndFlagOrigin[i])
			}

			if (!(g_iStartFlagEnt = CreateFlag(FLAG_SKIN_START, g_fStartFlagOrigin)))
			{
				fm_WarningLog("Failed to create start flag")	
				return PLUGIN_HANDLED
			}
			
			if (!(g_iEndFlagEnt = CreateFlag(FLAG_SKIN_END, g_fEndFlagOrigin)))
			{
				fm_WarningLog("Failed to create end flag")	
				return PLUGIN_HANDLED
			}

			fm_ReadyToSpeedRun() // Tell FM_SPEEDRUN_API that we are ready to speedrun. It will forward to the other plugins to check if they are ready.
		}
	}
	return PLUGIN_HANDLED
}

public fm_CanEnableSpeedRun()
{
	fm_DebugPrintLevel(1, "fm_CanEnableSpeedRun()")
	
	if (!g_iStartFlagEnt || !g_iEndFlagEnt)
	{
		return PLUGIN_HANDLED // Return plugin handled. This plugin is ready to speedrun yet!
	}
	return PLUGIN_CONTINUE
}

public fm_InitSpeedRunning()
{
	fm_DebugPrintLevel(1, "fm_InitSpeedRunning()")

	set_pev(g_iStartFlagEnt, pev_rendermode, kRenderNormal)	
	set_pev(g_iEndFlagEnt, pev_rendermode, kRenderNormal)
	register_forward(FM_Touch, "Forward_Touch")
}

CreateFlag(iSkin, Float:fOrigin[3])
{
	fm_DebugPrintLevel(1, "CreateFlag(%d, { %0.2f, %0.2f, %0.2f} )", iSkin, fOrigin[0], fOrigin[1], fOrigin[2])
	
	new iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target")) 
	if (!iEnt)
	{
		fm_WarningLog(FM_ENT_WARNING)
		return 0
	}

	engfunc(EngFunc_SetModel, iEnt, g_sFlagModel)
	set_pev(iEnt, pev_movetype, MOVETYPE_NONE)
	set_pev(iEnt, pev_solid, SOLID_TRIGGER)
	engfunc(EngFunc_SetSize, iEnt, { -16.0, -16.0, -16.0 } , { 16.0, 16.0, 96.0 } )

	set_pev(iEnt, pev_framerate, 0.5)
	set_pev(iEnt, pev_skin, iSkin)

	// Set a random angle on the y axis
	new Float:fAngles[3]; fAngles[1] = random_float(0.0,360.0)
	set_pev(iEnt, pev_angles, fAngles)

	engfunc(EngFunc_SetOrigin, iEnt, fOrigin)
	engfunc(EngFunc_DropToFloor, iEnt)

	// Render them translucent to signify that they aren't active yet
	set_pev(iEnt, pev_rendermode, kRenderTransTexture)
	set_pev(iEnt, pev_renderamt, 75.0)

	return iEnt
}


public fm_PlayerStoppedSpeedRunning(id, iTime)
{
	fm_DebugPrintLevel(1, "fm_PlayerStoppedSpeedRunning(%d, %d)", id, iTime)
	g_bPlayerSpeedRunning[id] = false
}

public fm_PlayerStartedSpeedRunning(id)
{
	fm_DebugPrintLevel(1, "fm_PlayerStartedSpeedRunning(%d)", id)
	g_bPlayerSpeedRunning[id] = true
}

public Forward_Touch(iEnt, id)
{
	if (id < 1 || id > g_iMaxPlayers)
	{
		return FMRES_IGNORED
	}

	if (iEnt == g_iStartFlagEnt)
	{
		if (!is_user_alive(id) || pev(id, pev_playerclass) != PC_CIVILIAN)
			return FMRES_IGNORED

		new Float:fGameTime = get_gametime()

		if (!g_bPlayerSpeedRunning[id])
		{
			if(pev(id, pev_button) & IN_USE)
			{
				fm_StartSpeedRunning(id)
				fm_PlaySound(id, "fm/ready.wav")		
				client_print(id, print_chat, "* Timer started. Simply touch the red end flag to finish or type \"/stop\" to abort")
			}
			else if (fGameTime > g_fPlayerNextMessage[id])
			{
				client_print(id, print_center, "Press USE to begin speedrunning")
				g_fPlayerNextMessage[id] = fGameTime + 0.5
			}	
		}
		else if (fGameTime > g_fPlayerNextMessage[id])
		{
			client_print(id, print_center, "Type /stop to abort speedrunning")
			g_fPlayerNextMessage[id] = fGameTime + 0.5
		}
	}
	else if (iEnt == g_iEndFlagEnt)
	{
		if (!is_user_alive(id) || pev(id, pev_playerclass) != PC_CIVILIAN)
		{
			return FMRES_IGNORED
		}

		if (g_bPlayerSpeedRunning[id])
		{
			fm_StopSpeedRunning(id, 0) // 0 = Not aborted
		}
	}
	return FMRES_IGNORED
}


public Admin_Flag(id, iLevel, iCommand)
{
	if (!fm_CommandAccess(id, iLevel, false))
	{
		return PLUGIN_HANDLED
	}

	if (g_iFlagStatus != SPEED_FLAGS_ALLOWED)
	{
		switch(g_iFlagStatus)
		{
			case SPEED_FLAGS_QUERY: console_print(id, "Unable to create flag. Flag origins are currently being queried from the database")
			case SPEED_FLASS_FAILURE: console_print(id, "Unable to create flag. The server failed to query the database for existing flag origins")
			case SPEED_FLAGS_LOADED: console_print(id, "Flag origins already exists in the database")
			case SPEED_FLAGS_DISABLED: console_print(id, "Creating flags is disabled for the current map")
		}
		return PLUGIN_HANDLED
	}

	new iMapIdent = fm_SQLGetMapIdent()
	if (!iMapIdent)
	{
		console_print(id, "Unable to add flag. Map Ident == 0")
		fm_WarningLog("Unable to add flag. Map Ident == 0")
		return PLUGIN_HANDLED
	}

	new Float:fTraceStart[3], Float:fTraceEnd[3], Float:fReturn[3]
	pev(id, pev_origin, fTraceStart)

	fTraceEnd[0] = fTraceStart[0]
	fTraceEnd[1] = fTraceStart[1]
	fTraceEnd[2] = -8192.0 // Trace straight down

	engfunc(EngFunc_TraceLine, fTraceStart, fTraceEnd, IGNORE_MONSTERS, id, 0)
	get_tr2(0, TR_vecEndPos, fReturn)

	new sCommand[32]; read_argv(0, sCommand, charsmax(sCommand))
	if (sCommand[9] == 's')
	{
		if (g_iStartFlagEnt > 0)
		{
			console_print(id, "Unable to add startflag. Already exists")
			return PLUGIN_HANDLED
		}
		g_iStartFlagEnt = CreateFlag(FLAG_SKIN_START, fReturn)

		for (new i = 0; i < 3; i++)
		{
			g_fStartFlagOrigin[i] = fReturn[i]
		}
	}
	else
	{
		if (g_iEndFlagEnt > 0)
		{
			console_print(id, "Unable to add endflag. Already exists")
			return PLUGIN_HANDLED
		}

		g_iEndFlagEnt = CreateFlag(FLAG_SKIN_END, fReturn)

		for (new i = 0; i < 3; i++)
		{
			g_fEndFlagOrigin[i] = fReturn[i]
		}
	}

	if (g_iStartFlagEnt && g_iEndFlagEnt)
	{					
		new sQuery[512]
		formatex(sQuery, charsmax(sQuery), "UPDATE maps SET load_flags=1, startflag_x=%d, startflag_y=%d, startflag_z=%d, endflag_x=%d, endflag_y=%d, endflag_z=%d WHERE map_id=%d;", floatround(g_fStartFlagOrigin[0]), floatround(g_fStartFlagOrigin[1]), floatround(g_fStartFlagOrigin[2]), floatround(g_fEndFlagOrigin[0]), floatround(g_fEndFlagOrigin[1]), floatround(g_fEndFlagOrigin[2]), iMapIdent)
		fm_SQLAddThreadedQuery(sQuery, "Handle_UpdateFlags", QUERY_NOT_DISPOSABLE, PRIORITY_HIGH)
	}

	return PLUGIN_HANDLED
}

public Handle_UpdateFlags(iFailState, Handle:hQuery, sError[], iError, sData[], iLen, Float:fQueueTime)
{
	fm_DebugPrintLevel(1, "Handle_InsertFlags: %f", fQueueTime)

	if(fm_SQLCheckThreadedError(iFailState, hQuery, sError, iError))
	{
		return PLUGIN_HANDLED
	}

	new iAffected = SQL_AffectedRows(hQuery)
	if (!iAffected)
	{
		fm_WarningLog("Failed to add speedrun flags to the database. SQL_AffectedRows(hQuery): %d", iAffected)
	}
	else
	{
		client_print(0, print_chat, "* Speedrun flags have been added to the map")	
		fm_ReadyToSpeedRun()  // Tell FM_SPEEDRUN_API that we are ready to speedrun. It will forward to the other plugins to check if they are ready.
		
	}
	
	return PLUGIN_CONTINUE
}



















/*
			 Prevent query spam if an admin fucks up the flags...
			/if (g_fPlayerEndTime[id] + 15.0 > fGameTime)
			{
				ResetTimer(id)
				client_print(id, print_chat, "* 41561d")
				return FMRES_IGNORED
			}

			if (g_iPlayerFinished[id] != 1)
		{
 			g_iPlayerFinished[id] = 1
				IncreaseCompleteCount(id)
			}

			if (!AddPlayerSpeedrun(id, iTime))
			{

			}

			ResetTimer(id)


	}
		else if (g_iPlayerFinished[id] != 1)
		{
			g_iPlayerFinished[id] = 1
			IncreaseCompleteCount(id)

			if (g_bCheckPointModule)
			{
				new sTime[32]; fm_SecondsToText(fm_get_user_playtime(id), sTime, charsmax(sTime))
				client_print(0,print_chat, "* \"%s\" has completed the map using %d checkpoint saves and %d loads over a total playtime of %s", sName, fm_get_user_savecount(id), fm_get_user_loadcount(id), sTime)
			}
		}
*/