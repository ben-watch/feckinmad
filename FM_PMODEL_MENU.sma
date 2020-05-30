#include "feckinmad/fm_global"
#include "feckinmad/fm_menu"
#include "feckinmad/fm_playermodel_api"

new const g_iMaxMenuItems[MENU_TYPE_COUNT] = { 7, 8, 8, 8 } // Max items to display for each menu type

new g_iPlayerMenuItemSelection[MAX_PLAYERS + 1][MENU_TYPE_COUNT] // Item the player has last selected in the menu
new g_iPlayerMenuPagePosition[MAX_PLAYERS + 1][MENU_TYPE_COUNT] // Page position a player is at in the menu

new g_iMenuEnterForward, g_iMenuExitForward, g_iReturn

public plugin_init() 
{ 
	fm_RegisterPlugin()

	register_menucmd(register_menuid("Select Model"), ALL_MENU_KEYS, "Command_SelectModel")
	register_menucmd(register_menuid("Select Modifier"), ALL_MENU_KEYS, "Command_SelectModifier")
	register_menucmd(register_menuid("Select Skin"), ALL_MENU_KEYS, "Command_SelectSkin")	
	register_menucmd(register_menuid("Select Body"), ALL_MENU_KEYS, "Command_SelectBody")
	register_menucmd(register_menuid("Select Subbody"), ALL_MENU_KEYS, "Command_SelectSubBody")

	register_clcmd("say", "Handle_Say")  
	register_clcmd("say_team", "Handle_Say")
	register_clcmd("fm_model_menu", "ModelMenu")

	g_iMenuEnterForward = CreateMultiForward("fm_PlayerModelMenuEnter", ET_IGNORE, FP_CELL)
	g_iMenuExitForward = CreateMultiForward("fm_PlayerModelMenuExit", ET_IGNORE, FP_CELL, FP_ARRAY)
}

public Handle_Say(id)
{
	new sArgs[192]; read_args(sArgs, charsmax(sArgs))
	remove_quotes(sArgs)

	if (equali(sArgs, "model", 5)) 
	{
		if (!sArgs[5]) // No arguments supplied
		{
			ModelMenu(id)
			return PLUGIN_HANDLED
		}
		
		if (sArgs[5] == ' ')
		{
			if (equali(sArgs[6], "off") || equali(sArgs[6], "stop") || equali(sArgs[6], "default") || equali(sArgs[6], "none"))
			{
				fm_RemovePlayerModel(id)
				//TODO:fm_SavePlayerModel(id, -1, 0, 0)
				client_print(id, print_chat, "* You have reset your player model to default")	
				return PLUGIN_HANDLED		
			}		
			else if (equali(sArgs, "menu") || equali(sArgs, "list"))
			{
				ModelMenu(id)
				return PLUGIN_HANDLED	
			}
		}			
	}
	else if (equali(sArgs, "currentmodel")) 
	{
		new sBuffer[MAX_MODEL_NAME_LEN]; get_user_info(id, "model", sBuffer, charsmax(sBuffer))
		client_print(id, print_chat, "* Your current model is \"%s\"", sBuffer)
		return PLUGIN_HANDLED
	}
	else if (equali(sArgs,"listmodels") || equali(sArgs,"skinlist") || equali(sArgs,"modellist")) 
	{
		ModelMenu(id)
		return PLUGIN_HANDLED
	}

	return PLUGIN_CONTINUE
}

ForwardEnterModelMenu(id)
{
	ExecuteForward(g_iMenuEnterForward, g_iReturn, id)
}

ForwardExitModelMenu(id)
{
	new iArray = PrepareArray(g_iPlayerMenuItemSelection[id], MENU_TYPE_COUNT)
	ExecuteForward(g_iMenuExitForward, g_iReturn, id, iArray)
}

public ModelMenu(id)
{
	if (!fm_GetPlayerModelStatus())
	{
		client_print(id, print_chat, "* %s", g_sTextDisabled) 
	}
	else if (!fm_GetPlayerModelCount())	
	{
		client_print(id, print_chat, "* No custom player models have been loaded")
	}
	else 
	{
		ResetPlayerMenu(id)
		SelectModel(id, 0)
		ForwardEnterModelMenu(id)
	}
}

