#include "feckinmad/fm_global"

#include <fakemeta>

new const g_sBotName[] = "QueryRefresh"
new g_iBot

public plugin_init() 
{
	fm_RegisterPlugin()
	set_task(5.0, "CreateBot")
}

public CreateBot()
{
	if (get_playersnum())
	{
		return PLUGIN_HANDLED
	}

	g_iBot = engfunc(EngFunc_CreateFakeClient, g_sBotName)
	if(!g_iBot)
	{
		return PLUGIN_HANDLED
	}

	// From metamod mutil.cpp: Allow plugins to call the entity functions in the GameDLL.
	// In particular, calling "player()" as needed by most Bots
	dllfunc(MetaFunc_CallGameEntity, "player", g_iBot)

	new sRejectReason[128]
	dllfunc(DLLFunc_ClientConnect, g_iBot, g_sBotName, "127.0.0.1", sRejectReason)
	dllfunc(DLLFunc_ClientPutInServer, g_iBot)

	new iFlags = pev(g_iBot, pev_flags) 
	set_pev(g_iBot, pev_flags, iFlags |= FL_FAKECLIENT)
		
	set_task(5.0, "KickBot")
	return PLUGIN_HANDLED
}

public client_putinserver(id)
{
	KickBot()
}

public KickBot()
{
	if (g_iBot)
	{
		server_cmd("kick #%d", get_user_userid(g_iBot))
		g_iBot = 0
	}
}



