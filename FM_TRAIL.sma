#include "feckinmad/fm_global"
#include "feckinmad/fm_config" // fm_InitConfigExec() forward
#include "feckinmad/fm_colour_api" // fm_GetColourIndex(...) etc
#include "feckinmad/fm_menu" // MAX_MENU_STRING etc
#include "feckinmad/fm_sql_tquery"
#include "feckinmad/fm_sql_player"
#include "feckinmad/fm_precache" // fm_SafePrecacheModel(...)

#include <fakemeta>

#define MAX_PLAYER_TRAIL_COLOURS 5 // Maximum number of colours a player can trail
#define MAX_MENU_TRAILS 7 // Number of trails per page in the menu

new bool:g_bTrailEnabled = true

new g_iPlayerTrailColours[MAX_PLAYERS + 1][MAX_PLAYER_TRAIL_COLOURS * 3] // Stores the players current trail colours
new g_iPlayerTrailColourNum[MAX_PLAYERS + 1] // Amount of colours the player is trailing
new g_iPlayerTempTrailColourNum[MAX_PLAYERS + 1] // Stored here when the player is being "teleported"
new g_iPlayerTrailPos[MAX_PLAYERS + 1] // Keep track of the current colour they are trailing

new g_iTrailMenuPos[MAX_PLAYERS + 1] // Page the player is on in the menu
new g_iMenuTrailColourIndex[MAX_PLAYERS + 1][MAX_PLAYER_TRAIL_COLOURS] // Store indexes to the colours as the player builds their trail in the menu
new g_iMenuTrailColourIndexCount[MAX_PLAYERS + 1]

new const g_sTextTrailHelp[] = "Type \"trail help\" for more information"
new const g_sTrailHelpFile[] = "help/fm_trailing.txt"
new g_sTrailHelpPath[128]

new g_iEnt, g_iMaxPlayers, g_iLaserBeam
new g_pCvarEnabled, g_pCvarAutoLoad, g_pCvarTrailLife, g_pCvarTrailWidth

new g_iPlayerQuery[MAX_PLAYERS + 1]
new g_sQuery[256]

public plugin_precache()
{
	g_iLaserBeam = fm_SafePrecacheModel("sprites/fm/smoke.spr")
}

public plugin_init()
{
	fm_RegisterPlugin()

	g_pCvarEnabled = register_cvar("fm_trail_enabled", "1")
	g_pCvarAutoLoad = register_cvar("fm_trail_autoload", "1")
	g_pCvarTrailLife = register_cvar("fm_trail_life", "50")	
	g_pCvarTrailWidth = register_cvar("fm_trail_width", "15")

	register_clcmd("say", "Handle_Say")
	register_clcmd("say_team", "Handle_Say")
	register_clcmd("trail", "Handle_Console")
}

public fm_InitConfigExec()
{
	if (!get_pcvar_num(g_pCvarEnabled))
	{
		g_bTrailEnabled = false
	}
	else
	{
		register_clcmd("fm_trail_menu", "TrailMenu")
		register_menucmd(register_menuid("Select Trail"), ALL_MENU_KEYS, "Command_SelectTrail")

		register_forward(FM_SetOrigin, "Forward_SetOrigin")
		register_forward(FM_SetOrigin, "Forward_SetOriginPost", 1)	
		register_event("Spectator", "Event_Spectator", "a")

		fm_BuildAMXFilePath(g_sTrailHelpFile, g_sTrailHelpPath, charsmax(g_sTrailHelpPath), FM_AMXX_LOCAL_CONFIGS)

		CreateTrailTimerEntity()
		g_iMaxPlayers = get_maxplayers()
	}
}

CreateTrailTimerEntity()
{
	g_iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	if (!g_iEnt) 
	{
		fm_WarningLog(FM_ENT_WARNING)
	}
	else
	{
		set_pev(g_iEnt, pev_nextthink, get_gametime() + 1.0)
		register_forward(FM_Think, "Forward_TrailTimer")	
	}
} 

