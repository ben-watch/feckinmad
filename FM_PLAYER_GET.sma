#include "feckinmad/fm_global"
#include "feckinmad/fm_point"
#include "feckinmad/fm_player_get"
#include "feckinmad/fm_player_search"

public plugin_natives()
{
	register_native("fm_CommandGetPlayer", "Native_CommandGetPlayer")
	register_library("fm_player_get")
}

public plugin_init() 
{
	fm_RegisterPlugin()
}

public Native_CommandGetPlayer()
{
	new id = get_param(1), iPlayer
	static sArg[64]; get_string(2, sArg, charsmax(sArg))

	new iLen = strlen(sArg)
	if (!iLen) // This shouldn't occur unless an argument check is missed
	{
		console_print(id, "You must specify a target player")
		return 0 
	}

	// If you press the uparrow to repeat a command in the hl console it adds a space to the end of the line. Remove it.
	new iEndChar = iLen - 1
	if (sArg[iEndChar] == ' ')
		sArg[iEndChar] = 0

	// If the first character is a #, assume they are attempting to enter a userid
	// Note: The engine does not allow player names cannot begin with #
	if (sArg[0] == '#')
	{
		if (equal(sArg[1], "point"))
		{
			iPlayer = fm_GetAimPlayer(id) // Returns the player being looked at from fm_point.inc which requires fakemeta	
			if (!iPlayer)
			{
				console_print(id, "You are not looking at a player")
				return 0 
			}
		}
		else if (equal(sArg[1], "me"))
		{
			iPlayer = id

			if (!iPlayer) // Incase called from rcon, would they even recieve this message? TODO: Check
			{
				console_print(id, "You are not a valid player")
				return 0 
			}
		}
		else
		{
			new iUserId = str_to_num(sArg[1])
			iPlayer = fm_GetPlayerByUserId(iUserId)

			if (!iPlayer)
			{
				console_print(id, "Player with the userid #%d not found", iUserId)
				return 0
			}
		}		
	}

	if (!iPlayer)
		iPlayer = fm_GetPlayerByExactName(sArg)

	if (!iPlayer)
	{
		new iPlayerList[MAX_PLAYERS + 1], iCount = fm_GetPlayersByPartialName(sArg, iPlayerList)
		if (iCount == 1) 
			iPlayer = iPlayerList[0]

		else if (iCount > 1)
		{
			console_print(id, "Please be more specific, there are %d players matching to your input of \"%s\":", iCount, sArg)

			new sName[MAX_NAME_LEN], sAuthid[MAX_AUTHID_LEN]
			for (new i = 0; i < iCount; i++)
			{
				iPlayer = iPlayerList[i] 
				get_user_name(iPlayer, sName, charsmax(sName))
				get_user_authid(iPlayer, sAuthid, charsmax(sAuthid))
				console_print(id, "\t\t#%d %s <%s>", get_user_userid(iPlayer), sName, sAuthid)
			}
			return 0
		}	
		
	}

	if (!iPlayer && equali(sArg, "STEAM_", 6))
	{
		iPlayer = fm_GetPlayerByAuthId(sArg)
		if (!iPlayer)
		{
			console_print(id, "Player with the name or steamid \"%s\" not found", sArg)
			return 0
		}
	}

	if (!iPlayer)
	{
		console_print(id, "Player with the name \"%s\" not found", sArg)
		return 0
	}

	return iPlayer
}
