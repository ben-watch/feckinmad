#if defined _fm_idle_included
  #endinput
#endif
#define _fm_idle_included

#pragma reqlib "fm_idle_api"
stock const g_sIdleAPILibName[] = "fm_idle_api"

forward fm_IdlePlayerAway(id)
forward fm_IdlePlayerBack(id)

native fm_GetUserIdle(id)
native fm_GetUserAway(id)

stock fm_GetActiveRealPlayerNum()
{
	new iCount
	for (new i = 1, iMaxPlayers = get_maxplayers(); i <= iMaxPlayers; i++)
	{
		if (!is_user_connected(i) || is_user_bot(i) || is_user_hltv(i))
			continue

		if (!fm_GetUserAway(i))
			iCount++
	}
	return iCount
}