public Forward_TrailTimer(iEnt)
{
	if (iEnt != g_iEnt)
	{
		return FMRES_IGNORED
	}

	static Float:fVelocity[3]

	for (new i = 1; i <= g_iMaxPlayers; i++)
	{
		if (!is_user_connected(i) || !g_iPlayerTrailColourNum[i])
		{
			continue
		}

		// If a trail catches up with the player it will be removed, so check if they are standing still
		// In theory there could be a gap where the trail catches up and the player moves before the timer kicks in
		// But it seems to work flawlessly, I suspect there is a delay before the trail is removed after being set

		// Simply "re-trailing" a moving player would result in an ugly break in the trail
		// Also check they don't have a random colour value, because this would result in a break anyway

		// TODO: Detect whether the player is on a lift or a conveyor
		if (g_iPlayerTrailColourNum[i] == 1 && (
			g_iPlayerTrailColours[i][0] != -1 ||
			g_iPlayerTrailColours[i][1] != -1 ||
			g_iPlayerTrailColours[i][2] != -1 ))
		{
			pev(i, pev_velocity, fVelocity)
			if (vector_length(fVelocity))
			{
				continue
			}
		}

		// Even if they are trailing a single colour, I keep rendering the trail on timer to ensure it hasn't been overwritten by tfc
		RenderTrail(i,
			g_iPlayerTrailColours[i][g_iPlayerTrailPos[i] * 3],
			g_iPlayerTrailColours[i][g_iPlayerTrailPos[i] * 3 + 1],
			g_iPlayerTrailColours[i][g_iPlayerTrailPos[i] * 3 + 2]
		)

		if (++g_iPlayerTrailPos[i] >= g_iPlayerTrailColourNum[i])
		{
			g_iPlayerTrailPos[i] = 0
		}
	}
	set_pev(iEnt,pev_nextthink, get_gametime() + 1.0)
	return FMRES_IGNORED
}


public Event_Spectator()
{
	new id = read_data(1)

	if (g_iPlayerTrailColourNum[id])
	{
		g_iPlayerTempTrailColourNum[id] = g_iPlayerTrailColourNum[id]
		g_iPlayerTrailColourNum[id] = 0
		DisableTrail(id)
	}
}

public Forward_SetOrigin(id, Float:fOrigin[3])
{
	if (id < 1 || id > g_iMaxPlayers)
	{
		return FMRES_IGNORED
	}
	
	if (!is_user_connected(id) || !pev(id, pev_team) || !pev(id, pev_playerclass))
	{
		return FMRES_IGNORED
	}

	if (g_iPlayerTrailColourNum[id])
	{
		g_iPlayerTempTrailColourNum[id] = g_iPlayerTrailColourNum[id]
		g_iPlayerTrailColourNum[id] = 0
		DisableTrail(id)
	}
	return FMRES_IGNORED
}

public Forward_SetOriginPost(id, Float:fOrigin[3])
{
	if (id < 1 || id > g_iMaxPlayers)
	{
		return FMRES_IGNORED
	}

	if (!is_user_connected(id) || !pev(id, pev_team) || !pev(id, pev_playerclass))
	{
		return FMRES_IGNORED
	}

	if (g_iPlayerTempTrailColourNum[id])
	{
		g_iPlayerTrailColourNum[id] = g_iPlayerTempTrailColourNum[id]
		g_iPlayerTempTrailColourNum[id] = 0

		RenderTrail(id,
			g_iPlayerTrailColours[id][g_iPlayerTrailPos[id] * 3],
			g_iPlayerTrailColours[id][g_iPlayerTrailPos[id] * 3 + 1],
			g_iPlayerTrailColours[id][g_iPlayerTrailPos[id] * 3 + 2]
		)
	}
	return FMRES_IGNORED
}

public Handle_Console(id) 
{
	new sArgs[192]; read_args(sArgs, charsmax(sArgs))
	remove_quotes(sArgs)

	if (!sArgs[0])
	{
		TrailMenu(id)
	}
	else
	{
		Handle_Trail(id, sArgs, print_console)
	}
}

public Handle_Say(id)
{
	new sArgs[192]; read_args(sArgs, charsmax(sArgs))
	remove_quotes(sArgs)

	if (equali(sArgs, "trail", 5)) 
	{
		if (!sArgs[5])
		{
			TrailMenu(id)
			return PLUGIN_HANDLED
		}
		
		if (sArgs[5] == ' ')
		{
			Handle_Trail(id, sArgs[6], print_chat)
			return PLUGIN_HANDLED		
		}	
	}
	return PLUGIN_CONTINUE
}


