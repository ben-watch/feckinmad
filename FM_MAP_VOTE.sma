#include "feckinmad/fm_global"
#include "feckinmad/fm_mapfunc"
#include "feckinmad/mapvote/fm_mapvote_changelevel"

#include <fakemeta>
#include <hamsandwich>

#define MAX_HUDMSG_MAPS 9 // Number of leading maps to display on the hud
#define HUD_DISPLAY_DISTANCE 4096.0 // Distance multiplier for view angle normalised vector used in the traceline
#define RESEND_MSG_DELAY 600.0 // How long to display the view hud messages

#define MODEL_RENDERAMT_ON 255.0
#define MODEL_RENDERAMT_OFF 50.0

new g_sPanelDir[16] = "models/fm/maps/" // Directory map panels are placed

new Array:g_sMapList  // Will store all the maps in the directory so we can randomly select some at random
new Array:g_sSelectedMapList // Holds the selected map panels we have precached randomly
new Array:g_iPanelEnts // Entity ids of the mapvote panels
new g_iMapCount, g_iSelectedCount, g_iPanelCount
new g_iMapCountStats, g_iMapSelectedStats

new g_sNextMap[MAX_MAP_LEN]
new Float:g_fStrength  // The strength of the panels when voting begins (based on playercount)
new g_iDisplayEnt, g_iKeyValueForward, g_iMaxPlayers

enum 
{
	VOTING_INACTIVE,
	VOTING_INIT,
	VOTING_STARTED,
	VOTING_FINISHED
}

new g_iVotingStatus = VOTING_INACTIVE

new g_iCurrentEnt[MAX_PLAYERS + 1] // Stores the entity the player is currently looking at -1 = world
new bool:g_bPlayerForceUpdate[MAX_PLAYERS + 1]  // Force a HUD update where usually there would be none

new const g_sSoundGetReady[] = "fm/mapvote/getready.wav"
new const g_sSoundCountdown[] = "fm/mapvote/countdown.wav" 
new const g_sSoundVoteStart[] = "fm/mapvote/startvote.wav"
new const g_sSoundChange[] = "fm/mapvote/change.wav"

new const g_sPanelClassName[] = "func_breakable" // TODO: Change the map to use a different classname so we can differenciate between func_breakables and mapvote panels
new const g_sPanelModelClassName[] = "fm_panel_model"

new g_pCvarStrenthMultiplier
new g_pCvarChannelDisplay
new g_pCvarChannelLeading

new g_iStrenthMultiplier

public plugin_precache()
{
	g_sMapList = ArrayCreate(MAX_MAP_LEN)
	GetMapListFromDir() // Get a list of map panels in the directory
		
	g_iPanelEnts = ArrayCreate(1)
	g_sSelectedMapList = ArrayCreate(MAX_MAP_LEN)
	g_iKeyValueForward = register_forward(FM_KeyValue, "Forward_KeyValue") // Precache a random panel for each map panel created on the map

	engfunc(EngFunc_PrecacheSound, g_sSoundGetReady)
	engfunc(EngFunc_PrecacheSound, g_sSoundVoteStart)

	engfunc(EngFunc_PrecacheSound, g_sSoundChange)
	engfunc(EngFunc_PrecacheSound, g_sSoundCountdown)	
}

public client_putinserver(id)
{
	switch(g_iVotingStatus)
	{
		case VOTING_INACTIVE:
		{
			g_iVotingStatus = VOTING_INIT
			set_task(10.0, "NumberPanels")
		}
		case VOTING_STARTED, VOTING_FINISHED: DisplayLeadingMaps(id)	
	}	
}

public NumberPanels()
{
	client_print(0, print_chat, "* %d random map panels have been selected from a total of %d availiable", g_iMapSelectedStats, g_iMapCountStats)
	DisplayPanelModels()
	set_pev(g_iDisplayEnt, pev_nextthink, get_gametime() + 0.1) // Start the hud display ent thinking
	set_task(10.0, "StrengthNote")
}

public StrengthNote()
{
	client_print(0, print_chat, "The strength of the panels is relative to the amount of players when voting starts")
	set_task(10.0, "DisplayGetReady")
}

