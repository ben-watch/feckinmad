#include "feckinmad/fm_global"
#include "feckinmad/fm_mapfile_api" // fm_GetMapNameByIndex(), fm_GetMapCount()
#include "feckinmad/mapvote/fm_mapvote_nominate" // fm_NominateMap()
#include "feckinmad/mapvote/fm_mapvote_mapmenu" // g_sMapMenuLibrary

#define MAPS_PER_PAGE 8 // Number of maps that are displayed per page in the listmaps menu. 9) More 0)Back/Cancel

new const g_sNominateLibrary[] = "fm_mapvote_nominate"

new Array:g_PlayerListMaps[MAX_PLAYERS + 1] // Search results for listmaps
new g_iPlayerMenuPos[MAX_PLAYERS + 1] // Keep track of the players current page position in the map menu

new g_iMaxPlayers

public fm_PluginInit() 
{
	register_menucmd(register_menuid("Select Map:"), ALL_MENU_KEYS, "Command_MapsMenu")

	register_clcmd("say","Handle_Say")
	register_clcmd("say_team","Handle_Say")

	register_concmd("fm_map_menu", "Command_MapMenu")

	g_iMaxPlayers = get_maxplayers()
}

public plugin_natives()
{
	register_native("fm_ShowMapMenu", "Native_ShowMapMenu")
	register_library(g_sMapMenuLibrary)

	set_module_filter("Module_Filter")
	set_native_filter("Native_Filter")
}

public Native_ShowMapMenu()
{
	new id = get_param(1)

	if (id < 1 || id > g_iMaxPlayers)
	{
		log_error(AMX_ERR_NATIVE, "Player out of range (%d)", id)
		return 0
	}

	if (!is_user_connected(id))
	{
		log_error(AMX_ERR_NATIVE, "Invalid player (%d)", id)
		return 0
	}

	MapsMenu(id, g_iPlayerMenuPos[id] = 0)
	return 1
}

public Module_Filter(sModule[])
{
	if (equal(sModule, g_sNominateLibrary))
	{
		return PLUGIN_HANDLED // Load the plugin even if the nominate plugin is not running
	}
	return PLUGIN_CONTINUE
}

public Native_Filter(sName[], iIndex, iTrap)
{
	if (!iTrap)
	{
		return PLUGIN_HANDLED	
	}
	return PLUGIN_CONTINUE
}

public Handle_Say(id)
{  
	static sArgs[192]; read_args(sArgs, charsmax(sArgs)) 
	remove_quotes(sArgs)
	trim(sArgs)

	if (!sArgs[0])
	{
		return PLUGIN_CONTINUE
	}

	if (equali(sArgs, "listmaps", 8))
	{
		if (!sArgs[8]) // No arguments supplied, so show them the full maplist
		{
			// Destroy this players search results so they are not shown them when they are requesting a full maplist
			// Its possible it wasn't destroyed earlier if the player did not press a menu key on the listmaps menu after doing a search
	
			if (g_PlayerListMaps[id] != Invalid_Array) 
				ArrayDestroy(g_PlayerListMaps[id])

			MapsMenu(id, g_iPlayerMenuPos[id] = 0)
			return PLUGIN_HANDLED
		}
		
		if (sArgs[8] == ' ') // Possible search argument
		{
			if (!sArgs[9])
			{
				client_print(id, print_chat, "Usage: listmaps [string] e.g. \"listmaps fm_\"")
			}
			else
			{
				// It's possible the array was never destroyed from previous use as mentioned above
				// Just clear it now as its going to be re-used else create a new one

				if (g_PlayerListMaps[id] != Invalid_Array) 
					ArrayClear(g_PlayerListMaps[id])
				else
					g_PlayerListMaps[id] = ArrayCreate(MAX_MAP_LEN)

				// Search through maplist for matches
				new sMap[MAX_MAP_LEN]
				for (new i = 0, iCount = fm_GetMapCount(); i < iCount; i++) 
				{
					fm_GetMapNameByIndex(i, sMap, charsmax(sMap))
					if (containi(sMap, sArgs[9]) != -1) // Does the mapname contain the search argument
						ArrayPushString(g_PlayerListMaps[id], sMap) // Actually store the whole name rather than just an index incase the map list is reloaded
				}

				new iSize = ArraySize(g_PlayerListMaps[id])
				if (iSize > 0)
				{
					MapsMenu(id, g_iPlayerMenuPos[id] = 0)
				}
				else
					client_print(id, print_chat, "* No matches for \"%s\"", sArgs[9])
			}
			return PLUGIN_HANDLED
		}
	}
	return PLUGIN_CONTINUE
}

