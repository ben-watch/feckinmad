#include "feckinmad/fm_global"
#include "feckinmad/fm_config" // fm_InitConfigExec() forward
#include "feckinmad/fm_colour_api" // fm_GetColourIndex(...) etc
#include "feckinmad/fm_menu" // MAX_MENU_STRING etc
#include "feckinmad/fm_sql_tquery"
#include "feckinmad/fm_sql_player"

#include <fakemeta>

#define MAX_PLAYER_GLOW_COLOURS 5 // Maximum number of colours a player can glow
#define MAX_MENU_GLOWS 7 // Number of glows per page in the menu

new bool:g_bGlowEnabled = true

new Float:g_fPlayerGlowColours[MAX_PLAYERS + 1][MAX_PLAYER_GLOW_COLOURS * 3] // Stores the players current glow colours
new g_iPlayerGlowColourNum[MAX_PLAYERS + 1] // Amount of colours the player is glowing
new g_iPlayerGlowPos[MAX_PLAYERS + 1] // Keep track of the current colour they are glowing

new g_iGlowMenuPos[MAX_PLAYERS + 1] // Page the player is on in the menu
new g_iMenuGlowColourIndex[MAX_PLAYERS + 1][MAX_PLAYER_GLOW_COLOURS] // Store indexes to the colours as the player builds their glow in the menu
new g_iMenuGlowColourIndexCount[MAX_PLAYERS + 1]

new const g_sTextGlowHelp[] = "Type \"glow help\" for more information"
new const g_sGlowHelpFile[] = "help/fm_glowing.txt"
new g_sGlowHelpPath[128]

new g_iEnt, g_iMaxPlayers
new g_pCvarEnabled, g_pCvarAutoLoad

new g_iPlayerQuery[MAX_PLAYERS + 1]
new g_sQuery[256]

public fm_PluginInit()
{
	g_pCvarEnabled = register_cvar("fm_glow_enabled", "1")
	g_pCvarAutoLoad = register_cvar("fm_glow_autoload", "1")

	register_clcmd("say", "Handle_Say")
	register_clcmd("say_team", "Handle_Say")
	register_clcmd("glow", "Handle_Console")
}

public fm_InitConfigExec()
{
	if (!get_pcvar_num(g_pCvarEnabled))
	{
		g_bGlowEnabled = false
	}
	else
	{
		register_clcmd("fm_glow_menu", "GlowMenu")
		register_menucmd(register_menuid("Select Glow"), ALL_MENU_KEYS, "Command_SelectGlow")

		fm_BuildAMXFilePath(g_sGlowHelpFile, g_sGlowHelpPath, charsmax(g_sGlowHelpPath), FM_AMXX_LOCAL_CONFIGS)

		CreateGlowTimerEntity()
		g_iMaxPlayers = get_maxplayers()
	}
}

CreateGlowTimerEntity()
{
	g_iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	if (!g_iEnt) 
	{
		fm_WarningLog(FM_ENT_WARNING)
	}
	else
	{
		set_pev(g_iEnt, pev_nextthink, get_gametime() + 1.0)
		register_forward(FM_Think, "Forward_GlowTimer")	
	}
} 

public Forward_GlowTimer(iEnt)
{
	if (iEnt != g_iEnt)
	{
		return FMRES_IGNORED
	}

	for (new i = 1; i <= g_iMaxPlayers; i++)
	{
		if (!is_user_connected(i) || !g_iPlayerGlowColourNum[i])
		{
			continue
		}

		// Even if they are glowing a single colour, I keep rendering the glow on timer to ensure it hasn't been overwritten by tfc
		RenderGlow(i,
			g_fPlayerGlowColours[i][g_iPlayerGlowPos[i] * 3],
			g_fPlayerGlowColours[i][g_iPlayerGlowPos[i] * 3 + 1],
			g_fPlayerGlowColours[i][g_iPlayerGlowPos[i] * 3 + 2]
		)

		if (++g_iPlayerGlowPos[i] >= g_iPlayerGlowColourNum[i])
		{
			g_iPlayerGlowPos[i] = 0
		}
	}
	set_pev(iEnt,pev_nextthink, get_gametime() + 1.0)
	return FMRES_IGNORED
}