public DisplayGetReady(iFill)
{
	fm_PlaySound(0, g_sSoundGetReady)
	client_print(0, print_chat, "* Get ready to vote for a map")
	set_task(5.0, "StartCountDown")
}

public StartCountDown(iFill)
{
	fm_PlaySound(0, g_sSoundCountdown)
	set_task(4.5, "StartVote")
}

public StartVote(iFill)
{
	fm_PlaySound(0, g_sSoundVoteStart)
	
	new iPlayerNum = get_playersnum(1)
	if (iPlayerNum)	
	{
		new iStrength = iPlayerNum * g_iStrenthMultiplier
		client_print(0, print_chat, "* Panel health multiplier is set at %d. Total players: %d. Panel Health = %d", g_iStrenthMultiplier, iPlayerNum, iStrength)

		g_fStrength = float(iStrength)

		for (new i = 0; i < g_iPanelCount; i++)
			set_pev(ArrayGetCell(g_iPanelEnts, i), pev_health, g_fStrength)
		
		
		ForceUpdateHudPanel() // Force everyones hud to update 
		
		client_print(0, print_chat,"* Vote for the map you want to play by breaking its panel")	
		client_cmd(0, "spk %s", g_sSoundVoteStart)
	
		g_iVotingStatus = VOTING_STARTED
		
	}
	else // Reset everything
	{
		DisplayPanelModels()
		g_iVotingStatus = VOTING_INACTIVE
		set_pev(g_iDisplayEnt, pev_nextthink, 0.0) // Stop the hud display ent thinking
	}
}

// Builds the dynamic array of map panel .mdl files from the directory
GetMapListFromDir()
{
	new sMapName[MAX_MAP_LEN], iLen

	new iDirHandle = open_dir(g_sPanelDir, sMapName, charsmax(sMapName))
	if (!iDirHandle)
	{
		log_amx("Error: Unable to open panel directory: \"%s\"", g_sPanelDir)
		return 0
	}

	do {
		iLen = strlen(sMapName) - 4
		if (iLen < 0 || !equali(sMapName[iLen], ".mdl")) 
			continue 		
			
		sMapName[iLen] = 0
			
		if (!fm_IsMapValid(sMapName)) // Check the map actually exists
		{
			log_amx("Warning: Unable to load panel for missing map: \"%s\"", sMapName)
			continue 
		}

		ArrayPushString(g_sMapList, sMapName)
		g_iMapCount++

	} 
	while (next_file(iDirHandle, sMapName, charsmax(sMapName)))
	close_dir(iDirHandle)	
	
	g_iMapCountStats = g_iMapCount
	
	log_amx("Loaded %d panel models from \"%s\"", g_iMapCount, g_sPanelDir)
	return 1
}

public Forward_KeyValue(iEnt, Kvd)
{
	/*if (pev_valid(iEnt))
	{
		return FMRES_IGNORED
	}*/

	// If we haven't got enough map panels to fill the map get out of here
	if (!g_iMapCount)
	{
		unregister_forward(FM_KeyValue, g_iKeyValueForward)
		return FMRES_IGNORED
	}

	static sBuffer[MAX_MAP_LEN]; get_kvd(Kvd, KV_KeyName, sBuffer, charsmax(sBuffer))
	if (equal(sBuffer, "classname"))
	{		
		get_kvd(Kvd, KV_Value, sBuffer, charsmax(sBuffer))
		if (equal(sBuffer, g_sPanelClassName))
		{
			set_kvd(Kvd, KV_Value, "func_breakable")
			
			// Randomly select a map from the panel directory list
			new iRandom = random(g_iMapCount) 
			ArrayGetString(g_sMapList, iRandom, sBuffer, charsmax(sBuffer))

			new sPath[64]; formatex(sPath, charsmax(sPath), "%s%s.mdl", g_sPanelDir, sBuffer)
			engfunc(EngFunc_PrecacheModel, sPath) // Precache the panel map model

			ArrayPushString(g_sSelectedMapList, sBuffer) // Add to the selected maps
			g_iSelectedCount++
			
			ArrayPushCell(g_iPanelEnts, iEnt) // Store the entity ID
			g_iPanelCount++
				
			ArrayDeleteItem(g_sMapList, iRandom)  // Clear this map out of the array to prevent picking it again
			g_iMapCount--
		}
	}
	else if (equal(sBuffer, "angles"))
	{
		get_kvd(Kvd, KV_Value, sBuffer, charsmax(sBuffer))
	
		// Parse the angles value and convert to float
		static Float:fAngles[3], sAngles[3][4]
		parse(sBuffer, sAngles[0], 3, sAngles[1], 3, sAngles[2], 3)
		for (new i = 0; i < 3; i++)
			fAngles[i] = str_to_float(sAngles[i])
		
		// Store in vuser1 pev
		set_pev(iEnt, pev_vuser1, fAngles)
		
		//pev(iEnt, pev_vuser1, fAngles)
		//console_print(0, "%d. pev_vuser1: %f %f %f", iEnt, fAngles[0], fAngles[1], fAngles[2])
	}
	return FMRES_IGNORED
}

