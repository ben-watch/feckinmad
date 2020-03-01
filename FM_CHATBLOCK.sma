#include "feckinmad/fm_global"
#include "feckinmad/fm_menu"

#define GAG_MENU_PLAYER_COUNT 8 // Number of players per page on menu

enum {
	CHAT_NORMAL = 0,
	CHAT_BLOCKED
}

new g_iPlayerGags[MAX_PLAYERS + 1][MAX_PLAYERS + 1] // Stores whether a client has chosen to not recieve chat from each player
new g_iMenuPlayers[MAX_PLAYERS + 1][MAX_PLAYERS + 1] 

new g_iPlayerMenuPos[MAX_PLAYERS + 1] // Page on the player select menu
new g_iMaxPlayers

public plugin_init()
{
	fm_RegisterPlugin()
	
	register_clcmd("fm_ignore_menu", "Player_BlockMenu")

	register_clcmd("say /ignore", "Player_BlockMenu")
	register_clcmd("say_team /ignore", "Player_BlockMenu")

	register_menucmd(register_menuid("Select Player:"), ALL_MENU_KEYS, "Command_SelectPlayerMenu")
	register_message(get_user_msgid("SayText"), "Handle_Say")

	g_iMaxPlayers = get_maxplayers()
}

public Handle_Say(iMsgId, iDest, iReciever)
{
	if (iReciever < 0 || iReciever > g_iMaxPlayers) // Check reciever is a player
		return PLUGIN_CONTINUE
		
	new iSender = get_msg_arg_int(1)	
	if (iSender < 0 || iSender > g_iMaxPlayers) // Check sender is a player
		return PLUGIN_CONTINUE	
	
	if (g_iPlayerGags[iReciever][iSender] == CHAT_BLOCKED) // Has reciever blocked sender
	{
		new sArgs[192]; get_msg_arg_string(2, sArgs, charsmax(sArgs))
		console_print(iReciever, sArgs) // Print it in their console instead
		return PLUGIN_HANDLED // Block it from being sent to client
	}
	return PLUGIN_CONTINUE 
}

public Player_BlockMenu(id)
{
	SelectPlayerMenu(id, g_iPlayerMenuPos[id] = 0)
	return PLUGIN_HANDLED
}

SelectPlayerMenu(id, iPos)
{
	if(iPos < 0)
		return PLUGIN_HANDLED
	
	new iPlayerCount
	for (new i = 1; i <= g_iMaxPlayers; i++)
		if (i != id && is_user_connected(i))
			g_iMenuPlayers[id][iPlayerCount++] = i
	
	if (!iPlayerCount)
	{
		client_print(0, print_chat, "* There are no players to ignore") 
		return PLUGIN_HANDLED	
	}
	
	new sMenu[512], iCurrentKey, iKeys, iLen
	new iStart = iPos * GAG_MENU_PLAYER_COUNT  // Start position, where the loop begins, controls pages.
	new iEnd = iStart + GAG_MENU_PLAYER_COUNT // The end of the page is the start + however many players we are showing per page

	if(iEnd > iPlayerCount) // End is greater than the amount of players we have
		iEnd = iPlayerCount

	// Show the page number / Total pages
	iLen = formatex(sMenu, charsmax(sMenu), "Select Player: Page %d/%d\n\n", iPos + 1, (iPlayerCount / GAG_MENU_PLAYER_COUNT + ((iPlayerCount % GAG_MENU_PLAYER_COUNT) ? 1 : 0 )))
	
	new sName[MAX_NAME_LEN + 16], player
	for(new i = iStart; i < iEnd; i++)
	{		
		player = g_iMenuPlayers[id][i]
		get_user_name(player, sName, charsmax(sName))
		iLen += formatex(sMenu[iLen], charsmax(sMenu) - iLen, "%d) %s%s\n", iCurrentKey + 1, sName, g_iPlayerGags[id][player] == CHAT_BLOCKED ? " (Ignored)" : "")
		iKeys |= (1 << iCurrentKey++)
	}

	if (iEnd != iPlayerCount)
	{
		iLen += formatex(sMenu[iLen], charsmax(sMenu) - iLen, "\n9) More")
		iKeys |= (1<<8)
	} 
	
	formatex(sMenu[iLen], charsmax(sMenu) - iLen, "\n0) %s", iPos ? "Back" : "Cancel")
	iKeys |= (1<<9)
	
	show_menu(id, iKeys, sMenu)	

	return PLUGIN_HANDLED
}

public client_disconnect(id)
{
	for (new i = 1; i <= g_iMaxPlayers; i++)
	{
		g_iPlayerGags[id][i] = CHAT_NORMAL // Unblock everyone he blocked
		g_iPlayerGags[i][id] = CHAT_NORMAL // Unblock everyone that blocked him
	}
	g_iPlayerMenuPos[id] = 0
}

public Command_SelectPlayerMenu(id, iKey) 
{
	switch(iKey) 
	{
		case 8: SelectPlayerMenu(id, ++g_iPlayerMenuPos[id])
		case 9: SelectPlayerMenu(id, --g_iPlayerMenuPos[id])
		default: 
		{	
			new player = g_iMenuPlayers[id][g_iPlayerMenuPos[id] * GAG_MENU_PLAYER_COUNT + iKey]
						
			if (!is_user_connected(player))
			{
				client_print(id, print_chat, "* The player you have selected is no longer on the server") 
				return PLUGIN_HANDLED
			}

			g_iPlayerGags[id][player] = g_iPlayerGags[id][player] == CHAT_NORMAL ? CHAT_BLOCKED : CHAT_NORMAL 
		}
	}
	fm_PlaySound(id, FM_MENU_SELECT_SOUND)
	return PLUGIN_HANDLED
}