Handle_Trail(id, sArgs[], iPrintType) 
{		
	if (!g_bTrailEnabled)
	{
		client_print(id, iPrintType, "%sTrailing is disabled", fm_PrintStar(iPrintType))
		return PLUGIN_CONTINUE
	}

	if (equali(sArgs, "off") || equali(sArgs, "stop") || equali(sArgs, "kill") || equali(sArgs, "none"))
	{
		if (!g_iPlayerTrailColourNum[id])
		{
			client_print(id, iPrintType, "%sYou are not currently trailing", fm_PrintStar(iPrintType))		
		}
		else 
		{
			RenderTrail(id, 0, 0, 0)
			g_iPlayerTrailColourNum[id] = 0
			client_print(id, iPrintType, "%sYou have turned your trail off", fm_PrintStar(iPrintType))	

			SavePlayerTrail(id)
		}
	}		
	else if (equali(sArgs, "menu"))
	{
		TrailMenu(id)
	}
	else if (equali(sArgs, "help"))
	{
		TrailHelp(id)
	}
	
	else if (equali(sArgs, "custom", 6) && ((sArgs[6] == ' ') || !sArgs[6]))
	{
		CustomTrail(id, sArgs[7], iPrintType)
	}
	else
	{
		new sBuffer[192], sColourName[MAX_COLOUR_NAME_LEN], iColourIndex[MAX_PLAYER_TRAIL_COLOURS], iColourIndexCount
		copy(sBuffer, charsmax(sBuffer), sArgs)
		
		while (iColourIndexCount < MAX_PLAYER_TRAIL_COLOURS)
		{
			strbreak(sBuffer, sColourName, charsmax(sColourName), sBuffer,  charsmax(sBuffer))	
			if (!sColourName[0])
			{
				break
			}
				
			if ((iColourIndex[iColourIndexCount] = fm_GetColourIndex(sColourName)) == -1) // Check the colour is valid, store the index in the trail list if so
			{
				client_print(id, iPrintType, "%s\"%s\" is not a recognised colour. %s", fm_PrintStar(iPrintType), sColourName, g_sTextTrailHelp)
				return PLUGIN_CONTINUE
			}
			iColourIndexCount++
		}
	
		if (!iColourIndexCount)
		{
			client_print(id, iPrintType, "%sYou didn't specify any colours. %s", fm_PrintStar(iPrintType), g_sTextTrailHelp)
			return PLUGIN_CONTINUE
		}
	
		SetPlayerTrail(id, iColourIndex, iColourIndexCount, iPrintType)
	}
	return PLUGIN_CONTINUE
}

SetPlayerTrail(id, iColourIndex[], iColourIndexCount, iPrintType)
{
	new iColourValues[3], sBuffer[MAX_CHAT_LEN]
	for (new i = 0; i < iColourIndexCount; i++)
	{
		fm_GetColoursByIndex(iColourIndex[i], iColourValues)	 	
		
		g_iPlayerTrailColours[id][i * 3    ] = iColourValues[0]
		g_iPlayerTrailColours[id][i * 3 + 1] = iColourValues[1]
		g_iPlayerTrailColours[id][i * 3 + 2] = iColourValues[2]
	}
		
	RenderTrail(id, g_iPlayerTrailColours[id][0], g_iPlayerTrailColours[id][1], g_iPlayerTrailColours[id][2])
	g_iPlayerTrailColourNum[id] = iColourIndexCount
	g_iPlayerTrailPos[id] = 0
		
	formatex(sBuffer, charsmax(sBuffer), "%sYou begin trailing ", fm_PrintStar(iPrintType))
	AddTrailNameList(iColourIndex, iColourIndexCount, sBuffer, charsmax(sBuffer))
	client_print(id, iPrintType, sBuffer)

	SavePlayerTrail(id)
}


RenderTrail(id, iRed, iGreen, iBlue) 
{
	DisableTrail(id)
			
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY) 
	write_byte(22)
	write_short(id)
	write_short(g_iLaserBeam)
	write_byte(get_pcvar_num(g_pCvarTrailLife))
	write_byte(get_pcvar_num(g_pCvarTrailWidth))
	write_byte(iRed == -1 ? random(255) : iRed)
	write_byte(iGreen == -1 ? random(255) : iGreen)
	write_byte(iBlue  == -1 ? random(255) : iBlue)
	write_byte(200)
	message_end()
}

DisableTrail(id)
{
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(99)
	write_short(id)
	message_end()
}

AddTrailNameList(iColourIndex[], iColourIndexCount, sStringOut[], iStringOutLen)
{
	new sColourName[MAX_COLOUR_NAME_LEN]
	for (new i = 0; i < iColourIndexCount; i++)	
	{
		fm_GetColourNameByIndex(iColourIndex[i], sColourName)
		add(sStringOut, iStringOutLen, sColourName)

		if (i == iColourIndexCount - 1)
		{
			break
		}
		else if (i == iColourIndexCount - 2)
		{
			add(sStringOut, iStringOutLen, " & ") 
		}
		else
		{
			add(sStringOut, iStringOutLen, ", ")
		}
	}
}