public plugin_init()
{
	fm_RegisterPlugin()
	
	g_iMapSelectedStats = g_iSelectedCount
		
	unregister_forward(FM_KeyValue, g_iKeyValueForward)  // No longer required
	ArrayDestroy(g_sMapList)

	CreatePanelModels()

	// Create the ents that acts as a timers
	g_iDisplayEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target")) 
	if (!g_iDisplayEnt)
	{
		log_amx("Warning: Failed to create display timer entity")
	}
	
	register_forward(FM_Think, "Forward_Think")
	g_iMaxPlayers = get_maxplayers()

	g_pCvarStrenthMultiplier = register_cvar("fm_votemap_strength_multiplier", "2000")
	g_iStrenthMultiplier = get_pcvar_num(g_pCvarStrenthMultiplier)
	if (g_iStrenthMultiplier <= 0)
		g_iStrenthMultiplier = 1

	g_pCvarChannelDisplay = register_cvar("fm_hudchannel_display", "1")
	g_pCvarChannelLeading = register_cvar("fm_hudchannel_leading", "4")

	// Handle the damage of the panel
	RegisterHam(Ham_TakeDamage, "func_breakable", "PanelTakeDamage") 
	RegisterHam(Ham_TakeDamage, "func_breakable", "PanelTakeDamagePost", 1)
	
	return PLUGIN_CONTINUE
}


