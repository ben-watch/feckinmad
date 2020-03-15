#include "feckinmad/fm_global"
#include "feckinmad/fm_voice_api"

#include <fakemeta>

new g_iPlayerListen[MAX_PLAYERS + 1][MAX_PLAYERS + 1]
new g_iMaxPlayers

public plugin_init()
{
	fm_RegisterPlugin()

	register_forward(FM_Voice_SetClientListening, "Forward_SetClientListening")
	g_iMaxPlayers = get_maxplayers()

	for (new i = 0; i <= g_iMaxPlayers; i++)
		for (new j = 0; j <= g_iMaxPlayers; j++)
			g_iPlayerListen[i][j] = SPEAK_NORMAL
}

public Forward_SetClientListening(iReceiver, iSender, iListen)
{
	if (iListen == SPEAK_NORMAL)
	{
		if (	g_iPlayerListen[iReceiver][iSender] != SPEAK_NORMAL || // Reciever has muted sender
			g_iPlayerListen[iReceiver][0] != SPEAK_NORMAL || // Receiver has muted all incoming
			g_iPlayerListen[0][iSender] != SPEAK_NORMAL // Sender is muted from outgoing
		) 
		{
			engfunc(EngFunc_SetClientListening, iReceiver, iSender, SPEAK_MUTED) 
			return FMRES_SUPERCEDE
		}
	}
	return FMRES_IGNORED
}

public client_disconnected(id)
{
	for (new i = 0; i <= g_iMaxPlayers; i++)
	{
		g_iPlayerListen[i][id] = SPEAK_NORMAL // Unmute everyone that muted him
		g_iPlayerListen[id][i] = SPEAK_NORMAL // Unmuted everyone he muted unless
	}
}

public plugin_natives()
{
	register_native("fm_SetVoiceListening", "Native_SetVoiceListening")
	register_native("fm_GetVoiceListening", "Native_GetVoiceListening")
	register_library("fm_voice_api")
}

public Native_SetVoiceListening(iPlugin, iParams)
{
	new iSender = get_param(1)
	new iReceiver = get_param(2)


	if (iSender < 0 || iSender > g_iMaxPlayers)
	{
		log_error(AMX_ERR_NATIVE, "Player out of range (%d)", iSender)
		return 0
	}

	if (iReceiver < 0 || iReceiver > g_iMaxPlayers)
	{
		log_error(AMX_ERR_NATIVE, "Player out of range (%d)", iReceiver)
		return 0
	}

	g_iPlayerListen[iSender][iReceiver] = get_param(3)
	return 1
}

public Native_GetVoiceListening(iPlugin, iParams)
{
	new iSender = get_param(1)
	new iReceiver = get_param(2)

	if (iSender < 0 || iSender > g_iMaxPlayers)
	{
		log_error(AMX_ERR_NATIVE, "Player out of range (%d)", iSender)
		return 0
	}

	if (iReceiver < 0 || iReceiver > g_iMaxPlayers)
	{
		log_error(AMX_ERR_NATIVE, "Player out of range (%d)", iReceiver)
		return 0
	}

	return g_iPlayerListen[iSender][iReceiver]
}
