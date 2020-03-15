#include "feckinmad/fm_global"

#include "feckinmad/entmod/fm_entmod_base"
#include "feckinmad/entmod/fm_entmod_access"
#include "feckinmad/entmod/fm_entmod_command"
#include "feckinmad/entmod/fm_entmod_render"
#include "feckinmad/entmod/fm_entmod_misc"

new Array:g_EntSaveList[MAX_PLAYERS + 1] = { Invalid_Array, ... }
new g_sSaveDirectory[128], g_sCurrentMap[MAX_MAP_LEN], g_iMaxPlayers

public plugin_init()
{
	fm_RegisterPlugin()

	register_clcmd("fm_ent_select", "Player_EntSelect")
	register_clcmd("fm_ent_save", "Player_EntSave")
	register_clcmd("fm_ent_load", "Player_EntLoad") 

	g_iMaxPlayers = get_maxplayers()
	get_mapname(g_sCurrentMap, charsmax(g_sCurrentMap))
	
	new sDataDirectory[64]; get_localinfo("amxx_datadir", sDataDirectory, charsmax(sDataDirectory))
	formatex(g_sSaveDirectory, charsmax(g_sSaveDirectory), "%s/entmod/saves/%s/", sDataDirectory, g_sCurrentMap)

	if (!dir_exists(g_sSaveDirectory) && mkdir(g_sSaveDirectory))
	{
		fm_WarningLog("Failed to create directory: \"%s\"", g_sSaveDirectory)
	}
}

public client_disconnected(id)
{
	if (g_EntSaveList[id] != Invalid_Array)
	{
		ArrayDestroy(g_EntSaveList[id])
	}
}

public plugin_end()
{
	for (new i = 1; i <= g_iMaxPlayers; i++)
	{
		if (g_EntSaveList[i] != Invalid_Array)
		{
			ArrayDestroy(g_EntSaveList[i])
		}
	}
}

public Player_EntSelect(id)
{
	if (!fm_CheckUserEntAccess(id))
	{
		return PLUGIN_HANDLED
	}

	new sArgs[8]; read_args(sArgs, charsmax(sArgs))
	new iEnt = fm_CommandGetEntity(id, sArgs)
	if (!iEnt || !fm_CommandCheckEntity(id, iEnt, ENTCMD_READ))
	{
		return PLUGIN_HANDLED
	}

	if (g_EntSaveList[id] == Invalid_Array)
	{
		g_EntSaveList[id] = ArrayCreate(1)
	}

	new iIndex = GetEntityArrayIndexByID(g_EntSaveList[id], iEnt)
	if (iIndex != -1)
	{
		ArrayDeleteItem(g_EntSaveList[id], iIndex)
		fm_RestoreRendering(iEnt)	
	}
	else
	{
		ArrayPushCell(g_EntSaveList[id], iEnt)
		fm_TempRenderColour(iEnt, 0, 0, 255)
	}
	return PLUGIN_HANDLED
}

public Player_EntLoad(id)
{
	if (!fm_CheckUserEntAccess(id))
	{
		return PLUGIN_HANDLED
	}

	new sArgs[32]; read_args(sArgs, charsmax(sArgs))
	trim(sArgs)

	if (!sArgs[0])
	{
		console_print(id, "Please supply a name to load from")
		return PLUGIN_HANDLED
	}

	new sFile[256]; formatex(sFile, charsmax(sFile), "%s%s.ini", g_sSaveDirectory, sArgs)
	if (!file_exists(sFile))
	{
		console_print(id, "File with the name \"%s.ini\" doesn't exist for map \"%s\"", sArgs, g_sCurrentMap)
		return PLUGIN_HANDLED
	}

	new iFileHandle = fopen(sFile, "rt")
	if (!iFileHandle) 
	{
		console_print(id, "There was a problem loading the file name \"%s.ini\"", sArgs)
		fm_WarningLog(FM_FOPEN_WARNING, sFile)
		return PLUGIN_HANDLED
	}

	new sData[2048], sClassName[32]
	new sKey[MAX_KEY_LEN], sValue[MAX_VALUE_LEN]
	new iEnt, iLine, iCount, cLast = '}'
	
	while (!feof(iFileHandle))
	{
		fgets(iFileHandle, sData, charsmax(sData))
		iLine++

		if (!sData[0] || sData[0] == '\n')
		{
			continue
		}
		else if (sData[0] == '{')
		{
			if (cLast != '}')
			{
				fm_WarningLog("Invalid { on line %d", iLine)
				break
			}

			cLast = '{'
		}
		else if (sData[0] == '\t')
		{
			if (cLast == '}')
			{
				fm_WarningLog("Invalid entdata on line %d", iLine)
				break
			}

			cLast = '\t'

			if (parse(sData, sKey, charsmax(sKey), sValue, charsmax(sValue)) == 2)
			{
				if (equal(sKey, "classname"))
				{
					iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, sValue)) 

					if (!iEnt)
					{
						fm_WarningLog("Failed to create entity \"%s\" on line %d", sClassName, iLine)
						break
					}

					fm_DestroyCachedEntKeys(iEnt)
					copy(sClassName, charsmax(sClassName), sValue)
					iCount++
				}
				else if (!iEnt)
				{
					fm_WarningLog("Entdata without corresponding entity on line %d", iLine)	
					break
				}

				fm_PushCachedEntKey(iEnt, sKey, sValue)
				fm_SetKeyValue(iEnt, sClassName, sKey, sValue)	
			}
			
		}
		else if (sData[0] == '}')
		{
			if (cLast == '}')
			{
				fm_WarningLog("Invalid } on line %d", iLine)
				break				
			}

			cLast = '}'

			if (iEnt)
			{
				dllfunc(DLLFunc_Spawn, iEnt)
				iEnt = 0
			}
		}
		else
		{
			fm_WarningLog("Unrecognised data on line %d", iLine)
			break
		}
	}
		

	fclose(iFileHandle)

	console_print(id, "Loaded %d entities", iCount)

	return PLUGIN_HANDLED
}

