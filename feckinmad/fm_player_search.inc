#if defined _fm_player_included
  #endinput
#endif
#define _fm_player_included

stock fm_GetPlayerByUserId(iUserId)
{
	for (new i = 1, iMaxPlayers = get_maxplayers(); i <= iMaxPlayers; i++)
		if (is_user_connected(i) && get_user_userid(i) == iUserId)
				return i
	return 0
}

stock fm_GetPlayersByPartialName(sArg[], iOut[MAX_PLAYERS + 1], iIgnore = 0)
{
	new sName[MAX_NAME_LEN], iCount = 0
	for (new i = 1, iMaxPlayers = get_maxplayers(); i <= iMaxPlayers; i++)
	{
		if (!is_user_connected(i) || iIgnore == i)
		{
			continue
		}

		get_user_name(i, sName, charsmax(sName))
		if (containi(sName, sArg) != -1)
		{
			iOut[iCount++] = i
		}
	}
	return iCount
}

stock fm_GetPlayerByExactName(sArg[])
{
	new sName[MAX_NAME_LEN]
	for (new i = 1, iMaxPlayers = get_maxplayers(); i <= iMaxPlayers; i++)
	{
		if (!is_user_connected(i))
			continue

		get_user_name(i, sName, charsmax(sName))
		if (equali(sName, sArg))
			return i
	}
	return 0
}

stock fm_GetPlayerByAuthId(sArg[])
{
	new sAuthId[MAX_AUTHID_LEN]
	for (new i = 1, iMaxPlayers = get_maxplayers(); i <= iMaxPlayers; i++)
	{
		if (!is_user_connected(i))
			continue

		get_user_authid(i, sAuthId, charsmax(sAuthId))
		if (equali(sAuthId, sArg))
			return i
	}
	return 0
}