public Forward_Think(iEnt)
{
	if (iEnt == g_iDisplayEnt)
	{
		if (g_iVotingStatus == VOTING_FINISHED)
		{
			ClearPlayerHud()
			engfunc(EngFunc_RemoveEntity, iEnt)
			return FMRES_IGNORED
		}
		
		static Float:fPlayerOrigin[3]
		static Float:fPlayerViewOff[3]
		static Float:fAngles[3]
		static iRetEnt
			
		static Float:fMsgLastSent[MAX_PLAYERS + 1]

		static Float:fHealth
		static Float:fGameTime; fGameTime = get_gametime()
	
		for (new i = 1; i <= g_iMaxPlayers; i++)
		{
			if (!is_user_connected(i) || !is_user_alive(i))
				continue
				
			// Convert view angle to normalised vector
			pev(i, pev_v_angle, fAngles)
			engfunc(EngFunc_MakeVectors, fAngles)
			global_get(glb_v_forward, fAngles) // Don't need angles anymore so use it to hold vector
		
			pev(i, pev_origin, fPlayerOrigin)
			pev(i, pev_view_ofs, fPlayerViewOff)
			
			for (new j = 0; j < 3; j++)
			{
				fPlayerOrigin[j] += fPlayerViewOff[j] // Get start origin for trace
				fAngles[j] = fPlayerOrigin[j] + (fAngles[j] * HUD_DISPLAY_DISTANCE) // Get End position for trace. Scale up normalised vector and add to start origin
			}
	
			engfunc(EngFunc_TraceLine, fPlayerOrigin, fAngles, IGNORE_MONSTERS, i, 0)
			iRetEnt = get_tr2(0, TR_pHit)
			
			// If the entity they are looking at has not changed since last time
			// Or we have flagged them to force a hudmessage update
			if (g_iCurrentEnt[i] != iRetEnt || fGameTime > fMsgLastSent[i] + RESEND_MSG_DELAY || g_bPlayerForceUpdate[i])
			{
				fMsgLastSent[i] = fGameTime
				g_iCurrentEnt[i] = iRetEnt
				g_bPlayerForceUpdate[i] = false
	
				if (iRetEnt > 0)
				{	
					if (IsPanelEnt(iRetEnt))
					{
						new sTarget[MAX_MAP_LEN]; pev(iRetEnt, pev_target, sTarget, charsmax(sTarget))
						if (g_iVotingStatus != VOTING_STARTED) // The voting hasn't started so we don't know how strong it is as its based off playercount
						{
							set_hudmessage(255, 255, 255, -1.0, 0.5, 0, 0.0, RESEND_MSG_DELAY, 0.0, 0.0, get_pcvar_num(g_pCvarChannelDisplay))
							show_hudmessage(i, sTarget)
						}
						else
						{
							pev(iRetEnt, pev_health, fHealth)
							new iPercent = floatround(fHealth/g_fStrength * 100, floatround_ceil)

							new iColours[3]; GetColourPercent(iPercent, iColours)
							set_hudmessage(iColours[0], iColours[1], iColours[2], -1.0, 0.5, 0, 0.0, RESEND_MSG_DELAY, 0.0, 0.0, get_pcvar_num(g_pCvarChannelDisplay))		
							show_hudmessage(i, "%s\n%d%%", sTarget, iPercent)
						}
						continue
					}
				}
				ClearPlayerHud(i)
			}	
		}
		set_pev(iEnt, pev_nextthink, get_gametime() + 0.1)
	}
	else
	{			
		static sClassName[sizeof g_sPanelModelClassName]; pev(iEnt, pev_classname, sClassName, charsmax(sClassName))			
		if (equal(sClassName, g_sPanelModelClassName))
		{
			// The panels model flicker when first turned on
			
			if (pev(iEnt, pev_renderfx) == kRenderFxFlickerFast)
			{
				// Lets make them distort before we turn off the effects
				set_pev(iEnt, pev_renderfx, kRenderFxDistort)
				
				set_pev(iEnt, pev_nextthink, get_gametime() + 3.0)		
				new Float:fThink; pev(iEnt, pev_nextthink, fThink)
			}
			else
			{
				set_pev(iEnt, pev_renderfx, kRenderFxPulseFast) // Reset the RenderFX back from distort when we first create the panel
				set_pev(pev(iEnt, pev_owner), pev_nextthink, 0.0) 
			}
		}
	}
		
	return FMRES_IGNORED
}

public PanelTakeDamage(iEnt, iInflictor, iAttacker, Float:fDamage, iDmgType)
{	
	if ((g_iVotingStatus != VOTING_STARTED) && IsPanelEnt(iEnt)) 
	{
		return HAM_SUPERCEDE // Don't allow damage yet
	}
	return HAM_IGNORED
}
	
// Checks if the entity specified is in fact the breakable panel entity
IsPanelEnt(iEnt)
{
	new iPanelEnt
	for (new i = 0; i < g_iPanelCount; i++)
	{
		iPanelEnt = ArrayGetCell(g_iPanelEnts, i)
		if (iEnt == iPanelEnt)
			return 1
	}
	return 0
}

// Sends a blank message to id to clear whatever message they currently have, 0 for all clients
ClearPlayerHud(id = 0)
{
	set_hudmessage(0, 0, 0, 0.0, 0.0, 0, 0.0, 0.0, 0.0, 0.0, get_pcvar_num(g_pCvarChannelDisplay))
	show_hudmessage(id, "")	
}

DisplayPanelModels()
{
	new iPanelEnt, iOwner
	for (new i = 0; i < g_iPanelCount; i++)
	{
		iPanelEnt = ArrayGetCell(g_iPanelEnts, i)
		iOwner = pev(iPanelEnt, pev_owner)

		if (pev(iOwner, pev_renderamt) == MODEL_RENDERAMT_OFF)
		{
			set_pev(iOwner, pev_renderamt, MODEL_RENDERAMT_ON)
			set_pev(iOwner, pev_renderfx, kRenderFxFlickerFast)
			set_pev(iOwner, pev_nextthink, get_gametime() + random_float(0.5, 10.0)) // Reset flicker back to normal on think	
		}
		else			
			set_pev(iOwner, pev_renderamt, MODEL_RENDERAMT_OFF) // Less visible
	}
}

