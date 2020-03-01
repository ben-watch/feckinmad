#include "feckinmad/fm_global"
#include "feckinmad/fm_admin_access"
#include "feckinmad/fm_sql_tquery"
#include "feckinmad/fm_sql_player"
#include "feckinmad/fm_menu"
#include "feckinmad/fm_time" // fm_SecondsToText()
#include "feckinmad/fm_mapfunc" // fm_IsMapNameInFile()
#include "feckinmad/fm_precache" // fm_SafePrecacheModel()
#include "feckinmad/fm_point" // fm_GetAimOrigin()

#include <fakemeta>
#include <nvault>

#define MAX_MODEL_NAME_LEN 32
#define MAX_DB_CACHE_AGE 86400 // 24 hours
#define MAX_MENU_MODELS 7
#define MAX_MENU_SKINS 8
#define MODEL_CHANGE_DELAY 3.0

// pdata defines
#define PD_REPLACE_MODEL 170
#define PD_REPLACE_SKIN	172
#define PD_LINUX_DIFF 3

#define MAX_PLAYER_VAULT_AGE 86400 * 30 // 30 days. How many days to keep a players model cached locally (Reduces queries to DB and means the player gets their model on mapload) (lots of queries going on on mapload!)
new g_iCacheVault = INVALID_HANDLE

new const g_sModelFile[] = "fm_models_cache.dat" // File to which database model information is saved
new const g_sExcludeFile[] = "fm_models_exlude.ini" // File containing list of maps that models should be disabled on. 

new const g_sModelQuery[] = "SELECT model_id, model_name, model_skincount FROM models WHERE model_active=1"
new const g_sPlayerQuery[] = "SELECT players.model_id, players.model_skin FROM players, models WHERE model_active=1 AND players.model_id = models.model_id AND player_id = %d LIMIT 1;"

new const g_sTextDisabled[] = "Custom player models are currently disabled"
new bool:g_bAllowModel = true

enum eModel_t
{
	m_iModelIdent,
	m_sModelName[MAX_MODEL_NAME_LEN],
	m_iModelSkinCount
}

new Array:g_ModelList
new g_iModelNum

new g_iPlayerQuery[MAX_PLAYERS + 1]
new g_sQuery[512]

new g_iPlayerMenuModel[MAX_PLAYERS + 1] // Model the player has selected in the menu
new g_iPlayerMenuSkin[MAX_PLAYERS + 1] // Skin the player has selected in the menu

new g_iPlayerCameraEnt[MAX_PLAYERS + 1] // Entity ID of their camera
new g_iPlayerModelMenuPos[MAX_PLAYERS + 1] // Page position a player is at in the menu
new g_iPlayerSkinMenuPos[MAX_PLAYERS + 1] // Page position a player is at in the menu
new g_bPlayerModelSave[MAX_PLAYERS + 1]

new Float:g_fPlayerNextChange[MAX_PLAYERS + 1] // Gametime the player is allowed to change their model again

new bool:g_bPluginEnd
new g_iLastDatabaseUpdate // The systime the database was last queried. Loaded from cache file

SetPlayerModel(id, sModelName[], iSkin)
{
	set_kvd(0, KV_ClassName, "player")
	set_kvd(0, KV_KeyName, "replacement_model")
	set_kvd(0, KV_Value, sModelName)
	set_kvd(0, KV_fHandled, 0)
	dllfunc(DLLFunc_KeyValue, id, 0)
	
	new sSkin[8]; num_to_str(iSkin, sSkin, charsmax(sSkin))
	set_kvd(0, KV_ClassName, "player")
	set_kvd(0, KV_KeyName, "replacement_model_skin")
	set_kvd(0, KV_Value, sSkin)
	set_kvd(0, KV_fHandled, 0)
	dllfunc(DLLFunc_KeyValue, id, 0)

	// Update straight away
	engfunc(EngFunc_SetClientKeyValue, id, engfunc(EngFunc_GetInfoKeyBuffer, id), "model", sModelName)	

	//console_print(id, "Setting player Model: \"%s\" Skin: %d", sModelName, iSkin)	
}

RemovePlayerModel(id)
{
	set_pdata_int(id, PD_REPLACE_MODEL, 0, PD_LINUX_DIFF)
	set_pdata_int(id, PD_REPLACE_SKIN, 0, PD_LINUX_DIFF)
}