public Handle_Console(id) 
{
	new sArgs[192]; read_args(sArgs, charsmax(sArgs))
	remove_quotes(sArgs)

	if (!sArgs[0])
	{
		GlowMenu(id)
	}
	else
	{
		Handle_Glow(id, sArgs, print_console)
	}
}

public Handle_Say(id)
{
	new sArgs[192]; read_args(sArgs, charsmax(sArgs))
	remove_quotes(sArgs)

	if (equali(sArgs, "glow", 4)) 
	{
		if (!sArgs[4])
		{
			GlowMenu(id)
			return PLUGIN_HANDLED
		}
		
		if (sArgs[4] == ' ')
		{
			Handle_Glow(id, sArgs[5], print_chat)
			return PLUGIN_HANDLED		
		}	
	}
	return PLUGIN_CONTINUE
}


Handle_Glow(id, sArgs[], iPrintType) 
{		
	if (!g_bGlowEnabled)
	{
		client_print(id, iPrintType, "%sGlowing is disabled", fm_PrintStar(iPrintType))
		return PLUGIN_CONTINUE
	}

	if (equali(sArgs, "off") || equali(sArgs, "stop") || equali(sArgs, "kill") || equali(sArgs, "none"))
	{
		if (!g_iPlayerGlowColourNum[id])
		{
			client_print(id, iPrintType, "%sYou are not currently glowing", fm_PrintStar(iPrintType))		
		}
		else 
		{
			RenderGlow(id, 0.0, 0.0, 0.0, kRenderFxNone)
			g_iPlayerGlowColourNum[id] = 0
			client_print(id, iPrintType, "%sYou have turned your glow off", fm_PrintStar(iPrintType))	

			SavePlayerGlow(id)
		}
	}		
	else if (equali(sArgs, "menu"))
	{
		GlowMenu(id)
	}
	else if (equali(sArgs, "help"))
	{
		GlowHelp(id)
	}
	
	else if (equali(sArgs, "custom", 6) && ((sArgs[6] == ' ') || !sArgs[6]))
	{
		CustomGlow(id, sArgs[7], iPrintType)
	}
	else
	{
		new sBuffer[192], sColourName[MAX_COLOUR_NAME_LEN], iColourIndex[MAX_PLAYER_GLOW_COLOURS], iColourIndexCount
		copy(sBuffer, charsmax(sBuffer), sArgs)
		
		while (iColourIndexCount < MAX_PLAYER_GLOW_COLOURS)
		{
			argbreak(sBuffer, sColourName, charsmax(sColourName), sBuffer,  charsmax(sBuffer))	
			if (!sColourName[0])
			{
				break
			}
				
			if ((iColourIndex[iColourIndexCount] = fm_GetColourIndex(sColourName)) == -1) // Check the colour is valid, store the index in the glow list if so
			{
				client_print(id, iPrintType, "%s\"%s\" is not a recognised colour. %s", fm_PrintStar(iPrintType), sColourName, g_sTextGlowHelp)
				return PLUGIN_CONTINUE
			}
			iColourIndexCount++
		}
	
		if (!iColourIndexCount)
		{
			client_print(id, iPrintType, "%sYou didn't specify any colours. %s", fm_PrintStar(iPrintType), g_sTextGlowHelp)
			return PLUGIN_CONTINUE
		}
	
		SetPlayerGlow(id, iColourIndex, iColourIndexCount, iPrintType)
	}
	return PLUGIN_CONTINUE
}

SetPlayerGlow(id, iColourIndex[], iColourIndexCount, iPrintType)
{
	new iColourValues[3], sBuffer[MAX_CHAT_LEN]
	for (new i = 0; i < iColourIndexCount; i++)
	{
		fm_GetColoursByIndex(iColourIndex[i], iColourValues)
		g_fPlayerGlowColours[id][i * 3    ] = float(iColourValues[0])
		g_fPlayerGlowColours[id][i * 3 + 1] = float(iColourValues[1])
		g_fPlayerGlowColours[id][i * 3 + 2] = float(iColourValues[2])	 	
	}
		
	RenderGlow(id, g_fPlayerGlowColours[id][0], g_fPlayerGlowColours[id][1], g_fPlayerGlowColours[id][2])
	g_iPlayerGlowColourNum[id] = iColourIndexCount
	g_iPlayerGlowPos[id] = 0
		
	formatex(sBuffer, charsmax(sBuffer), "%sYou begin glowing ", fm_PrintStar(iPrintType))
	AddGlowNameList(iColourIndex, iColourIndexCount, sBuffer, charsmax(sBuffer))
	client_print(id, iPrintType, sBuffer)

	SavePlayerGlow(id)
}