public Player_EntSave(id)
{
	if (!fm_CheckUserEntAccess(id))
	{
		return PLUGIN_HANDLED
	}

	if (g_EntSaveList[id] == Invalid_Array || !ArraySize(g_EntSaveList[id]))
	{
		console_print(id, "You must select at least one entity to save")
		return PLUGIN_HANDLED
	}
	
	new sArgs[32]; read_args(sArgs, charsmax(sArgs))
	trim(sArgs)

	if (!sArgs[0])
	{
		console_print(id, "Please supply a name to save to")
		return PLUGIN_HANDLED
	}

	new sFile[256]; formatex(sFile, charsmax(sFile), "%s%s.ini", g_sSaveDirectory, sArgs)
	if (file_exists(sFile))
	{
		console_print(id, "File with the name \"%s.ini\" already exists for map \"%s\"", sArgs, g_sCurrentMap)
		return PLUGIN_HANDLED
	}

	new iFileHandle = fopen(sFile, "wt")
	if (!iFileHandle) 
	{
		console_print(id, "There was a problem saving with the file name \"%s.ini\"", sArgs)
		fm_WarningLog(FM_FOPEN_WARNING, sFile)
		return PLUGIN_HANDLED
	}

	new sKey[MAX_KEY_LEN], sValue[MAX_VALUE_LEN]
	new iEnt, iCount = ArraySize(g_EntSaveList[id])

	for (new i = 0; i < iCount; i++)
	{
		iEnt = ArrayGetCell(g_EntSaveList[id], i)
		fprintf(iFileHandle, "{\n")

		for (new j = 0, iCount = fm_CachedEntKeyCount(iEnt); j < iCount; j++)
		{
			fm_GetCachedEntKeyIndex(iEnt, j, sKey, charsmax(sKey), sValue, charsmax(sValue))

			//if (!equal(sKey, "fm_", 3)) // Ignore custom keys
			//{
			fprintf(iFileHandle, "\t\"%s\" \"%s\"\n", sKey, sValue)
			//}
		}

		fprintf(iFileHandle, "}\n")	
		fm_RestoreRendering(iEnt)
	}

	fclose(iFileHandle)

	ArrayDestroy(g_EntSaveList[id])
	console_print(id, "Saved %d entities", iCount)

	return PLUGIN_HANDLED
}

GetEntityArrayIndexByID(Array:SavedEntityList, iEnt)
{
	for (new i = 0; i < ArraySize(SavedEntityList); i++)
	{	
		if (ArrayGetCell(SavedEntityList, i) == iEnt)
		{
			return i
		}
	} 
	return -1
}

public fm_RunEntCommand(id, iEnt, iMode) // NOTE: iCommand would be useful
{
	new iIndex
	for (new i = 1; i <= g_iMaxPlayers; i++)
	{
		if (g_EntSaveList[i] == Invalid_Array)
		{
			continue
		}

		iIndex = GetEntityArrayIndexByID(g_EntSaveList[i], iEnt)
		if (iIndex != -1 && !(iMode & ENTCMD_READ))
		{
			client_print(id, print_chat, "* This entity is currently selected to be saved")
			return PLUGIN_HANDLED
		}
	}

	return PLUGIN_CONTINUE
}