// This function returns the index of the specified model name in the g_sModelList array
GetModelIndexByName(sModel[])
{
	new Buffer[eModel_t]
	for(new i = 0; i < g_iModelNum; i++)
	{
		ArrayGetArray(g_ModelList, i, Buffer)
		if (equali(sModel, Buffer[m_sModelName]))
		{
			return i
		}
	}
	return -1
}

// This function returns the index of the specified model_id in the g_sModelList array
GetModelIndex(iModel)
{
	new Buffer[eModel_t]
	for(new i = 0; i < g_iModelNum; i++)
	{
		ArrayGetArray(g_ModelList, i, Buffer)
		if (iModel == Buffer[m_iModelIdent])
		{
			return i
		}
		
	}
	return -1
}

// This function checks whether a player has allowed enough time between changing models
CheckModelDelay(id, iPrint)
{
	new Float:fGameTime = get_gametime()
	if (g_fPlayerNextChange[id] > fGameTime)
	{
		new sTime[64]; fm_SecondsToText(floatround(g_fPlayerNextChange[id] - fGameTime, floatround_ceil), sTime, charsmax(sTime))
		client_print(id, iPrint, "%sPlease wait another %s before changing your player model", fm_PrintStar(iPrint), sTime)
		return 1
	}
	return 0
}

AddPlayerModel(Model[eModel_t])
{
	new sModelFile[MAX_RESOURCE_LEN]
	formatex(sModelFile, charsmax(sModelFile), "models/player/%s/%s.mdl", Model[m_sModelName], Model[m_sModelName])

	if (!fm_SafePrecacheModel(sModelFile))
	{
		return 0
	}

	ArrayPushArray(g_ModelList, Model)
	g_iModelNum++
	
	return 1
}

public plugin_precache()
{
	new sFile[128]; fm_BuildAMXFilePath(g_sExcludeFile, sFile, charsmax(sFile), "amxx_configsdir")
	new sCurrentMap[MAX_MAP_LEN]; get_mapname(sCurrentMap, charsmax(sCurrentMap))

	if (fm_IsMapNameInFile(sCurrentMap, sFile) == 1)
	{
		return PLUGIN_CONTINUE	
	}		

	g_ModelList = ArrayCreate(eModel_t)

	// Read the cache file to load the models here so I can precache. I don't want to use a blocking query
	g_iLastDatabaseUpdate = ReadCacheFile()

	return PLUGIN_CONTINUE	
}

public Handle_QueryModelInfo(iFailState, Handle:hQuery, sError[], iError, sData[], iLen, Float:fQueueTime)
{
	if (g_bPluginEnd)
	{
		return PLUGIN_HANDLED
	}

	if(fm_SQLCheckThreadedError(iFailState, hQuery, sError, iError))
	{
		return PLUGIN_HANDLED
	}

	new sFile[128]; fm_BuildAMXFilePath(g_sModelFile, sFile, charsmax(sFile), FM_AMXX_LOCAL_DATA)
	new iFileHandle = fopen(sFile, "wb")
	if (!iFileHandle)
	{
		fm_WarningLog(FM_FOPEN_WARNING, sFile)
		return PLUGIN_HANDLED
	}

	fwrite(iFileHandle, get_systime(), BLOCK_INT)

	// Get the SQL results and store
	new Buffer[eModel_t], iCount
	while(SQL_MoreResults(hQuery))
	{	
		Buffer[m_iModelIdent] = SQL_ReadResult(hQuery, 0)
		SQL_ReadResult(hQuery, 1, Buffer[m_sModelName], charsmax(Buffer[m_sModelName]))
		Buffer[m_iModelSkinCount] = SQL_ReadResult(hQuery, 2)

		// Write the SQL results to cache file
		fwrite_blocks(iFileHandle, Buffer, eModel_t, BLOCK_INT)
		iCount++

		SQL_NextRow(hQuery)	
	}

	fclose(iFileHandle)
	log_amx("Wrote %d models to \"%s\"", iCount, sFile)
	return PLUGIN_HANDLED
}

public plugin_end()
{
	if (g_iCacheVault != INVALID_HANDLE)
	{
		nvault_close(g_iCacheVault)
	}

	if (g_ModelList != Invalid_Array)
	{
		ArrayDestroy(g_ModelList)
	}

	g_bPluginEnd = true
}