RenderGlow(id, Float:fRed, Float:fGreen, Float:fBlue, iRenderFX = kRenderFxGlowShell) 
{
	new Float:fColour[3]
	fColour[0] = fRed == -1.0 ? float(random(255)) : fRed
	fColour[1] = fGreen == -1.0 ? float(random(255)) : fGreen
	fColour[2] = fBlue  == -1.0 ? float(random(255)) : fBlue
	
	set_pev(id, pev_renderfx, iRenderFX)
	set_pev(id, pev_rendercolor, fColour)
	set_pev(id, pev_rendermode, kRenderNormal)
	set_pev(id, pev_renderamt, 0.0)
}

AddGlowNameList(iColourIndex[], iColourIndexCount, sStringOut[], iStringOutLen)
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
// GLOW MENU
// -------------------------------------------------------------------------------------------------------------

public GlowMenu(id)
{
	if (!g_bGlowEnabled)
	{
		client_print(id, print_chat, "* Glowing is disabled")
		return PLUGIN_CONTINUE
	}
	
	if (!fm_GetColourCount())
	{
		client_print(id, print_chat, "* There are no colours availiable")
		return PLUGIN_CONTINUE
	}
	
	g_iMenuGlowColourIndexCount[id] = 0
	g_iGlowMenuPos[id] = 0	
		
	SelectGlow(id, g_iGlowMenuPos[id])
	client_print(id, print_chat, "* Select up to %d colours then press \"Finish\" to begin glowing.", MAX_PLAYER_GLOW_COLOURS)
		
	return PLUGIN_CONTINUE
}

