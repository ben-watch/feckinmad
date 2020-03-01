#include "feckinmad/fm_global"
#include "feckinmad/fm_voice_api"
#include "feckinmad/fm_menu"

#define MENU_PLAYER_COUNT 7

new g_iMenuPlayers[MAX_PLAYERS + 1][MAX_PLAYERS + 1] // Array which is filled with players for the menu
new g_iPlayerMenuPos[MAX_PLAYERS + 1] // Keep track of what page the player is on
new g_iMaxPlayers

public plugin_init()
{
	fm_RegisterPlugin()

	register_concmd("fm_mute_menu", "Player_MuteMenu")
	register_menucmd(register_menuid("Select Player"), ALL_MENU_KEYS, "Command_SelectPlayerMenu")

	g_iMaxPlayers = get_maxplayers()
}

public Player_MuteMenu(id)
	SelectPlayerMenu(id, g_iPlayerMenuPos[id] = 0)		

SelectPlayerMenu(id, iPos)
{
	if(iPos < 0) // If they cancel out of the menu
		return PLUGIN_HANDLED

	new iPlayerCount
	for (new i = 1; i <= g_iMaxPlayers; i++)
		if (i != id && is_user_connected(i))
			g_iMenuPlayers[id][iPlayerCount++] = i
	
	if (!iPlayerCount)
	{
		client_print(id, print_chat, "* There are no players to mute") 
		return PLUGIN_HANDLED	
	}
	
	new sMenu[512], iCurrentKey, iKeys, iLen
	new iStart = iPos * MENU_PLAYER_COUNT  // Start position, where the loop begins, controls pages.
	new iEnd = iStart + MENU_PLAYER_COUNT// The end of the page is the start + however many players we are showing per page

	if(iEnd > iPlayerCount) // If the end is greater than the amount of players, set it to that instead
		iEnd = iPlayerCount

	// Show the page number / Total pages
	iLen = formatex(sMenu, charsmax(sMenu), "Select Player: Page %d/%d\n\n", iPos + 1, fm_GetMenuPageMax(iPlayerCount, MENU_PLAYER_COUNT))
	
	new sName[MAX_NAME_LEN], iPlayer
	for(new i = iStart; i < iEnd; i++)
	{		
		iPlayer = g_iMenuPlayers[id][i]
		get_user_name(iPlayer, sName, charsmax(sName))
		
		iLen += formatex(sMenu[iLen], charsmax(sMenu) - iLen, "%d) %s%s\n", iCurrentKey + 1, sName, fm_GetVoiceListening(id, iPlayer) == SPEAK_MUTED ? " (Muted)" : "")
		iKeys |= (1<<iCurrentKey++)
	}

	iLen += formatex(sMenu[iLen], charsmax(sMenu) - iLen, "\n8) Everyone%s", fm_GetVoiceListening(id, 0) == SPEAK_MUTED ? " (Muted)" : "")
	iKeys |= (1<<7)
	
	if(iEnd != iPlayerCount)
	{
		iLen += formatex(sMenu[iLen], charsmax(sMenu) - iLen, "\n9) More")
		iKeys |= (1<<8)
	} 
	
	formatex(sMenu[iLen], charsmax(sMenu) - iLen, "\n0) %s", iPos ? "Back" : "Cancel")
	iKeys |= (1<<9)
	
	show_menu(id, iKeys, sMenu)	

	return PLUGIN_HANDLED
}

public Command_SelectPlayerMenu(id, iKey) 
{
	switch(iKey) 
	{	
		case 7: 
		{	
			if (fm_GetVoiceListening(id, 0) == SPEAK_NORMAL)
			{
				client_print(id, print_chat, "* You have muted all voice communications")
				fm_SetVoiceListening(id, 0, SPEAK_MUTED)
			}
			else
			{
				client_print(id, print_chat, "* You have unmuted all voice communications")
				fm_SetVoiceListening(id, 0, SPEAK_NORMAL)
			}
		}
		case 8: SelectPlayerMenu(id, ++g_iPlayerMenuPos[id])
		case 9: SelectPlayerMenu(id, --g_iPlayerMenuPos[id])
		default: 
		{	
			new iTarget = g_iMenuPlayers[id][g_iPlayerMenuPos[id] * MENU_PLAYER_COUNT + iKey]
			
			if (!is_user_connected(iTarget))
			{
				client_print(id, print_chat, "* The player you have selected is no longer on the server") 
				return PLUGIN_HANDLED
			}
	
			new sTargetName[MAX_NAME_LEN]; get_user_name(iTarget, sTargetName, charsmax(sTargetName))
		
			if (fm_GetVoiceListening(id, iTarget) == SPEAK_NORMAL)
			{
				fm_SetVoiceListening(id, iTarget, SPEAK_MUTED)
				client_print(id, print_chat, "* You have muted voice communications from \"%s\"", sTargetName)
			}
			else
			{
				fm_SetVoiceListening(id, iTarget, SPEAK_NORMAL)
				client_print(id, print_chat, "* You have unmuted voice communications from \"%s\"", sTargetName)
			}
		}
	}
	fm_PlaySound(id, FM_MENU_SELECT_SOUND)
	SelectPlayerMenu(id, g_iPlayerMenuPos[id])
	return PLUGIN_HANDLED
}	