public Command_MapMenu(id)
{
	if (g_PlayerListMaps[id] != Invalid_Array) 
	{
		ArrayDestroy(g_PlayerListMaps[id])
	}

	MapsMenu(id, g_iPlayerMenuPos[id] = 0)
	return PLUGIN_HANDLED
}

MapsMenu(id, iPos)
{
	if (iPos < 0)
	{
		if (g_PlayerListMaps[id] != Invalid_Array) 
			ArrayDestroy(g_PlayerListMaps[id])
		return PLUGIN_HANDLED	
	}
	
	new iMapCount = g_PlayerListMaps[id] != Invalid_Array ? ArraySize(g_PlayerListMaps[id]) : fm_GetMapCount()

	if (!iMapCount)
	{
		client_print(id, print_chat, "* There are no maps to display") 
		return PLUGIN_HANDLED	
	}

	new sMenu[512], iCurrentKey, iKeys, iLen
	new iStart = iPos * MAPS_PER_PAGE
	new iEnd = iStart + MAPS_PER_PAGE

	if(iEnd > iMapCount) 
		iEnd = iMapCount
	
	iLen = formatex(sMenu, charsmax(sMenu), "Select Map: Page %d/%d\n\n", iPos + 1, fm_GetMenuPageMax(iMapCount, MAPS_PER_PAGE))

	// Loop between the start and end 
	new sMap[MAX_MAP_LEN]
	for (new i = iStart; i < iEnd; i++) 
	{
		iKeys |= (1 << iCurrentKey++) // Map key

		if (g_PlayerListMaps[id] != Invalid_Array)
			ArrayGetString(g_PlayerListMaps[id], i, sMap, charsmax(sMap))
		else
			fm_GetMapNameByIndex(i, sMap, charsmax(sMap))

		iLen += formatex(sMenu[iLen], (charsmax(sMenu) - iLen), "%d) %s\n", iCurrentKey, sMap)
	}
	
	if(iEnd != iMapCount) 
	{
		iLen += formatex(sMenu[iLen], charsmax(sMenu) - iLen, "\n9) More")
		iKeys |= (1<<8)
	} 
	
	formatex(sMenu[iLen], charsmax(sMenu) - iLen, "\n0) %s", iPos ? "Back" : "Cancel")
	iKeys |= (1<<9)
	
	show_menu(id, iKeys, sMenu)
	
	return PLUGIN_HANDLED
}

public Command_MapsMenu(id, iKey) 
{
	switch(iKey) 
	{
		case 8: MapsMenu(id, ++g_iPlayerMenuPos[id])
		case 9: MapsMenu(id, --g_iPlayerMenuPos[id])
		default:
		{
			new i = g_iPlayerMenuPos[id] * MAPS_PER_PAGE + iKey
			
			new sMap[MAX_MAP_LEN]
			if (g_PlayerListMaps[id] != Invalid_Array)
			{
				ArrayGetString(g_PlayerListMaps[id], i, sMap, charsmax(sMap))
				ArrayDestroy(g_PlayerListMaps[id])
			}
			else
			{
				fm_GetMapNameByIndex(i, sMap, charsmax(sMap))
			}

			if (LibraryExists(g_sNominateLibrary, LibType_Library))
			{
				fm_NominateMap(id, sMap)			
			}
			else
			{
				client_cmd(id, "say %s", sMap)
			}
		}
	}
	fm_PlaySound(id, FM_MENU_SELECT_SOUND)
}

public plugin_end()
{
	for (new i = 1; i <= MAX_PLAYERS; i++)
	{
		if (g_PlayerListMaps[i] != Invalid_Array) 
		{
			ArrayDestroy(g_PlayerListMaps[i])
		}
	}
}