public client_disconnect(id)
{
	g_iPlayerMenuModel[id] = 0
	g_iPlayerMenuSkin[id] = 0
	
	g_iPlayerModelMenuPos[id] = 0
	g_iPlayerSkinMenuPos[id] = 0
	g_bPlayerModelSave[id] = false

	g_fPlayerNextChange[id] = 0.0

	DestroyCamera(id)

	if (g_iPlayerQuery[id])
	{
		fm_SQLRemoveThreadedQuery(g_iPlayerQuery[id])
		g_iPlayerQuery[id] = 0
	}
}

public fm_SQLPlayerIdent(id, player_id)
{
	if (!g_bAllowModel || !g_iModelNum)
	{
		return PLUGIN_CONTINUE	
	}

	new sData[32], iTimeStamp
	new sAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAuthid, charsmax(sAuthid))

	// Check the cache vault for an entry by this player
	if (g_iCacheVault != INVALID_HANDLE && nvault_lookup(g_iCacheVault, sAuthid, sData, charsmax(sData), iTimeStamp))
	{
		new sModel[16], sSkin[16]
		parse(sData, sModel, charsmax(sModel), sSkin, charsmax(sSkin))
		new iModelIdent = str_to_num(sModel)
		if (iModelIdent != -1)
		{
			new iModelIndex = GetModelIndex(iModelIdent)
			if (iModelIndex != -1)
			{
				new Buffer[eModel_t]; ArrayGetArray(g_ModelList, iModelIndex, Buffer)
				new iSkin = str_to_num(sSkin)
				if (iSkin < 0 || iSkin >= Buffer[m_iModelSkinCount])
				{
					iSkin = 0
				}

				SetPlayerModel(id, Buffer[m_sModelName], iSkin)
				nvault_touch(g_iCacheVault, sAuthid)
			}
		}
	}
	else // Query the database instead
	{
		if (g_iPlayerQuery[id])
		{
			 fm_SQLRemoveThreadedQuery(g_iPlayerQuery[id])
		}

		new sData[1]; sData[0] = id
		formatex(g_sQuery, charsmax(g_sQuery), g_sPlayerQuery, player_id)
		g_iPlayerQuery[id] = fm_SQLAddThreadedQuery(g_sQuery, "Handle_SelectPlayerModel", QUERY_DISPOSABLE, PRIORITY_NORMAL, sData, 1)
	}
	return PLUGIN_CONTINUE
}

public Handle_SelectPlayerModel(iFailState, Handle:hQuery, sError[], iError, sData[], iLen, Float:fQueueTime, iQueryIdent)
{
	if(fm_SQLCheckThreadedError(iFailState, hQuery, sError, iError))
	{
		return PLUGIN_HANDLED
	}

	// Since this query is threaded, check that the models had not been disabled while it was queued
	if (!g_bAllowModel)
	{
		return PLUGIN_HANDLED
	}

	new id = sData[0]

	// Check the player that this query belonged to is still ingame. This shouldn't occur because I remove the query on disconnect
	// But it could happen if the query is running when we try to remove it. is_user_connected(id) as a failsafe
	if (g_iPlayerQuery[id] != iQueryIdent || !is_user_connected(id))
	{
		return PLUGIN_HANDLED
	}
		
	if (SQL_NumResults(hQuery) > 0)
	{
		new iModelIdent = SQL_ReadResult(hQuery, 0)
		new iModelIndex = GetModelIndex(iModelIdent) 
		if (iModelIndex != -1)
		{
			new iSkin = SQL_ReadResult(hQuery, 1)

			new Buffer[eModel_t]; ArrayGetArray(g_ModelList, iModelIndex, Buffer)
			SetPlayerModel(id, Buffer[m_sModelName], iSkin)
			CachePlayerModel(id, iModelIdent, iSkin) 
		}
	}
	// No results, cache the result
	else 
	{
		CachePlayerModel(id, -1, 0) 
	}


	return PLUGIN_HANDLED		
}


