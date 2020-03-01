#include "feckinmad/fm_global"
#include <fakemeta>

#define MAX_DISTANCE 512
#define DISTANCE_INCRIMENT 16
#define MAX_ATTEMPTS 256

new g_iMaxPlayers

TraceHull(id, Float:fOrigin[3], iHull)
{
	engfunc(EngFunc_TraceHull, fOrigin, fOrigin, DONT_IGNORE_MONSTERS, iHull, id, 0)
	if (get_tr2(0, TR_StartSolid) || get_tr2(0, TR_AllSolid) || !get_tr2(0, TR_InOpen))
		return 1
	return 0
}

public plugin_init()
{
	fm_RegisterPlugin()

	register_clcmd("say", "Handle_Say")
	register_clcmd("say_team", "Handle_Say")

	register_forward(FM_SetOrigin, "Forward_SetOriginPost", 1)
	g_iMaxPlayers = get_maxplayers()
}

public Handle_Say(id) 
{
	new sArgs[128]; read_args(sArgs, charsmax(sArgs))
	remove_quotes(sArgs)
	
	if (equali(sArgs,"stuck") || equali(sArgs,"/stuck") || equali(sArgs,"check stuck") || equali(sArgs,"destuckme") || equali(sArgs,"unstuck"))
	{
		switch(UnStick(id))
		{
			case 1: client_print(id, print_chat, "* You have been unstuck")
			case 0: client_print(id, print_chat, "* You don't seem to be stuck")
			case -1: client_print(id, print_chat, "* Sorry, but you are stuck beyond hope")
		}	
		return PLUGIN_HANDLED
	}
	else if (containi(sArgs, "stuck") != -1)
	{
		UnStick(id)
	}

	return PLUGIN_CONTINUE
}

UnStick(id)
{
	new Float:fPlayerOrigin[3]; pev(id, pev_origin, fPlayerOrigin)
	new iHull = pev(id, pev_flags) & FL_DUCKING ? HULL_HEAD : HULL_HUMAN

	if (!TraceHull(id, fPlayerOrigin, iHull))
		return 0

	new Float:fNewOrigin[3], iDistance = DISTANCE_INCRIMENT
	fPlayerOrigin[2] += 16.0 // Raise the player slightly as it's quite likely they are stuck in the ground

	//fm_DebugPrintLevel(3, "%0.2f %0.2f %0.2f", fPlayerOrigin[0], fPlayerOrigin[1], fPlayerOrigin[2])

	while(iDistance < MAX_DISTANCE)
	{
		//fm_DebugPrintLevel(3, "iDistance: %d", iDistance)

		for (new i = 0; i < MAX_ATTEMPTS; ++i) 
		{
			for (new j = 0; j < 3; j++)
				fNewOrigin[j] = random_float(fPlayerOrigin[j] - iDistance, fPlayerOrigin[j] + iDistance)

			//fm_DebugPrintLevel(3, "%0.2f %0.2f %0.2f", fNewOrigin[0], fNewOrigin[1], fNewOrigin[2])

			if (!TraceHull(id, fNewOrigin, iHull)) 
			{
				engfunc(EngFunc_SetOrigin, id, fNewOrigin)
				return 1
			}
		}
		iDistance += DISTANCE_INCRIMENT
	}
	return -1	
}

public plugin_natives()
{
	register_native("fm_UnstickPlayer", "Native_UnstickPlayer")
	register_library("fm_stuck")
}

public Native_UnstickPlayer() 
{
	new id = get_param(1)

	if (id < 1 || id > g_iMaxPlayers)
		return FMRES_IGNORED

	if (!is_user_connected(id) || !pev(id, pev_team))
		return FMRES_IGNORED

	return UnStick(id)
}

// Automatically unstick players when they get teleported by a map
public Forward_SetOriginPost(iEnt, Float:fOrigin[3])
{
	if (iEnt < 1 || iEnt > g_iMaxPlayers)
		return FMRES_IGNORED

	if (!is_user_connected(iEnt) || !pev(iEnt, pev_team))
		return FMRES_IGNORED

	UnStick(iEnt)
	return FMRES_IGNORED
}