SelectModel(id, iPos)
{
	if(iPos < 0) 
	{	
		// Closed out of model menu, so send a forward for other plugins. e.g. For destroying camera, storing their model / skin / body selection. etc
		ForwardExitModelMenu(id)
		return PLUGIN_HANDLED
	}

	new sMenuBody[256], iCurrentKey, iKeys, iMax = g_iMaxMenuItems[MENU_TYPE_MODEL]
	new iStart = iPos * iMax	
	new iEnd = iStart + iMax
	new iModelNum = fm_GetPlayerModelCount()

	new iLen = formatex(sMenuBody, charsmax(sMenuBody), "Select Model: Page %d/%d\n\n", iPos + 1, (iModelNum / iMax + ((iModelNum % iMax) ? 1 : 0 )) )
	if(iEnd > iModelNum)
	{
		iEnd = iModelNum	
	}

	new Buffer[eModel_t]
	for(new i = iStart; i < iEnd; i++)
	{
		fm_GetPlayerModelDataByIndex(i, Buffer)
		iLen += formatex(sMenuBody[iLen], (charsmax(sMenuBody) - iLen), "\\w%d) %s%s\n", iCurrentKey + 1, Buffer[m_sModelName], (Buffer[m_iModelSkinCount] > 1 || fm_GetSubBodyPartTotalByModelIndex(i) > 1) ? "\\d..." : "")
		iKeys |= (1<<iCurrentKey++)
	}
		
	iLen += formatex(sMenuBody[iLen], (charsmax(sMenuBody) - iLen), "\\w\n8) Default")
	iKeys |= (1<<7)

	if(iEnd != iModelNum) 
	{
		iLen += formatex(sMenuBody[iLen], (charsmax(sMenuBody) - iLen), "\n9) More")
		iKeys |= (1<<8)
	}
	
	formatex(sMenuBody[iLen], (charsmax(sMenuBody) - iLen), "\n0) %s", iPos ? "Back" : "Close")
	iKeys |= (1<<9)
	
	show_menu(id, iKeys, sMenuBody)
	return PLUGIN_HANDLED
}

public Command_SelectModel(id, iKey) 
{
	if (!fm_GetPlayerModelStatus()) // In case the player had the model menu open before an admin disabled models
	{
		client_print(id, print_chat, "* %s", g_sTextDisabled) 
		ForwardExitModelMenu(id)
		return PLUGIN_HANDLED
	}
	
	switch(iKey) 
	{
		case 8: SelectModel(id, ++g_iPlayerMenuPagePosition[id][MENU_TYPE_MODEL]) // Next page
		case 9: SelectModel(id, --g_iPlayerMenuPagePosition[id][MENU_TYPE_MODEL]) // Previous page
		default: 
		{
			new Buffer[eModel_t]

			// New model selected. Reset any modifiers
			ResetPlayerMenuSelection(id) 

			// Reset to the default model
			if (iKey == 7)
			{
				fm_RemovePlayerModel(id)
				g_iPlayerMenuItemSelection[id][MENU_TYPE_MODEL] = -1
			}
			else // Get the model selected
			{
				g_iPlayerMenuItemSelection[id][MENU_TYPE_MODEL] = g_iPlayerMenuPagePosition[id][MENU_TYPE_MODEL] * g_iMaxMenuItems[MENU_TYPE_MODEL] + iKey
				fm_GetPlayerModelDataByIndex(g_iPlayerMenuItemSelection[id][MENU_TYPE_MODEL], Buffer)
				
				fm_SetPlayerModel(id, Buffer[m_sModelName]) // Set the player model
				fm_SetPlayerSkin(id, 0) // Reset modifiers since new model has been selected
				fm_SetPlayerBodyValue(id, 0)
			}

			// Theres some skins / bodygroups that the player can change, so open the modifier menu. Else reopen the model menu to allow additional model changes
			if (iKey != 7 && (fm_GetSubBodyPartTotalByModelIndex(g_iPlayerMenuItemSelection[id][MENU_TYPE_MODEL]) > 1 || Buffer[m_iModelSkinCount] > 1))
			{
				SelectModifier(id) 
			}
			else 
			{
				SelectModel(id, g_iPlayerMenuPagePosition[id][MENU_TYPE_MODEL]) 
			}
		}
	}
	fm_PlaySound(id, FM_MENU_SELECT_SOUND)
	return PLUGIN_HANDLED
} 

