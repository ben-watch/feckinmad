#include "feckinmad/fm_global"
#include "feckinmad/fm_precache" // fm_SafePrecacheSound()
#include "feckinmad/fm_mapfunc" // fm_IsMapValid()

new const g_sSoundLoading[] = "fm/mapvote/loading.wav"

new g_sNextMap[MAX_MAP_LEN]
new bool:g_bChangeInProgress

public plugin_precache()
{
	fm_SafePrecacheSound(g_sSoundLoading)
}

public plugin_init() 
{
	fm_RegisterPlugin()
}

public fm_UserRockVote(id)
{
	if (g_bChangeInProgress)
	{
		return PLUGIN_HANDLED
	}
	return PLUGIN_CONTINUE
}


public plugin_natives()
{
	register_native("fm_ChangeLevel", "Native_ChangeLevel")
	register_library("fm_mapvote_changelevel")
}

public Native_ChangeLevel()
{
	if (g_bChangeInProgress)
	{
		fm_WarningLog("Attempted to changelevel whilst already in progress")
		return 0
	}

	get_string(1, g_sNextMap, charsmax(g_sNextMap))	
	if (!fm_IsMapValid(g_sNextMap))
	{
		fm_WarningLog("Attempted to changelevel to invalid map (\"%s\")", g_sNextMap)
		g_sNextMap[0] = 0
		return 0			
	}

	g_bChangeInProgress = true
	set_task(float(get_param(2)), "ChangelevelLoadingSound")
	return 1
}

public ChangelevelLoadingSound()
{
	fm_PlaySound(0, g_sSoundLoading)
	set_task(5.0, "ChangelevelScreenFade")
}

public ChangelevelScreenFade()
{
	fm_PlaySound(0, "ambience/particle_suck2.wav")

	new iScreenFade = get_user_msgid("ScreenFade")
	new iMaxPlayers = get_maxplayers()

	for (new i = 1; i <= iMaxPlayers; i++)
	{
		if(is_user_connected(i))
		{		
			message_begin(MSG_ONE, iScreenFade, { 0, 0, 0 }, i) 
			write_short (1<<14)
			write_short(1<<12)
			write_short(SF_FADE_IN) // Fade type 
			write_byte(255)
			write_byte(255)
			write_byte(255)
			write_byte(255)
			message_end()					
		}
	}

	set_task(5.0, "ChangelevelIntermission")
}

public ChangelevelIntermission()
{
	fm_PlaySound(0, "debris/beamstart4.wav")
	client_print(0, print_center, "nextmap:\n%s", g_sNextMap)

	message_begin(MSG_ALL, SVC_INTERMISSION)
	message_end()

	set_task(5.0, "ChangelevelCommand")
}

public ChangelevelCommand()
{
	log_amx("Nextmap: \"%s\"", g_sNextMap)
	server_cmd("changelevel %s\n", g_sNextMap)
	set_task(5.0, "ChangelevelError")
}

public ChangelevelError()
{
	fm_WarningLog("There was a problem changing map to \"%s\"", g_sNextMap)
	client_print(0, print_chat, "There was a problem changing map to \"%s\"", g_sNextMap)
	g_bChangeInProgress = false
}
