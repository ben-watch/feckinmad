#include "feckinmad/fm_global"
#include "feckinmad/fm_precache"

new const g_sJoinSoundFile[] = "fm/door_bell.wav"

public plugin_init()
{
	fm_RegisterPlugin()
}

public plugin_precache()
{
	fm_SafePrecacheSound(g_sJoinSoundFile)
}

public client_putinserver(id)
{	
	new sName[MAX_NAME_LEN]; get_user_name(id, sName, charsmax(sName))
	client_print(0, print_chat, "+ %s has joined the game", sName)

	fm_PlaySound(0, g_sJoinSoundFile)
}