#include "feckinmad/fm_global"
#include "feckinmad/fm_colour_api"

#include <fakemeta> // engfunc()

#define MESSAGE_FREQUENCY 60.0 // secs

new Array:g_MessageList
new const g_sMessageFile[] = "fm_messages.ini"

new g_iEnt // Global entity used as a timer
new g_iCurMessage  = -1 // Current message position

new const g_sMessageForward[] = "fm_ScreenMessage"
new g_pCvarMessageHudChannel

public plugin_init()
{
	fm_RegisterPlugin()
	
	g_MessageList = ArrayCreate(MAX_HUDMSG_LEN)

	new sMessageFile[128], sConfigDir[64]; get_localinfo("amxx_configsdir", sConfigDir, charsmax(sConfigDir))

	// Read main message file which is filled with messages we display all the time
	formatex(sMessageFile, charsmax(sMessageFile), "%s/%s", sConfigDir, g_sMessageFile)
	ReadMessageFile(sMessageFile)
	
	// Read map specific messages from messages-mapname.ini 
	new sMapName[MAX_MAP_LEN]; get_mapname(sMapName, charsmax(sMapName))
	formatex(sMessageFile, charsmax(sMessageFile), "%s/maps/messages-%s.ini", sConfigDir, sMapName)
	if (file_exists(sMessageFile))
		ReadMessageFile(sMessageFile)
	
	g_pCvarMessageHudChannel = register_cvar("fm_message_hud_channel", "2")
	
	// Create the entity which is used as a timer
	g_iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	if (g_iEnt) 
	{
		set_pev(g_iEnt, pev_nextthink, get_gametime() + MESSAGE_FREQUENCY)
		register_forward(FM_Think, "Forward_Think")
	}
	else
		log_amx("Failed to create timer entity")
}

ReadMessageFile(sMessageFile[])
{
	new iFileHandle = fopen(sMessageFile, "rt")
	if (!iFileHandle)
	{
		fm_WarningLog(FM_FOPEN_WARNING, sMessageFile)	
	}
	
	new sData[MAX_HUDMSG_LEN]
	new iCount // Seperate count as messages may have been added before this file is read

	while (!feof(iFileHandle))
	{
		fgets(iFileHandle, sData, charsmax(sData))
		trim(sData);

		if (fm_Comment(sData))
		{
			continue
		}

		
		replace_all(sData, MAX_HUDMSG_LEN - 1, "\n", "^n")
		ArrayPushString(g_MessageList, sData)
		iCount++	
	}
	fclose(iFileHandle)
	log_amx("Loaded %d messages from file: \"%s\"", iCount, sMessageFile)
	
	return PLUGIN_CONTINUE
}

public Forward_Think(iEnt)
{
	if (iEnt != g_iEnt)
	{
		return FMRES_IGNORED
	}

	new iMessageCount = ArraySize(g_MessageList)

	if (iMessageCount > 0) // If there are messages to display
	{
		// Start on a random message to begin with
		if (g_iCurMessage == -1)
		{
			g_iCurMessage = random(iMessageCount)
		}
		else if (g_iCurMessage >= iMessageCount)
		{
			g_iCurMessage = 0
		}

		// Get the message to display
		new sBuffer[MAX_HUDMSG_LEN]
		ArrayGetString(g_MessageList, g_iCurMessage, sBuffer, charsmax(sBuffer))

		if (sBuffer[0] == '@')
		{
			new iReturn, iForward, iPlugin = is_plugin_loaded(sBuffer[1], true)
			if (iPlugin != -1)
			{
				iForward = CreateOneForward(iPlugin, g_sMessageForward, FP_ARRAY, FP_CELL)
				
				if (iForward > 0)
				{
					new iBufferArray = PrepareArray(sBuffer, sizeof(sBuffer), 1)
					ExecuteForward(iForward, iReturn, iBufferArray, sizeof(sBuffer))

					replace_all(sBuffer, charsmax(sBuffer), "\\n", "\n")
	
					DisplayMessage(sBuffer)
					DestroyForward(iForward)

					set_pev(iEnt, pev_nextthink, get_gametime() + MESSAGE_FREQUENCY)
					g_iCurMessage++



					return FMRES_IGNORED
				}
				else	
				{
					log_error(AMX_ERR_NOTFOUND, "Function \"%s\" was not found", g_sMessageForward)
				}
			}
			else
			{
				log_error(AMX_ERR_NOTFOUND, "Plugin \"%s\" was not found", sBuffer[1])
			}

			ArrayDeleteItem(g_MessageList, g_iCurMessage)
			set_pev(iEnt, pev_nextthink, get_gametime() + MESSAGE_FREQUENCY)
			return FMRES_IGNORED
		}
				
		DisplayMessage(sBuffer)
		g_iCurMessage++
	}
	
	set_pev(iEnt, pev_nextthink, get_gametime() + MESSAGE_FREQUENCY)
	return FMRES_IGNORED
}

DisplayMessage(sMessage[])
{
	// Get a VALID random colour from the FM_COLOUR_API plugin
	new iColours[3]; fm_GetColoursByIndex(random(fm_GetColourCount()), iColours)
		
	set_hudmessage(iColours[0], iColours[1], iColours[2], 
	-1.0,  0.01, 	// Hud position
	2, 1.0, 	// Effect & Effect delay
	10.0, 		// Holdtime
	0.03, 		// Fade In Time
	1.0, 		// Fade Out Time
	get_pcvar_num(g_pCvarMessageHudChannel)) // HudChannel to use
		
	show_hudmessage(0, sMessage)
	client_print(0, print_console, sMessage)
}

public plugin_natives()
{
	register_native("fm_AddMessage", "Native_AddMessage")
	register_library("fm_message_api")
}

public Native_AddMessage(iPlugin, iParams) 
{
	new sData[MAX_HUDMSG_LEN]; get_string(1, sData, charsmax(sData))

	if (sData[0])
	{
		//replace_all(sData, MAX_HUDMSG_LEN - 1, "\\n", "\\n")
		ArrayPushString(g_MessageList, sData)
	} 	
}


