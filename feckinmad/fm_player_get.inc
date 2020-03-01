#if defined _fm_player_get_included
  #endinput
#endif
#define _fm_player_get_included

#pragma reqlib "fm_player_get"

#define CMD_PLAYER_DENY_SELF (1<<0)
#define CMD_PLAYER_ONLY_ALIVE (1<<1)

native fm_CommandGetPlayer(id, sArg[])

stock fm_CommandCheckPlayer(id, iTarget, iFlags)
{
  	if ((iFlags & CMD_PLAYER_DENY_SELF) && (id == iTarget))
	{
		console_print(id, "You can't run this command on yourself")
		return 0
	}

	if ((iFlags & CMD_PLAYER_ONLY_ALIVE) && (!is_user_alive(iTarget)))
	{
		new sName[MAX_NAME_LEN]; get_user_name(iTarget, sName, charsmax(sName))
      		console_print(id, "You can't run this command on \"%s\" as they are currently dead", sName)
		return 0
	}
	return 1
}