// Forces any players looking at the specified panels hud to be updated on next think. 0 for all
// This ensures that things like health percentage display correctly at all times
ForceUpdateHudPanel(iPanel = 0)
{	
	for (new i = 1; i <= g_iMaxPlayers; i++)
		if (!iPanel || g_iCurrentEnt[i] == iPanel)
			g_bPlayerForceUpdate[i] = true	
}

// Blue is always 0
GetColourPercent(iPercent, iColours[3])
{
	new iRemain = iPercent - 50
	iColours[0] = iRemain > 0 ? 255 - floatround(float(iRemain) * 5.1) : 255
	iColours[1] = iRemain < 0 ? 255 - floatround(float(-iRemain) * 5.1) : 255
}

CreatePanelModels()
{
	new sMap[MAX_MAP_LEN], sPath[64]
	new iModel

	new Float:fMaxs[3]
	new Float:fMins[3]
	
	new iTarget
	for (new i = 0; i < g_iPanelCount; i++)
	{
		iTarget = ArrayGetCell(g_iPanelEnts, i)
		
		pev(iTarget, pev_mins, fMins)
		pev(iTarget, pev_maxs, fMaxs)		
	
		new Float:fOrigin[3]
		fOrigin[0] = (fMins[0] + fMaxs[0]) * 0.5
		fOrigin[1] = (fMins[1] + fMaxs[1]) * 0.5
		fOrigin[2] = (fMins[2] + fMaxs[2]) * 0.5 
		fOrigin[2] -= 152 / 2 // URG 
		
		// Get the angles stored in the pev_vuser1
		// We can't just use the "angles" key because the Y value is stripped by the engine
		new Float:fAngles[3]; pev(iTarget, pev_vuser1, fAngles)
		//console_print(0, "%d. %d: %f %f %f",i, iTarget, fAngles[0], fAngles[1], fAngles[2])
		
		// Create the entity which we will assign the model to
		iModel = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target")) 
		set_pev(iModel, pev_classname, g_sPanelModelClassName)	
		engfunc(EngFunc_SetOrigin, iModel, fOrigin)
		set_pev(iModel, pev_angles, fAngles)
				
		// Reset the breakable angles to 0 to prevent any oddities
		for (new i = 0; i < 3; i++)
			fAngles[i] = 0.0
		set_pev(iTarget, pev_angles, fAngles)

		g_iSelectedCount--
					
		ArrayGetString(g_sSelectedMapList, g_iSelectedCount, sMap, charsmax(sMap))
		formatex(sPath, charsmax(sPath), "%s%s.mdl", g_sPanelDir, sMap)
		engfunc(EngFunc_SetModel, iModel, sPath)
		
		//dllfunc(DLLFunc_Spawn, iModel)
			
		set_pev(iTarget, pev_target, sMap)
		set_pev(iTarget, pev_owner, iModel)
		
		set_pev(iModel, pev_rendermode, kRenderTransAdd)
		set_pev(iModel, pev_renderamt, MODEL_RENDERAMT_OFF)	
	}
	
	ArrayDestroy(g_sSelectedMapList) // No longer need
	ForceUpdateHudPanel() // Force everyones hud to update 
}