SelectModifier(id)
{
	new iModelIndex = g_iPlayerMenuItemSelection[id][MENU_TYPE_MODEL]
	new Buffer[eModel_t]; fm_GetPlayerModelDataByIndex(iModelIndex, Buffer)
	new iSkinCount = Buffer[m_iModelSkinCount]

	new sMenuBody[256], iKeys, iLen = formatex(sMenuBody, charsmax(sMenuBody), "Select Modifier:\n")
	if (iSkinCount > 1)
	{
		iKeys |= (1<<0)
	}
	iLen += formatex(sMenuBody[iLen], (charsmax(sMenuBody) - iLen), "%s\n1) Skins (%d)", iSkinCount > 1 ? "\\w" : "\\d", iSkinCount)
	
	new iSubBodyTotal = fm_GetSubBodyPartTotalByModelIndex(iModelIndex)
	if (iSubBodyTotal > 1)
	{
		iKeys |= (1<<1)
	}
	iLen += formatex(sMenuBody[iLen], (charsmax(sMenuBody) - iLen), "%s\n2) Body Parts (%d)", iSubBodyTotal > 1 ? "\\w" : "\\d",  iSubBodyTotal)
	
	formatex(sMenuBody[iLen], (charsmax(sMenuBody) - iLen), "\\w\n\n0) Back")
	iKeys |= (1<<9)	

	show_menu(id, iKeys, sMenuBody)
	return PLUGIN_HANDLED
}

public Command_SelectModifier(id, iKey) 
{
	if (!fm_GetPlayerModelStatus()) // Incase the player had the model menu open before an admin disabled models
	{
		client_print(id, print_chat, "* %s", g_sTextDisabled) 
		ForwardExitModelMenu(id)
		return PLUGIN_HANDLED
	}

	g_iPlayerMenuPagePosition[id][MENU_TYPE_SKIN] = g_iPlayerMenuPagePosition[id][MENU_TYPE_BODYGROUP] = g_iPlayerMenuItemSelection[id][MENU_TYPE_BODYSUB] = 0 // Reset any modifier menu positions
	switch(iKey) 
	{
		case 0: SelectSkin(id, g_iPlayerMenuPagePosition[id][MENU_TYPE_SKIN] = 0)
		case 1: SelectBody(id, g_iPlayerMenuPagePosition[id][MENU_TYPE_BODYGROUP] = 0)
		case 9: SelectModel(id, g_iPlayerMenuPagePosition[id][MENU_TYPE_MODEL])
	}
	fm_PlaySound(id, FM_MENU_SELECT_SOUND)
	return PLUGIN_HANDLED
} 


SelectSkin(id, iPos)
{
	if(iPos < 0)
	{
		SelectModifier(id)
		return PLUGIN_HANDLED	
	}

	new Buffer[eModel_t]; fm_GetPlayerModelDataByIndex(g_iPlayerMenuItemSelection[id][MENU_TYPE_MODEL], Buffer)
	new iSkinCount = Buffer[m_iModelSkinCount]

	new sMenuBody[256], iCurrentKey, iKeys, iMax = g_iMaxMenuItems[MENU_TYPE_SKIN]
	new iStart = iPos * iMax
	new iEnd = iStart + iMax
	
	new iLen = formatex(sMenuBody, charsmax(sMenuBody), "Select Skin: Page %d/%d\n\n", iPos + 1, (iSkinCount / iMax + ((iSkinCount % iMax) ? 1 : 0 )) )
	
	if(iEnd > iSkinCount)
	{
		iEnd = iSkinCount	
	}

	new sSkinName[SKIN_NAME_LEN]	
	for(new i = iStart; i < iEnd; i++)
	{
		ArrayGetString(Buffer[m_ModelSkinNames], i, sSkinName, charsmax(sSkinName))
		iLen += formatex(sMenuBody[iLen], (charsmax(sMenuBody) - iLen), "%d) %s\n", iCurrentKey + 1, sSkinName)
		iKeys |= (1<<iCurrentKey++)
	}
		
	if(iEnd != iSkinCount) 
	{
		iLen += formatex(sMenuBody[iLen], (charsmax(sMenuBody) - iLen), "\n9) More")
		iKeys |= (1<<8)
	}
	
	formatex(sMenuBody[iLen], (charsmax(sMenuBody) - iLen), "\n0) Back")
	iKeys |= (1<<9)
	
	show_menu(id, iKeys, sMenuBody)
	return PLUGIN_HANDLED
}

