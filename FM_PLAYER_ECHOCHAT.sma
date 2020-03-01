#include "feckinmad/fm_global"

public plugin_init()
{
	fm_RegisterPlugin()
	register_clcmd("fm_echo_chat", "Player_EchoChat")
}

public Player_EchoChat(id)
{
	if (id != 0)
	{
		new sArgs[MAX_CHAT_LEN]; read_args(sArgs, charsmax(sArgs))
		client_print(id, print_chat, "* %s", sArgs)
	}
}