// -------------------------------------------------------------------------------------------------------------
// TRAIL MENU
// -------------------------------------------------------------------------------------------------------------

public TrailMenu(id)
{
	if (!g_bTrailEnabled)
	{
		client_print(id, print_chat, "* Trailing is disabled")
		return PLUGIN_CONTINUE
	}
	
	if (!fm_GetColourCount())
	{
		client_print(id, print_chat, "* There are no colours availiable")
		return PLUGIN_CONTINUE
	}
	
	g_iMenuTrailColourIndexCount[id] = 0
	g_iTrailMenuPos[id] = 0	
		
	SelectTrail(id, g_iTrailMenuPos[id])
	client_print(id, print_chat, "* Select up to %d colours then press \"Finish\" to begin trailing.", MAX_PLAYER_TRAIL_COLOURS)
		
	return PLUGIN_CONTINUE
}

SelectTrail(id, iPos = 0)
{
	if(iPos < 0) 
	{
		return PLUGIN_HANDLED	
	}
	
	new sMenuText[MAX_MENU_STRING], iCurrentKey, iKeys
	new iColourCount = fm_GetColourCount()	

	new iStart = iPos * MAX_MENU_TRAILS	
	new iEnd = iStart + MAX_MENU_TRAILS
	
	new iLen = formatex(sMenuText, charsmax(sMenuText), "Select Trail: Page %d/%d\n\n", iPos + 1, (iColourCount / MAX_MENU_TRAILS + ((iColourCount % MAX_MENU_TRAILS) ? 1 : 0 )) )
	
	if(iEnd > iColourCount)
	{
		iEnd = iColourCount
	}
	
	new sColourName[MAX_COLOUR_NAME_LEN]
	for(new i = iStart; i < iEnd; i++)
	{
		fm_GetColourNameByIndex(i, sColourName)
		iLen += formatex(sMenuText[iLen], (charsmax(sMenuText) - iLen), "%d) %s\n", iCurrentKey + 1, sColourName)
		iKeys |= (1<<iCurrentKey++)
	}

	if (g_iMenuTrailColourIndexCount[id] > 0)
	{
		iLen += formatex(sMenuText[iLen], (charsmax(sMenuText) - iLen), "\n8) Finish")
		iKeys |= (1<<7)
	}

	if(iEnd != iColourCount) 
	{
		iLen += formatex(sMenuText[iLen], (charsmax(sMenuText) - iLen), "\n9) More")
		iKeys |= (1<<8)
	}
	
	formatex(sMenuText[iLen], (charsmax(sMenuText) - iLen), "\n0) %s", iPos ? "Back" : "Cancel")
	iKeys |= (1<<9)
		
	show_menu(id, iKeys, sMenuText)

	return PLUGIN_HANDLED
}

public Command_SelectTrail(id, iKey) 
{
	switch(iKey) 
	{
		case 7: MenuTrailFinished(id)
		case 8: SelectTrail(id, ++g_iTrailMenuPos[id])
		case 9: SelectTrail(id, --g_iTrailMenuPos[id])
		default: 
		{
			new iTrail = g_iTrailMenuPos[id] * MAX_MENU_TRAILS + iKey 
			g_iMenuTrailColourIndex[id][g_iMenuTrailColourIndexCount[id]] = iTrail // Add to menu array
			
			// -------------------------------------------------------------------------------------------------------------
			// Finish the trail automatically if they have selected the max colours
			// -------------------------------------------------------------------------------------------------------------
			if (++g_iMenuTrailColourIndexCount[id] >= MAX_PLAYER_TRAIL_COLOURS)
			{
				MenuTrailFinished(id) 
			}
			else
			{
				// -------------------------------------------------------------------------------------------------------------
				// Show the menu again until they reach the max colours or select finish
				// -------------------------------------------------------------------------------------------------------------
				SelectTrail(id, g_iTrailMenuPos[id]) 
				
				// -------------------------------------------------------------------------------------------------------------
				// Format the string to tell the player what colours they have selected so far
				// -------------------------------------------------------------------------------------------------------------				
				new sBuffer[128]; formatex(sBuffer, charsmax(sBuffer), "* Add another colour or select \"Finish\" to begin trailing ")
				AddTrailNameList(g_iMenuTrailColourIndex[id], g_iMenuTrailColourIndexCount[id], sBuffer, charsmax(sBuffer))
				client_print(id, print_chat, sBuffer)
			}
		}
	}
	fm_PlaySound(id, FM_MENU_SELECT_SOUND)
	return PLUGIN_HANDLED
}  