ReadCacheFile()
{
	new sFile[128]; fm_BuildAMXFilePath(g_sModelFile, sFile, charsmax(sFile), FM_AMXX_LOCAL_DATA)
	new iFileHandle = fopen(sFile, "rb")
	if (!iFileHandle) 
	{
		fm_WarningLog(FM_FOPEN_WARNING, sFile)
		return 0
	}
	fread(iFileHandle, g_iLastDatabaseUpdate, BLOCK_INT)

	new iLastUpdate = fseek(iFileHandle, 0, SEEK_END)
	new iCount = (ftell(iFileHandle) - BLOCK_INT) / (_:eModel_t * BLOCK_INT)
	fseek(iFileHandle, BLOCK_INT, SEEK_SET)

	new Buffer[eModel_t]
	for (new i = 0; i < iCount; i++)
	{
		if (fread_blocks(iFileHandle, Buffer, eModel_t, BLOCK_INT) != _:eModel_t)
		{
			fm_WarningLog("Failed whilst reading model cache file (%d)", ftell(iFileHandle))
			break
		}
		AddPlayerModel(Buffer)
	}

	fclose(iFileHandle)
	log_amx("Read %d models from \"%s\"", iCount, sFile)
	
	return iLastUpdate
}

public plugin_init() 
{ 
	fm_RegisterPlugin()

	register_clcmd("fm_model_menu", "ModelMenu")
	register_menucmd(register_menuid("Select Model"), ALL_MENU_KEYS, "Command_SelectModel")
	register_menucmd(register_menuid("Select Skin"), ALL_MENU_KEYS, "Command_SelectSkin")	

	register_clcmd("say","Handle_Say")  
	register_clcmd("say_team","Handle_Say")
	register_clcmd("applymodel","Handle_Console")

	register_concmd("admin_disablemodels", "Admin_DisableModels", ADMIN_MEMBER)

	// Determine if the cache is old enough to warrant reloading from db
	// Using cached results saves having to query on every mapload
	if (g_iLastDatabaseUpdate <= 0 || ((get_systime() - g_iLastDatabaseUpdate) > MAX_DB_CACHE_AGE)) 
	{
		fm_SQLAddThreadedQuery(g_sModelQuery, "Handle_QueryModelInfo", QUERY_DISPOSABLE, PRIORITY_LOW)
	}

	g_iCacheVault = nvault_open("fm_player_model_cache")
	if (g_iCacheVault != INVALID_HANDLE)
	{
		nvault_prune(g_iCacheVault, 0, get_systime() - (MAX_PLAYER_VAULT_AGE))
	}

	return PLUGIN_CONTINUE
}

// Admin command to disable models
public Admin_DisableModels(id, iLevel, iCommand)
{
	if (!fm_CommandAccess(id, iLevel, false)) 
	{
		return PLUGIN_HANDLED
	}
	
	// Check that models have not already been disabled
	if (!g_bAllowModel)
	{
		console_print(id, g_sTextDisabled)
		return PLUGIN_HANDLED
	}

	g_bAllowModel = false
	
	for (new i = 1, iMaxPlayers = get_maxplayers(); i <= iMaxPlayers; i++)
		if (is_user_connected(i))	
			RemovePlayerModel(i)			

	new sArgs[8]; read_args(sArgs, charsmax(sArgs))
	if (str_to_num(sArgs) == 1)
	{
		new sFile[128]; get_localinfo("amxx_configsdir", sFile, charsmax(sFile))
		format(sFile, charsmax(sFile), "%s/%s", sFile, g_sExcludeFile)

		new iFileHandle = fopen(sFile, "at")
		if (iFileHandle)
		{
			new sCurrentMap[MAX_MAP_LEN]; get_mapname(sCurrentMap, charsmax(sCurrentMap))
			fprintf(iFileHandle, "\n%s", sCurrentMap)
			fclose (iFileHandle)
		}
	}

	new sAdminName[MAX_NAME_LEN]; get_user_name(id, sAdminName, charsmax(sAdminName))
	new sAdminAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAdminAuthid, charsmax(sAdminAuthid))
	new sAdminRealName[MAX_NAME_LEN]; fm_GetUserRealname(id, sAdminRealName, charsmax(sAdminRealName))
	
	client_print(0, print_chat, "* ADMIN #%d %s: disabled player models for this map", fm_GetUserIdent(id), sAdminRealName)
	console_print(id, "You have disabled player models for this map. Written to exclude file.")

	new sCommand[32]; read_argv(0, sCommand, charsmax(sCommand))
	log_amx("\"%s<%s>(%s)\" %s", sAdminName, sAdminAuthid, sAdminRealName, sCommand)

	return PLUGIN_HANDLED
}

