#include "feckinmad/fm_global"

new g_iStatusText

public plugin_init()
{
	fm_RegisterPlugin()
	register_message(get_user_msgid("TextMsg"), "Handle_TextMsg")
	g_iStatusText = get_user_msgid("StatusText")
}

public Handle_TextMsg(id, iDest, iEnt)
{
	static sArg[128]; get_msg_arg_string(2, sArg, charsmax(sArg))
	
	if (equal(sArg, "#hunted_status", 14))
	{	
		static sName[MAX_NAME_LEN]; get_msg_arg_string(3, sName, charsmax(sName))	
		static sMessage[128]; formatex(sMessage, charsmax(sMessage), "%s %s", sName, sArg) 

		message_begin(MSG_ONE, g_iStatusText, {0,0,0}, iEnt) 
		write_byte(0)
		write_string(sMessage) 
		message_end()
	}
}
	
/*
L 11/18/2006 - 10:19:54: MessageBegin (TextMsg "82") (Destination "One<1>") (Args "3") (Entity "1") (Classname "player") (Netname "watchy") (Origin "0.000000 0.000000 0.000000")
L 11/18/2006 - 10:19:54: Arg 1 (Byte "1")
L 11/18/2006 - 10:19:54: Arg 2 (String "#hunted_status_main_road")
L 11/18/2006 - 10:19:54: Arg 3 (String "BOB")
L 11/18/2006 - 10:19:54: MessageEnd (TextMsg 
*/