MenuTrailFinished(id)
{
	SetPlayerTrail(id, g_iMenuTrailColourIndex[id], g_iMenuTrailColourIndexCount[id], print_chat)

	g_iTrailMenuPos[id] = 0
	g_iMenuTrailColourIndexCount[id] = 0
}

CustomTrail(id, sArgs[], iPrintType)
{
	new sBuffer[128]; copy(sBuffer, charsmax(sBuffer), sArgs)
	
	new iColourCount, iValueCount, sColourValue[4]
	new iColourValues[MAX_PLAYER_TRAIL_COLOURS * 3]
	
	while (iValueCount < MAX_PLAYER_TRAIL_COLOURS * 3) // Load the R G & B values
	{
		strbreak(sBuffer, sColourValue, charsmax(sColourValue), sBuffer, charsmax(sBuffer))
		if (!sColourValue[0])
		{
			break
		}
	
		iColourValues[iValueCount] = str_to_num(sColourValue)
	
		if(!is_str_num2(sColourValue) || iColourValues[iValueCount] < -1 || iColourValues[iValueCount] > 255)
		{
			client_print(id, iPrintType, "%sColour values must be between -1 (Random) and 255. %s", fm_PrintStar(iPrintType), g_sTextTrailHelp)
			return PLUGIN_CONTINUE
		}
		
		iValueCount++
	}
	
	if (!iValueCount)
	{
		client_print(id, iPrintType, "%sYou didn't specify any colour values. %s", fm_PrintStar(iPrintType), g_sTextTrailHelp)
		return PLUGIN_CONTINUE
	}

	if (iValueCount % 3)
	{
		client_print(id, iPrintType, "%sYou didn't specify enough colour values. %s", fm_PrintStar(iPrintType), g_sTextTrailHelp)
		return PLUGIN_CONTINUE
	}
	
	iColourCount = iValueCount / 3
	
	new iLen = formatex(sBuffer, charsmax(sBuffer), "%sYou begin trailing custom", fm_PrintStar(iPrintType))
	for (new i = 0; i < iColourCount; i++)
	{
		iLen += formatex(sBuffer[iLen], charsmax(sBuffer) - iLen, " (%d %d %d)", iColourValues[i * 3], iColourValues[i * 3 + 1], iColourValues[i * 3 + 2])
		
		g_iPlayerTrailColours[id][i * 3    ] = iColourValues[i * 3    ]
		g_iPlayerTrailColours[id][i * 3 + 1] = iColourValues[i * 3 + 1]
		g_iPlayerTrailColours[id][i * 3 + 2] = iColourValues[i * 3 + 2]	 
	}
	client_print(id, iPrintType, sBuffer)
	
	RenderTrail(id, g_iPlayerTrailColours[id][0], g_iPlayerTrailColours[id][1], g_iPlayerTrailColours[id][2])
	g_iPlayerTrailColourNum[id] = iColourCount
	g_iPlayerTrailPos[id] = 0
	
	SavePlayerTrail(id)

	return PLUGIN_CONTINUE
}

// -------------------------------------------------------------------------------------------------------------
// TRAIL SAVING / LOADING
// -------------------------------------------------------------------------------------------------------------

public fm_SQLPlayerIdent(id, player_id)
{
	if (g_bTrailEnabled && get_pcvar_num(g_pCvarAutoLoad) == 1)
	{
		if (g_iPlayerQuery[id])
		{
			 fm_SQLRemoveThreadedQuery(g_iPlayerQuery[id])
		}

		new Data[1]; Data[0] = id
		formatex(g_sQuery, charsmax(g_sQuery), "SELECT player_trail FROM players WHERE player_id = %d LIMIT 1;", player_id)
		g_iPlayerQuery[id] = fm_SQLAddThreadedQuery(g_sQuery, "Handle_SelectPlayerTrail", QUERY_DISPOSABLE, PRIORITY_NORMAL, Data, 1)
	}
}