CachePlayerModel(id, iModelIdent, iSkin)
{
	if (g_iCacheVault != INVALID_HANDLE)
	{
		new sAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAuthid, charsmax(sAuthid))
		new sData[32]; formatex(sData, charsmax(sData), "%d %d", iModelIdent != -1 ? iModelIdent : -1, iSkin)
		nvault_set(g_iCacheVault, sAuthid, sData)
	}
}

SavePlayerModel(id, iModelIdent, iSkin)
{
	if (g_iPlayerQuery[id])
	{
		fm_SQLRemoveThreadedQuery(g_iPlayerQuery[id])
	}

	CachePlayerModel(id, iModelIdent, iSkin)

	// Get the players player_id
	new iPlayerIdent = fm_SQLGetUserIdent(id)
	if (!iPlayerIdent)
	{
		return PLUGIN_CONTINUE
	}
	
	new iLen = formatex(g_sQuery, charsmax(g_sQuery), "UPDATE players SET model_id = ")
	if (iModelIdent != -1)
	{
		iLen += formatex(g_sQuery[iLen], charsmax(g_sQuery) - iLen, "%d", iModelIdent)			
	}
	else
	{
		iLen += formatex(g_sQuery[iLen], charsmax(g_sQuery) - iLen, "NULL")
	}
	iLen += formatex(g_sQuery[iLen], charsmax(g_sQuery) - iLen, ", model_skin = %d WHERE player_id = %d LIMIT 1;", iSkin, iPlayerIdent)

	new sData[1]; sData[0] = id
	g_iPlayerQuery[id] = fm_SQLAddThreadedQuery(g_sQuery, "Handle_UpdateModel", QUERY_DISPOSABLE, PRIORITY_LOW, sData, 1)	
	g_fPlayerNextChange[id] = get_gametime() + MODEL_CHANGE_DELAY

	return PLUGIN_CONTINUE	
}

public Handle_UpdateModel(iFailState, Handle:hQuery, sError[], iError, sData[], iLen, Float:fQueueTime)
{	
	fm_SQLCheckThreadedError(iFailState, hQuery, sError, iError)
	g_iPlayerQuery[sData[0]] = false
}