public Command_SelectSkin(id, iKey) 
{
	if (!fm_GetPlayerModelStatus()) // Incase the player had the model menu open before an admin disabled models
	{
		client_print(id, print_chat, "* %s", g_sTextDisabled) 
		ForwardExitModelMenu(id)
		return PLUGIN_HANDLED
	}

	switch(iKey) 
	{
		case 8: SelectSkin(id, ++g_iPlayerMenuPagePosition[id][MENU_TYPE_SKIN]) // Next page
		case 9: SelectSkin(id, --g_iPlayerMenuPagePosition[id][MENU_TYPE_SKIN]) // Previous page
		default: 
		{
			new iSkin = g_iPlayerMenuPagePosition[id][MENU_TYPE_SKIN] * g_iMaxMenuItems[MENU_TYPE_SKIN] + iKey
			fm_SetPlayerSkin(id, iSkin) // Set the player model skin
			g_iPlayerMenuItemSelection[id][MENU_TYPE_SKIN] = iSkin // Note for when we exit the menu so it can be saved	 		
			SelectSkin(id, g_iPlayerMenuPagePosition[id][MENU_TYPE_SKIN]) // Open up the skin menu so they can try some more skins
		}
	}
	fm_PlaySound(id, FM_MENU_SELECT_SOUND)
	return PLUGIN_HANDLED
} 

SelectBody(id, iPos)
{
	if(iPos < 0)
	{
		SelectModifier(id)
		return PLUGIN_HANDLED	
	}

	new Buffer[eModel_t]; fm_GetPlayerModelDataByIndex(g_iPlayerMenuItemSelection[id][MENU_TYPE_MODEL], Buffer)
	new iBodyCount = Buffer[m_iModelBodyCount]

	new sMenuBody[256], iCurrentKey, iKeys, iMax = g_iMaxMenuItems[MENU_TYPE_BODYGROUP]
	new iStart = iPos * iMax
	new iEnd = iStart + iMax 
	
	new iLen = formatex(sMenuBody, charsmax(sMenuBody), "Select Body: Page %d/%d\n\n", iPos + 1, (iBodyCount / iMax + ((iBodyCount % iMax) ? 1 : 0 )) )
	
	if(iEnd > iBodyCount)
	{
		iEnd = iBodyCount	
	}

	new BodyParts[eBodyPart_t]
	for(new i = iStart; i < iEnd; i++)
	{
		ArrayGetArray(Buffer[m_ModelBodyParts], i, BodyParts)

		if (BodyParts[m_iBodyPartCount] > 1)
		{
			iKeys |= (1<<iCurrentKey)
		}
		iCurrentKey++
		iLen += formatex(sMenuBody[iLen], (charsmax(sMenuBody) - iLen), "%s%d) %s\n", BodyParts[m_iBodyPartCount] > 1 ? "\\w" : "\\d", iCurrentKey, BodyParts[m_sBodyPartName])
		
	}
		
	if(iEnd != iBodyCount) 
	{
		iLen += formatex(sMenuBody[iLen], (charsmax(sMenuBody) - iLen), "\n\\w9) More")
		iKeys |= (1<<8)
	}
	
	formatex(sMenuBody[iLen], (charsmax(sMenuBody) - iLen), "\\w\n0) Back")
	iKeys |= (1<<9)
	
	show_menu(id, iKeys, sMenuBody)
	return PLUGIN_HANDLED
}

public Command_SelectBody(id, iKey) 
{
	if (!fm_GetPlayerModelStatus())  // Incase the player had the model menu open before an admin disabled models
	{
		client_print(id, print_chat, "* %s", g_sTextDisabled) 
		return PLUGIN_HANDLED
	}
	
	switch(iKey) 
	{
		case 8: SelectSkin(id, ++g_iPlayerMenuPagePosition[id][MENU_TYPE_BODYGROUP]) // Next page
		case 9: SelectSkin(id, --g_iPlayerMenuPagePosition[id][MENU_TYPE_BODYGROUP]) // Previous page
		default: 
		{
			g_iPlayerMenuItemSelection[id][MENU_TYPE_BODYGROUP] = g_iPlayerMenuPagePosition[id][MENU_TYPE_BODYGROUP] * g_iMaxMenuItems[MENU_TYPE_BODYGROUP] + iKey
			new Buffer[eModel_t]; fm_GetPlayerModelDataByIndex(g_iPlayerMenuItemSelection[id][MENU_TYPE_MODEL], Buffer)
			new BodyParts[eBodyPart_t]; ArrayGetArray(Buffer[m_ModelBodyParts], g_iPlayerMenuItemSelection[id][MENU_TYPE_BODYGROUP], BodyParts)

			if (BodyParts[m_iBodyPartCount] > 1)
			{
				SelectSubBody(id, g_iPlayerMenuPagePosition[id][MENU_TYPE_BODYSUB] = 0)
			}
			else
			{
				fm_SetPlayerBody(id, g_iPlayerMenuItemSelection[id][MENU_TYPE_BODYGROUP], 0)
				SelectBody(id, g_iPlayerMenuPagePosition[id][MENU_TYPE_BODYGROUP])
			}
		}
	}
	fm_PlaySound(id, FM_MENU_SELECT_SOUND)
	return PLUGIN_HANDLED
}