public client_disconnect(id)
{
	g_iTrailMenuPos[id] = 0
	g_iMenuTrailColourIndexCount[id] = 0
	g_iPlayerTrailColourNum[id] = 0
	g_iPlayerTempTrailColourNum[id] = 0

	g_iPlayerTrailPos[id] = 0
	
	if (g_iPlayerQuery[id])
	{
		fm_SQLRemoveThreadedQuery(g_iPlayerQuery[id])
		g_iPlayerQuery[id] = 0
	}
}

public Handle_SelectPlayerTrail(iFailState, Handle:hQuery, sError[], iError, Data[], iDataSize, Float:fQueueTime, iQueryIdent)
{
	fm_DebugPrintLevel(1, "Handle_SelectPlayerTrail: %f", fQueueTime)

	if(fm_SQLCheckThreadedError(iFailState, hQuery, sError, iError))
	{
		return PLUGIN_HANDLED	
	}

	new id = Data[0]

	// Check the player that this query belonged to is still ingame. This shouldn't occur because I remove the query on disconnect
	// But it could happen if the query is running when we try to remove it. is_user_connected(id) as a failsafe
	if (g_iPlayerQuery[id] != iQueryIdent || !is_user_connected(id))
	{
		return PLUGIN_HANDLED
	}

	if (!SQL_IsNull(hQuery, 0))
	{
		new sColour[4], iColourValueCount, sTrail[MAX_PLAYER_TRAIL_COLOURS * 12] // "000 000 000 "
		SQL_ReadResult(hQuery, 0, sTrail , charsmax(sTrail))

		while (iColourValueCount < MAX_PLAYER_TRAIL_COLOURS * 3) // Load all the RGB values up to the max colours
		{
			strbreak(sTrail, sColour, charsmax(sColour), sTrail, charsmax(sTrail))
			if (!sColour[0])
			{
				break
			}
			g_iPlayerTrailColours[id][iColourValueCount++] = str_to_num(sColour)
		}

		// Only render the trail initially if they are alive
		if (!is_user_alive(id))
		{
			g_iPlayerTrailColourNum[id] = 0
			g_iPlayerTempTrailColourNum[id] = iColourValueCount / 3
		}
		else
		{
			g_iPlayerTempTrailColourNum[id] = 0
			g_iPlayerTrailColourNum[id] = iColourValueCount / 3
			RenderTrail(id, g_iPlayerTrailColours[id][0], g_iPlayerTrailColours[id][1], g_iPlayerTrailColours[id][2]) 
		}
	}
	return PLUGIN_HANDLED
}


SavePlayerTrail(id)
{
	if (g_iPlayerQuery[id])
	{
		fm_SQLRemoveThreadedQuery(g_iPlayerQuery[id])
	}

	// Get the players player_id
	new iPlayerIdent = fm_SQLGetUserIdent(id)
	if (!iPlayerIdent)
	{
		return PLUGIN_CONTINUE
	}
	
	new iLen = formatex(g_sQuery, charsmax(g_sQuery), "UPDATE players SET player_trail = ")

	if (!g_iPlayerTrailColourNum[id])
	{	
		iLen += formatex(g_sQuery[iLen], charsmax(g_sQuery) - iLen, "NULL")
	}
	else
	{
		iLen += add(g_sQuery[iLen], charsmax(g_sQuery) - iLen, "'")
		for (new i = 0; i < g_iPlayerTrailColourNum[id] * 3; i++)
		{
			iLen += formatex(g_sQuery[iLen], charsmax(g_sQuery) - iLen, "%d ", g_iPlayerTrailColours[id][i])
		}
		iLen--
		iLen += add(g_sQuery[iLen], charsmax(g_sQuery) - iLen, "'")
	}

	iLen += formatex(g_sQuery[iLen], charsmax(g_sQuery) - iLen, " WHERE player_id = %d LIMIT 1;", iPlayerIdent)

	new Data[1]; Data[0] = id
	g_iPlayerQuery[id] = fm_SQLAddThreadedQuery(g_sQuery, "Handle_UpdatePlayerTrail", QUERY_DISPOSABLE, PRIORITY_LOW, Data, 1)
	
	return PLUGIN_CONTINUE	
}

public Handle_UpdatePlayerTrail(iFailState, Handle:hQuery, sError[], iError, Data[], iDataSize, Float:fQueueTime, iQueryIdent)
{
	fm_DebugPrintLevel(1, "Handle_UpdatePlayerTrail: %f", fQueueTime)
	fm_SQLCheckThreadedError(iFailState, hQuery, sError, iError)

	g_iPlayerQuery[Data[0]] = 0
}


TrailHelp(id)
{
	show_motd(id, g_sTrailHelpPath, "Trail Help")
}