public Handle_Console(id) 
{
	new sArgs[192]; read_args(sArgs, charsmax(sArgs))
	remove_quotes(sArgs)

	if (!sArgs[0]) // No arguments supplied
		ModelMenu(id)
	else
		Handle_Model(id, sArgs, print_console)

	return PLUGIN_HANDLED
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
			Handle_Model(id, sArgs[6], print_chat)
			return PLUGIN_HANDLED		
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

Handle_Model(id, sArgs[], iPrintType) 
{
	if (!g_bAllowModel)
	{
		client_print(id, iPrintType, "%sModel changing is currently disabled", fm_PrintStar(iPrintType))
		return
	}

	new iModel, iSkin
	new sModel[MAX_MODEL_NAME_LEN], sSkin[8]
	strbreak(sArgs, sModel, charsmax(sModel), sSkin, charsmax(sSkin))

	if (equali(sArgs, "off") || equali(sArgs, "stop") || equali(sArgs, "default") || equali(sArgs, "none"))
	{
		RemovePlayerModel(id)
		SavePlayerModel(id, -1, 0)
		client_print(id, iPrintType, "%sYou have reset your player model to default", fm_PrintStar(iPrintType))		
	}		
	else if (equali(sArgs, "menu") || equali(sArgs, "list"))
		ModelMenu(id)
	
	else if ((iModel = GetModelIndexByName(sModel)) != -1)
	{
		if (!CheckModelDelay(id, iPrintType) /*&& !CheckModelAccess(id, iModel, iPrintType)*/)
		{
			iSkin = str_to_num(sSkin)
			if (iSkin < 1)
			{
				iSkin = 1
			}

			new Buffer[eModel_t]; ArrayGetArray(g_ModelList, iModel, Buffer); 
			if (iSkin > Buffer[m_iModelSkinCount])
			{
				iSkin = Buffer[m_iModelSkinCount]
			}

			SetPlayerModel(id, Buffer[m_sModelName], iSkin - 1)
			SavePlayerModel(id, Buffer[m_iModelIdent], iSkin - 1)
			client_print(id, iPrintType, "%sYou have changed your player model to \"%s\" using skin %d/%d", fm_PrintStar(iPrintType), Buffer[m_sModelName], iSkin, Buffer[m_iModelSkinCount])
		}
	}
	else
		client_print(id, iPrintType, "%sSorry but the model \"%s\" was not found. Type \"model menu\" for a list of availiable models", fm_PrintStar(iPrintType), sArgs)

	return
}


public ModelMenu(id)
{
	if (!g_bAllowModel)
	{
		client_print(id, print_chat, "* %s", g_sTextDisabled) 
	}
	else if (!g_iModelNum)	
	{
		client_print(id, print_chat, "* No custom player models have been loaded")
	}
	else 
	{
		g_iPlayerModelMenuPos[id] = g_iPlayerModelMenuPos[id] = g_iPlayerMenuSkin[id] = g_iPlayerMenuModel[id] = 0
		g_bPlayerModelSave[id] = false
		SelectModel(id, 0)
		CreateCamera(id)
	}
}

SelectModel(id, iPos)
{
	if(iPos < 0) 
	{	
		// Closed out of menu. SAVE
		if (g_bPlayerModelSave[id]) // Check they actually made a change
		{
			new Buffer[eModel_t]
			if (g_iPlayerMenuModel[id] != -1) // Is the change an actual model or did they set it back to default
			{
				ArrayGetArray(g_ModelList, g_iPlayerMenuModel[id], Buffer)	
			}
			else
			{
				Buffer[m_iModelIdent] = -1
			}
			SavePlayerModel(id, Buffer[m_iModelIdent], g_iPlayerMenuSkin[id])
		}
		ResetView(id)
		return PLUGIN_HANDLED
	}

	new sMenuBody[256], iCurrentKey, iKeys
	new iStart = iPos * MAX_MENU_MODELS	
	new iEnd = iStart + MAX_MENU_MODELS
	
	new iLen = formatex(sMenuBody, charsmax(sMenuBody), "Select Model: Page %d/%d\n\n", iPos + 1, (g_iModelNum / MAX_MENU_MODELS + ((g_iModelNum % MAX_MENU_MODELS) ? 1 : 0 )) )
	if(iEnd > g_iModelNum)
	{
		iEnd = g_iModelNum	
	}

	new Buffer[eModel_t]
	for(new i = iStart; i < iEnd; i++)
	{
		ArrayGetArray(g_ModelList, i, Buffer); 
		iLen += formatex(sMenuBody[iLen], (charsmax(sMenuBody) - iLen), "%d) %s\n", iCurrentKey + 1, Buffer[m_sModelName])
		iKeys |= (1<<iCurrentKey++)
	}
		
	iLen += formatex(sMenuBody[iLen], (charsmax(sMenuBody) - iLen), "\n8) Default")
	iKeys |= (1<<7)

	if(iEnd != g_iModelNum) 
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
	if (!g_bAllowModel) // In case the player had the model menu open before an admin disabled models
	{
		client_print(id, print_chat, "* %s", g_sTextDisabled) 
		ResetView(id)
		return PLUGIN_HANDLED
	}

	g_bPlayerModelSave[id] = true
	
	switch(iKey) 
	{
		case 8: SelectModel(id, ++g_iPlayerModelMenuPos[id]) // Next page
		case 9: SelectModel(id, --g_iPlayerModelMenuPos[id]) // Previous page
		case 7: 
		{
			RemovePlayerModel(id)
			g_iPlayerMenuModel[id] = -1
			g_iPlayerMenuSkin[id] = 0
			SelectModel(id, g_iPlayerModelMenuPos[id])
		}
		default: 
		{
			// New model selected. Reset skin selection
			g_iPlayerMenuSkin[id] = 0 

			// Get the model selected
			g_iPlayerMenuModel[id] = g_iPlayerModelMenuPos[id] * MAX_MENU_MODELS + iKey
			new Buffer[eModel_t]; ArrayGetArray(g_ModelList, g_iPlayerMenuModel[id] , Buffer)

			// Set the player model
			SetPlayerModel(id, Buffer[m_sModelName], 0)
			
			// If the skin count is greater than 1
			if (Buffer[m_iModelSkinCount] > 1)
			{
				// Open up the select skin menu
				SelectSkin(id, g_iPlayerSkinMenuPos[id] = 0)
			}
			else
			{
				// Reopen the model menu
				SelectModel(id, g_iPlayerModelMenuPos[id])
			}
		}
	}
	fm_PlaySound(id, FM_MENU_SELECT_SOUND)
	return PLUGIN_HANDLED
} 

SelectSkin(id, iPos)
{
	if(iPos < 0)
	{
		// Exit out of the skin menu and go back to the model menu
		SelectModel(id, g_iPlayerModelMenuPos[id]) 
		return PLUGIN_HANDLED	
	}

	new Buffer[eModel_t]; ArrayGetArray(g_ModelList, g_iPlayerMenuModel[id] , Buffer)
	new iSkinCount = Buffer[m_iModelSkinCount]

	new sMenuBody[256], iCurrentKey, iKeys
	new iStart = iPos * MAX_MENU_SKINS
	new iEnd = iStart + MAX_MENU_SKINS
	
	new iLen = formatex(sMenuBody, charsmax(sMenuBody), "Select Skin: Page %d/%d\n\n", iPos + 1, (iSkinCount / MAX_MENU_SKINS + ((iSkinCount % MAX_MENU_SKINS) ? 1 : 0 )) )
	
	if(iEnd > iSkinCount)
	{
		iEnd = iSkinCount	
	}

	for(new i = iStart; i < iEnd; i++)
	{
		iLen += formatex(sMenuBody[iLen], (charsmax(sMenuBody) - iLen), "%d) Skin %d\n", iCurrentKey + 1, g_iPlayerSkinMenuPos[id] * MAX_MENU_SKINS + iCurrentKey + 1)
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
	if (!g_bAllowModel) // Incase the player had the model menu open before an admin disabled models
	{
		client_print(id, print_chat, "* %s", g_sTextDisabled) 
		return PLUGIN_HANDLED
	}
	
	
	switch(iKey) 
	{
		case 8: SelectSkin(id, ++g_iPlayerSkinMenuPos[id]) // Next page
		case 9: SelectSkin(id, --g_iPlayerSkinMenuPos[id]) // Previous page
		default: 
		{
			// Get the skin key pressed
			g_iPlayerMenuSkin[id] = g_iPlayerSkinMenuPos[id] * MAX_MENU_SKINS + iKey

			// Get the model name
			new Buffer[eModel_t]; ArrayGetArray(g_ModelList, g_iPlayerMenuModel[id], Buffer)

			// Set the player model
			SetPlayerModel(id, Buffer[m_sModelName], g_iPlayerMenuSkin[id])

			// Open up the skin menu so they can try some more!
			SelectSkin(id, g_iPlayerSkinMenuPos[id])
		}
	}
	fm_PlaySound(id, FM_MENU_SELECT_SOUND)
	return PLUGIN_HANDLED
} 



CreateCamera(id)
{
	DestroyCamera(id)

	new iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	if (!iEnt) 
	{
		fm_WarningLog(FM_ENT_WARNING)
		return PLUGIN_HANDLED
	}

	g_iPlayerCameraEnt[id] = iEnt

        engfunc(EngFunc_SetModel, iEnt, "models/backpack.mdl") // Must have a model or setview doesn't work ...
        set_pev(iEnt, pev_rendermode, kRenderTransTexture)
        set_pev(iEnt, pev_renderamt, 0.0)
       
	new Float:fOrigin[3]; pev(id, pev_origin, fOrigin)
	new Float:fAngle[3]; pev(id, pev_v_angle, fAngle) 
	
	fAngle[0] = 0.0
	fAngle[2] = 0.0

	new Float:fVBack[3]; angle_vector(fAngle, ANGLEVECTOR_FORWARD, fVBack)

        fOrigin[0] += (fVBack[0] * 64.0)
        fOrigin[1] += (fVBack[1] * 64.0)
        fOrigin[2] += (fVBack[2] * 64.0)

        engfunc(EngFunc_SetOrigin, iEnt, fOrigin)

	// Reverse angle
	if (fAngle[1] < 0.0)
	{
		fAngle[1] += 180.0
	}
	else
	{
		fAngle[1] -=180.0
	}

	set_pev(iEnt, pev_angles, fAngle)
	engfunc(EngFunc_SetView, id, iEnt)

	return PLUGIN_HANDLED
}

DestroyCamera(id)
{
	if (g_iPlayerCameraEnt[id])
	{
		engfunc(EngFunc_RemoveEntity, g_iPlayerCameraEnt[id])
		g_iPlayerCameraEnt[id] = 0
	}
}

public ResetView(id)
{
	engfunc(EngFunc_SetView, id, id)
	DestroyCamera(id)
}
