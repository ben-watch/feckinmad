// This plugin must be near the top in plugins.ini or it won't block "say" being sent to plugins loaded before it

#include "feckinmad/fm_global"

#define SPAM_PENALTY 5.0 // Time that is added onto when the player can next chat if they trigger antispam
#define SPAM_MAX_LINES 2 // Number of lines allowed in the given time before antispam kicks in
#define SPAM_SAMPLE_TIME 1.0 // Minimum time between chat, if they say something faster than this their line count will increase

new Float:g_fPlayerNextChat[MAX_PLAYERS + 1] // When the player can next chat
new g_iPlayerLineCount[MAX_PLAYERS + 1]

public plugin_init()
{	
	fm_RegisterPlugin()
	register_clcmd("say", "Handle_Say")
	register_clcmd("say_team", "Handle_Say")	
}

public Handle_Say(id)
{
	static sArgs[192]; read_args(sArgs, charsmax(sArgs))
	remove_quotes(sArgs)

	// -------------------------------------------------------------------------------------------------------------
	// Ignore blank lines as the game will not print these
	// -------------------------------------------------------------------------------------------------------------
	if (!sArgs[0])
	{
		return PLUGIN_HANDLED
	}

	// -------------------------------------------------------------------------------------------------------------
	// Check if the player is using chat too soon
	// -------------------------------------------------------------------------------------------------------------
	new Float:fGameTime = get_gametime()
	if (fGameTime < g_fPlayerNextChat[id])
	{		
		if (++g_iPlayerLineCount[id] == SPAM_MAX_LINES)
		{
			g_fPlayerNextChat[id] = fGameTime + SPAM_PENALTY
		}
		
		if (g_iPlayerLineCount[id] >= SPAM_MAX_LINES)
		{
			new Float:fTime = g_fPlayerNextChat[id] - fGameTime
			client_print(id, print_chat, "* You may not speak for another %d seconds for spamming", floatround(fTime, floatround_ceil))
			return PLUGIN_HANDLED // Block command from being processed by the engine & by other plugins
		}		
	}
	else 
	{
		g_iPlayerLineCount[id] = 0
	}
	
	g_fPlayerNextChat[id] = fGameTime + SPAM_SAMPLE_TIME
	return PLUGIN_CONTINUE
}

public client_disconnect(id)
{
	g_fPlayerNextChat[id] = 0.0
	g_iPlayerLineCount[id] = 0	
}