DisplayLeadingMaps(id = 0)
{
	new sMapHudList[MAX_HUDMSG_MAPS][MAX_MAP_LEN] 
	new Float:fMapHudHealth[MAX_HUDMSG_MAPS]
	
	new iEnt, Float:fHealth
	for (new i = 0; i < g_iPanelCount; i++)
	{
		iEnt = ArrayGetCell(g_iPanelEnts, i)

		pev(iEnt, pev_health, fHealth)
		if (fHealth == g_fStrength) // Don't bother if map panel hasn't taken any damage
			continue
		
		for (new j = 0; j < MAX_HUDMSG_MAPS; j++)
		{
			if (fHealth < fMapHudHealth[j] || !sMapHudList[j][0])
			{	
				for (new k = MAX_HUDMSG_MAPS - 1; k > j ;k--) // Move everything down one place
				{
					sMapHudList[k] = sMapHudList[k - 1]
					fMapHudHealth[k] = fMapHudHealth[k - 1]
					
				}
					
				pev(iEnt, pev_target, sMapHudList[j], MAX_MAP_LEN - 1)
				fMapHudHealth[j] = fHealth
					
				break
			}
		}
	}
	
	// Display the leading maps
	static sBuffer[MAX_HUDMSG_LEN], iPercent, iLowest = 100
	for (new i = 0, iLen = 0; i < MAX_HUDMSG_MAPS; i++)
	{
		if (!sMapHudList[i][0])
			break
		
		iPercent = floatround(fMapHudHealth[i]/g_fStrength * 100, floatround_ceil)
		if (iPercent < 0) iPercent = 0 // Incase negative health
		
		if (iPercent < iLowest)
			iLowest = iPercent

		new sPos[6]; fm_FormatPosition(i + 1, sPos, charsmax(sPos))
		iLen += formatex(sBuffer[iLen], charsmax(sBuffer) - iLen, "%s %s: %d%%%%\n", sPos, sMapHudList[i], iPercent)
		
	}
	new iColours[3]; GetColourPercent(iLowest, iColours)
	set_hudmessage(iColours[0], iColours[1], iColours[2], 0.6, 0.1, 0, 0.0, 600.0, 0.0, 0.0, get_pcvar_num(g_pCvarChannelLeading))
	show_hudmessage(id, sBuffer)
}


public client_disconnect(id)
	g_iCurrentEnt[id] = -1

public PanelTakeDamagePost(iEnt, iInflictor, iAttacker, Float:fDamage, iDmgType)
{
	if (!IsPanelEnt(iEnt)) 
		return HAM_IGNORED
	
	if (g_iVotingStatus != VOTING_STARTED)
		return HAM_SUPERCEDE
	
	DisplayLeadingMaps() // Update the hud display of leading maps
	ForceUpdateHudPanel(iEnt) // Update the hud health % for anyone looking at the panel
	
	// Calculate what new health is left over
	new Float:fHealth; pev(iEnt, pev_health, fHealth)
	fHealth -= fDamage 
	
	if (fHealth <= 0.0)
	{		
		// Remove the panel as its now broken
		for (new i = 0, iPanelEnt = 0; i < g_iPanelCount; i++)
		{
			iPanelEnt = ArrayGetCell(g_iPanelEnts, i)
			
			if (iPanelEnt == iEnt)
			{
				ArrayDeleteItem(g_iPanelEnts, i)
				g_iPanelCount--
				break
			}
		}
		
		// Get the map this panel was associated with
		new sTarget[MAX_MAP_LEN]; pev(iEnt, pev_target, sTarget, charsmax(sTarget))	

		if (!fm_ChangeLevel(sTarget, 0))
		{
			client_print(0, print_chat, "* Sorry, there was a problem loading map \"%s\"", sTarget)
			return HAM_IGNORED
		}
		
		copy(g_sNextMap, charsmax(g_sNextMap), sTarget)
		client_print(0, print_chat, "* Players have voted to change map to \"%s\"", g_sNextMap)
	
		// Shake screen
		message_begin(MSG_BROADCAST, get_user_msgid("ScreenShake") )
		write_short(1<<14) // Amplitude 
		write_short(1<<13) // Duration
		write_short(1<<14) // Frequency 
		message_end() 
			
		g_iVotingStatus = VOTING_FINISHED
		
		// Update the rendermode on the panel ents
		for (new i = 0, iPanelEnt = 0; i < g_iPanelCount; i++)
		{
			iPanelEnt = ArrayGetCell(g_iPanelEnts, i)

			if (iPanelEnt == iEnt)
				set_pev(pev(iPanelEnt, pev_owner), pev_renderfx, kRenderFxDistort) // Make the winning panel model flicker
			else 
				set_pev(pev(iPanelEnt, pev_owner), pev_renderamt, 50.0) // Other panel models become less visible
		}
	}
	/*else
	{
		new iPanel = pev(iEnt, pev_owner)
		set_pev(iPanel, pev_renderfx, kRenderFxStrobeFast)
		set_pev(iPanel, pev_nextthink, get_gametime() + random_float(0.5, 1.0)) // Reset distort back to normal on think	
	}*/
	return HAM_IGNORED
}


