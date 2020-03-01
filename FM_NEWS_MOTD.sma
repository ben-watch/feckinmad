#include "feckinmad/fm_global"

new const g_sNewsHelpFile[] = "news/fm_news.txt"
new g_sNewsHelpPath[128]

public plugin_init()
{
	fm_RegisterPlugin()

	register_clcmd("say /news", "Handle_News")
	register_clcmd("say_team /news", "Handle_News")

	fm_BuildAMXFilePath(g_sNewsHelpFile, g_sNewsHelpPath, charsmax(g_sNewsHelpPath), FM_AMXX_LOCAL_CONFIGS)
}

public Handle_News(id)
{
	show_motd(id, g_sNewsHelpPath, "News")
	return PLUGIN_HANDLED
}