SelectSubBody(id, iPos)
{
	if(iPos < 0)
	{
		SelectBody(id, g_iPlayerMenuPagePosition[id][MENU_TYPE_BODYGROUP])
		return PLUGIN_HANDLED	
	}

	new Buffer[eModel_t]; fm_GetPlayerModelDataByIndex(g_iPlayerMenuItemSelection[id][MENU_TYPE_MODEL], Buffer)
	new BodyParts[eBodyPart_t]; ArrayGetArray(Buffer[m_ModelBodyParts], g_iPlayerMenuItemSelection[id][MENU_TYPE_BODYGROUP], BodyParts)
	new iSubBodyCount = BodyParts[m_iBodyPartCount]

	new sMenuBody[256], iCurrentKey, iKeys, iMax = g_iMaxMenuItems[MENU_TYPE_BODYSUB]
	new iStart = iPos * iMax
	new iEnd = iStart + iMax
	
	new iLen = formatex(sMenuBody, charsmax(sMenuBody), "Select Subbody: Page %d/%d\n\n", iPos + 1, (iSubBodyCount / iMax + ((iSubBodyCount % iMax) ? 1 : 0 )) )
	
	if (iEnd > iSubBodyCount)
	{
		iEnd = iSubBodyCount 
	}
	
	new sSubBodyName[MODEL_NAME_LEN]
	for(new i = iStart; i < iEnd; i++)
	{
		fm_GetSubBodyNameByIndex(g_iPlayerMenuItemSelection[id][MENU_TYPE_MODEL], g_iPlayerMenuItemSelection[id][MENU_TYPE_BODYGROUP], i, sSubBodyName)
		iLen += formatex(sMenuBody[iLen], (charsmax(sMenuBody) - iLen), "%d) %s\n", iCurrentKey + 1, sSubBodyName)
		iKeys |= (1<<iCurrentKey++)
	}
		
	if(iEnd != iSubBodyCount)
	{
		iLen += formatex(sMenuBody[iLen], (charsmax(sMenuBody) - iLen), "\n9) More")
		iKeys |= (1<<8)
	}
	
	formatex(sMenuBody[iLen], (charsmax(sMenuBody) - iLen), "\n0) Back")
	iKeys |= (1<<9)
	
	show_menu(id, iKeys, sMenuBody)
	return PLUGIN_HANDLED
}

public Command_SelectSubBody(id, iKey) 
{
	if (!fm_GetPlayerModelStatus()) // Incase the player had the model menu open before an admin disabled models
	{
		client_print(id, print_chat, "* %s", g_sTextDisabled) 
		ForwardExitModelMenu(id)
		return PLUGIN_HANDLED
	}

	switch(iKey) 
	{
		case 8: SelectSubBody(id, ++g_iPlayerMenuPagePosition[id][MENU_TYPE_BODYSUB]) // Next page
		case 9: SelectSubBody(id, --g_iPlayerMenuPagePosition[id][MENU_TYPE_BODYSUB]) // Previous page
		default: 
		{
			g_iPlayerMenuItemSelection[id][MENU_TYPE_BODYSUB] = g_iPlayerMenuPagePosition[id][MENU_TYPE_BODYSUB] * g_iMaxMenuItems[MENU_TYPE_BODYSUB] + iKey
			fm_SetPlayerBody(id, g_iPlayerMenuItemSelection[id][MENU_TYPE_BODYGROUP], g_iPlayerMenuItemSelection[id][MENU_TYPE_BODYSUB]) 	 		
			SelectSubBody(id, g_iPlayerMenuPagePosition[id][MENU_TYPE_BODYSUB]) // Open up the skin menu so they can try some more skins
		}
	}
	fm_PlaySound(id, FM_MENU_SELECT_SOUND)
	return PLUGIN_HANDLED
} 

ResetPlayerMenu(id)
{
	for (new i = 0; i < MENU_TYPE_COUNT; i++)
	{
		g_iPlayerMenuItemSelection[id][i] = -2
		g_iPlayerMenuPagePosition[id][i] = 0
	}
}

ResetPlayerMenuSelection(id)
{
	for (new i = 0; i < MENU_TYPE_COUNT; i++)
	{
		g_iPlayerMenuItemSelection[id][i] = -2
	}
}

public client_disconnected(id)
{
	ResetPlayerMenu(id)
}