SelectGlow(id, iPos = 0)
{
	if(iPos < 0) 
	{
		return PLUGIN_HANDLED	
	}
	
	new sMenuText[MAX_MENU_STRING], iCurrentKey, iKeys
	new iColourCount = fm_GetColourCount()	

	new iStart = iPos * MAX_MENU_GLOWS	
	new iEnd = iStart + MAX_MENU_GLOWS
	
	new iLen = formatex(sMenuText, charsmax(sMenuText), "Select Glow: Page %d/%d\n\n", iPos + 1, (iColourCount / MAX_MENU_GLOWS + ((iColourCount % MAX_MENU_GLOWS) ? 1 : 0 )) )
	
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

	if (g_iMenuGlowColourIndexCount[id] > 0)
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

public Command_SelectGlow(id, iKey) 
{
	switch(iKey) 
	{
		case 7: MenuGlowFinished(id)
		case 8: SelectGlow(id, ++g_iGlowMenuPos[id])
		case 9: SelectGlow(id, --g_iGlowMenuPos[id])
		default: 
		{
			new iGlow = g_iGlowMenuPos[id] * MAX_MENU_GLOWS + iKey 
			g_iMenuGlowColourIndex[id][g_iMenuGlowColourIndexCount[id]] = iGlow // Add to menu array
			
			// -------------------------------------------------------------------------------------------------------------
			// Finish the glow automatically if they have selected the max colours
			// -------------------------------------------------------------------------------------------------------------
			if (++g_iMenuGlowColourIndexCount[id] >= MAX_PLAYER_GLOW_COLOURS)
			{
				MenuGlowFinished(id) 
			}
			else
			{
				// -------------------------------------------------------------------------------------------------------------
				// Show the menu again until they reach the max colours or select finish
				// -------------------------------------------------------------------------------------------------------------
				SelectGlow(id, g_iGlowMenuPos[id]) 
				
				// -------------------------------------------------------------------------------------------------------------
				// Format the string to tell the player what colours they have selected so far
				// -------------------------------------------------------------------------------------------------------------				
				new sBuffer[128]; formatex(sBuffer, charsmax(sBuffer), "* Add another colour or select \"Finish\" to begin glowing ")
				AddGlowNameList(g_iMenuGlowColourIndex[id], g_iMenuGlowColourIndexCount[id], sBuffer, charsmax(sBuffer))
				client_print(id, print_chat, sBuffer)
			}
		}
	}
	fm_PlaySound(id, FM_MENU_SELECT_SOUND)
	return PLUGIN_HANDLED
}  

MenuGlowFinished(id)
{
	SetPlayerGlow(id, g_iMenuGlowColourIndex[id], g_iMenuGlowColourIndexCount[id], print_chat)

	g_iGlowMenuPos[id] = 0
	g_iMenuGlowColourIndexCount[id] = 0
}

CustomGlow(id, sArgs[], iPrintType)
{
	new sBuffer[128]; copy(sBuffer, charsmax(sBuffer), sArgs)
	
	new iColourCount, iValueCount, sColourValue[4]
	new iColourValues[MAX_PLAYER_GLOW_COLOURS * 3]
	
	while (iValueCount < MAX_PLAYER_GLOW_COLOURS * 3) // Load the R G & B values
	{
		argbreak(sBuffer, sColourValue, charsmax(sColourValue), sBuffer, charsmax(sBuffer))
		if (!sColourValue[0])
		{
			break
		}
	
		iColourValues[iValueCount] = str_to_num(sColourValue)
	
		if(!is_str_num2(sColourValue) || iColourValues[iValueCount] < -1 || iColourValues[iValueCount] > 255)
		{
			client_print(id, iPrintType, "%sColour values must be between -1 (Random) and 255. %s", fm_PrintStar(iPrintType), g_sTextGlowHelp)
			return PLUGIN_CONTINUE
		}
		
		iValueCount++
	}
	
	if (!iValueCount)
	{
		client_print(id, iPrintType, "%sYou didn't specify any colour values. %s", fm_PrintStar(iPrintType), g_sTextGlowHelp)
		return PLUGIN_CONTINUE
	}

	if (iValueCount % 3)
	{
		client_print(id, iPrintType, "%sYou didn't specify enough colour values. %s", fm_PrintStar(iPrintType), g_sTextGlowHelp)
		return PLUGIN_CONTINUE
	}
	
	iColourCount = iValueCount / 3
	
	new iLen = formatex(sBuffer, charsmax(sBuffer), "%sYou begin glowing custom", fm_PrintStar(iPrintType))
	for (new i = 0; i < iColourCount; i++)
	{
		iLen += formatex(sBuffer[iLen], charsmax(sBuffer) - iLen, " (%d %d %d)", iColourValues[i * 3], iColourValues[i * 3 + 1], iColourValues[i * 3 + 2])
		
		g_fPlayerGlowColours[id][i * 3    ] = float(iColourValues[i * 3    ])
		g_fPlayerGlowColours[id][i * 3 + 1] = float(iColourValues[i * 3 + 1])
		g_fPlayerGlowColours[id][i * 3 + 2] = float(iColourValues[i * 3 + 2])	 
	}
	client_print(id, iPrintType, sBuffer)
	
	RenderGlow(id, g_fPlayerGlowColours[id][0], g_fPlayerGlowColours[id][1], g_fPlayerGlowColours[id][2])
	g_iPlayerGlowColourNum[id] = iColourCount
	g_iPlayerGlowPos[id] = 0
	
	SavePlayerGlow(id)

	return PLUGIN_CONTINUE
}

// -------------------------------------------------------------------------------------------------------------
// GLOW SAVING / LOADING
// -------------------------------------------------------------------------------------------------------------

public fm_SQLPlayerIdent(id, player_id)
{
	if (g_bGlowEnabled && get_pcvar_num(g_pCvarAutoLoad) == 1)
	{
		if (g_iPlayerQuery[id])
		{
			 fm_SQLRemoveThreadedQuery(g_iPlayerQuery[id])
		}

		new Data[1]; Data[0] = id
		formatex(g_sQuery, charsmax(g_sQuery), "SELECT player_glow FROM players WHERE player_id = %d LIMIT 1;", player_id)
		g_iPlayerQuery[id] = fm_SQLAddThreadedQuery(g_sQuery, "Handle_SelectPlayerGlow", QUERY_DISPOSABLE, PRIORITY_NORMAL, Data, 1)
	}
}

public client_disconnected(id)
{
	g_iGlowMenuPos[id] = 0
	g_iMenuGlowColourIndexCount[id] = 0
	g_iPlayerGlowColourNum[id] = 0
	g_iPlayerGlowPos[id] = 0

	if (g_iPlayerQuery[id])
	{
		fm_SQLRemoveThreadedQuery(g_iPlayerQuery[id])
		g_iPlayerQuery[id] = 0
	}
}

public Handle_SelectPlayerGlow(iFailState, Handle:hQuery, sError[], iError, Data[], iDataSize, Float:fQueueTime, iQueryIdent)
{
	fm_DebugPrintLevel(1, "Handle_SelectPlayerGlow: %f", fQueueTime)

	if(fm_SQLCheckThreadedError(iFailState, hQuery, sError, iError))
	{
		return PLUGIN_HANDLED	
	}

	new id = Data[0]

	// Check the player that this query belonged to is still ingame. This shouldn't occur because I remove the query on disconnect, but
	// it could happen if the query is running when we try to remove it. is_user_connected(id) as a failsafe
	if (g_iPlayerQuery[id] != iQueryIdent || !is_user_connected(id))
	{
		return PLUGIN_HANDLED
	}

	if (!SQL_IsNull(hQuery, 0))
	{
		new sColour[4], iColourValueCount, sGlow[MAX_PLAYER_GLOW_COLOURS * 12] // "000 000 000 "
		SQL_ReadResult(hQuery, 0, sGlow , charsmax(sGlow))

		while (iColourValueCount < MAX_PLAYER_GLOW_COLOURS * 3) // Load all the RGB values up to the max colours
		{
			argbreak(sGlow, sColour, charsmax(sColour), sGlow, charsmax(sGlow))
			if (!sColour[0])
			{
				break
			}
			g_fPlayerGlowColours[id][iColourValueCount++] = str_to_float(sColour)
		}
		g_iPlayerGlowColourNum[id] = iColourValueCount / 3
		RenderGlow(id, g_fPlayerGlowColours[id][0], g_fPlayerGlowColours[id][1], g_fPlayerGlowColours[id][2]) 
	}
	return PLUGIN_HANDLED
}


SavePlayerGlow(id)
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
	
	new iLen = formatex(g_sQuery, charsmax(g_sQuery), "UPDATE players SET player_glow = ")

	if (!g_iPlayerGlowColourNum[id])
	{	
		iLen += formatex(g_sQuery[iLen], charsmax(g_sQuery) - iLen, "NULL")
	}
	else
	{
		iLen += add(g_sQuery[iLen], charsmax(g_sQuery) - iLen, "'")
		for (new i = 0; i < g_iPlayerGlowColourNum[id] * 3; i++)
		{
			iLen += formatex(g_sQuery[iLen], charsmax(g_sQuery) - iLen, "%d ", floatround(g_fPlayerGlowColours[id][i]))
		}
		iLen--
		iLen += add(g_sQuery[iLen], charsmax(g_sQuery) - iLen, "'")
	}

	iLen += formatex(g_sQuery[iLen], charsmax(g_sQuery) - iLen, " WHERE player_id = %d LIMIT 1;", iPlayerIdent)

	new Data[1]; Data[0] = id
	g_iPlayerQuery[id] = fm_SQLAddThreadedQuery(g_sQuery, "Handle_UpdatePlayerGlow", QUERY_DISPOSABLE, PRIORITY_LOW, Data, 1)
	
	return PLUGIN_CONTINUE	
}

public Handle_UpdatePlayerGlow(iFailState, Handle:hQuery, sError[], iError, Data[], iDataSize, Float:fQueueTime, iQueryIdent)
{
	fm_DebugPrintLevel(1, "Handle_UpdatePlayerGlow: %f", fQueueTime)
	fm_SQLCheckThreadedError(iFailState, hQuery, sError, iError)

	g_iPlayerQuery[Data[0]] = 0
}


GlowHelp(id)
{
	show_motd(id, g_sGlowHelpPath, "Glow Help")
}
