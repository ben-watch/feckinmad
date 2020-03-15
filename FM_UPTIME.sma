#include "feckinmad/fm_global"
#include "feckinmad/fm_time"

new g_iStartTime

public plugin_init()
{
	fm_RegisterPlugin()

	register_clcmd("say /uptime", "Handle_Uptime")
	register_clcmd("say_team /uptime", "Handle_Uptime")

	// Must be deal with number as a string to prevent it getting fucked
	new sTime[MAX_CHAT_LEN], iSysTime = get_systime()
	num_to_str(iSysTime, sTime, charsmax(sTime))

	// Hold boot timestamp between mapchanges
	new pCvarStartTime = register_cvar("fm_boot_systime", sTime)

	// Add uptime to amxmodx logs
	get_pcvar_string(pCvarStartTime, sTime, charsmax(sTime)) 
	g_iStartTime = str_to_num(sTime)

	fm_SecondsToText(iSysTime - g_iStartTime, sTime, charsmax(sTime))
	log_amx("Map Start: Uptime: %s", sTime)
}

public plugin_end()
{
	new sTime[MAX_CHAT_LEN]; fm_SecondsToText(get_systime() - g_iStartTime, sTime, charsmax(sTime))
	log_amx("Map End: Uptime: %s", sTime)
}

public Handle_Uptime(id)
{
	new sTime[MAX_CHAT_LEN]; fm_SecondsToText(get_systime() - g_iStartTime, sTime, charsmax(sTime))
	client_print(0, print_chat, "* Server Uptime: %s", sTime)
}

public fm_ScreenMessage(sBuffer[], iSize)
{
	switch(random(2))
	{
		case 0:
		{
			new sTime[MAX_CHAT_LEN]; fm_SecondsToText(get_systime() - g_iStartTime, sTime, charsmax(sTime))
			formatex(sBuffer, iSize, "Time since last restart: %s", sTime)
			return PLUGIN_CONTINUE
		}
		case 1: 
		{
			formatex(sBuffer, iSize, "%d plugins currently loaded for your gaming pleasure", get_pluginsnum())
			return PLUGIN_CONTINUE
		}
	}
	return PLUGIN_CONTINUE
}