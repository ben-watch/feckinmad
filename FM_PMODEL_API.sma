#include "feckinmad/fm_global"
#include "feckinmad/fm_precache" // fm_SafePrecacheModel()
#include "feckinmad/fm_playermodel_api"
#include <fakemeta>

new Array:g_ModelList

// Pdata defines
#define PD_REPLACE_MODEL 170
#define PD_REPLACE_SKIN	172
#define PD_LINUX_DIFF 3

// Struct sizes for mdl data
#define STRUCT_SIZE_TEXDATA 80 // char[64], int, int, int, int
#define STRUCT_SIZE_BODYDATA 76 // char[64], int, int, int

// Engine limits
#define MAX_SKIN_COUNT 100
#define MAX_BODY_COUNT 32

new bool:g_bAllowModel = true
new bool:g_bPreacheDone
new g_iModelNum, g_iMaxPlayers
new g_iPlayerCurrentPlayerModel[MAX_PLAYERS + 1] = { -1, ...}

public plugin_init() 
{ 
	fm_RegisterPlugin()
	g_iMaxPlayers = get_maxplayers()
	g_bPreacheDone = true

	register_clcmd("debugmodel", "DebugPrintModelData")
}

public plugin_natives()
{
	register_native("fm_GetPlayerModelStatus", "Native_GetPlayerModelStatus")
	register_native("fm_GetPlayerModelCount", "Native_GetPlayerModelCount")
	register_native("fm_SetPlayerModelDisabled", "Native_SetPlayerModelDisabled")
	register_native("fm_SetPlayerModel", "Native_SetPlayerModel")
	register_native("fm_SetPlayerSkin", "Native_SetPlayerSkin")
	register_native("fm_SetPlayerBody", "Native_SetPlayerBody")
	register_native("fm_SetPlayerBodyValue", "Native_SetPlayerBodyValue")
	register_native("fm_AddPlayerModel", "Native_AddPlayerModel")
	register_native("fm_RemovePlayerModel", "Native_RemovePlayerModel")
	register_native("fm_GetPlayerModelIndexByName", "Native_GetPlayerModelIndexByName")
	register_native("fm_GetPlayerModelIndexByIdent", "Native_GetPlayerModelIndexByIdent")
	register_native("fm_GetPlayerModelIdentByIndex", "Native_GetPlayerModelIdentByIndex")
	register_native("fm_GetPlayerModelDataByIndex", "Native_GetPlayerModelDataByIndex")
	register_native("fm_GetPlayerModelNameByIndex", "Native_GetPlayerModelNameByIndex")

	register_library(g_sPlayerModelAPILibName)
}

Array:GetModelArray()
{
	if (g_ModelList == Invalid_Array)
	{
		g_ModelList = ArrayCreate(eModel_t)
	}
	return g_ModelList
}

public Native_GetPlayerModelCount(iPlugin, iParams)
{
	return g_iModelNum
}

public Native_GetPlayerModelStatus(iPlugin, iParams)
{
	return g_bAllowModel
}

public Native_SetPlayerModelDisabled(iPlugin, iParams)
{
	g_bAllowModel = false
}

public Native_GetPlayerModelIndexByName(iPlugin, iParams)
{
	new sModelName[MAX_MODEL_NAME_LEN]; get_string(2, sModelName, charsmax(sModelName))
	return GetModelIndexByName(sModelName)
}

public Native_GetPlayerModelDataByIdent(iPlugin, iParams)
{
	new iModelIndent = get_param(1)
	new Array:ModelArray = GetModelArray()
	new Buffer[eModel_t]
	for(new i = 0; i < g_iModelNum; i++)
	{
		ArrayGetArray(ModelArray, i, Buffer)
		if (iModelIndent == Buffer[m_iModelIdent])
		{
			set_array(2, Buffer, eModel_t)
			return i
		}
	}
	return -1
}

public Native_GetPlayerModelDataByIndex(iPlugin, iParams)
{
	new iModelIndex = get_param(1)
	if (iModelIndex < 0 || iModelIndex >= g_iModelNum) 
	{	
		log_error(AMX_ERR_NATIVE, "Model index out of range (%d)", iModelIndex)
		return 0
	}

	new Buffer[eModel_t]; ArrayGetArray(Array:GetModelArray(), iModelIndex , Buffer)
	set_array(2, Buffer, eModel_t)
	return 1
}

public Native_GetPlayerModelNameByIndex(iPlugin, iParams)
{
	new iModelIndex = get_param(1)
	if (iModelIndex < 0 || iModelIndex >= g_iModelNum) 
	{	
		log_error(AMX_ERR_NATIVE, "Model index out of range (%d)", iModelIndex)
		return 0
	}

	new Buffer[eModel_t]; ArrayGetArray(Array:GetModelArray(), iModelIndex , Buffer)
	set_array(2, Buffer[m_sModelName], get_param(3))
	return 1
}

// This returns the index of the specified model_id in the g_sModelList array
public Native_GetPlayerModelIndexByIdent(iPlugin, iParams)
{
	new iModelIndent = get_param(1)	
	new Array:ModelArray = GetModelArray()
	new Buffer[eModel_t]

	for(new i = 0; i < g_iModelNum; i++)
	{
		ArrayGetArray(ModelArray, i, Buffer)
		if (iModelIndent == Buffer[m_iModelIdent])
		{
			return i
		}
	}
	return -1
}

// This returns the ident of the specified index in the g_sModelList array
public Native_GetPlayerModelIdentByIndex(iPlugin, iParams)
{
	new iModelIndex = get_param(1)	
	new Array:ModelArray = GetModelArray()

	if (iModelIndex < 0 || iModelIndex > g_iModelNum)
	{
		log_error(AMX_ERR_NATIVE, "Model index out of range (%d)", iModelIndex)
		return -1
	}

	new Buffer[eModel_t]; ArrayGetArray(ModelArray, iModelIndex, Buffer)
	return Buffer[m_iModelIdent]
}

public Native_AddPlayerModel(iPlugin, iParams)
{
	new iModelIdent = get_param(1)
	new sModelName[MAX_MODEL_NAME_LEN]; get_string(2, sModelName, charsmax(sModelName))
	fm_DebugPrintLevel(1, "Native_AddPlayerModel(%d, %s)", iModelIdent, sModelName)

	if (g_bPreacheDone)
	{
		return 0
	}

	if (iModelIdent < 1) 
	{
		log_error(AMX_ERR_NATIVE, "Model ident out of range (%d)", iModelIdent)
		return 0
	}

	new sModelPath[MAX_RESOURCE_LEN]; formatex(sModelPath, charsmax(sModelPath), "models/player/%s/%s.mdl", sModelName, sModelName)
	new Model[eModel_t]
	Model[m_sModelName] = sModelName
	Model[m_iModelIdent] = iModelIdent

	if (!ReadModelData(Model, sModelPath))
	{
		// Warning log
		return 0
	}

	if (!fm_SafePrecacheModel(sModelPath)) // Warning logging inside function
	{
		return 0
	}

	ArrayPushArray(Array:GetModelArray(), Model)
	g_iModelNum++
	return 1
}

public Native_RemovePlayerModel(iPlugin, iParams)
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

	set_pdata_int(id, PD_REPLACE_MODEL, 0, PD_LINUX_DIFF)
	set_pdata_int(id, PD_REPLACE_SKIN, 0, PD_LINUX_DIFF)
	g_iPlayerCurrentPlayerModel[id] = -1

	return 1
}

public client_disconnected(id)
{
	g_iPlayerCurrentPlayerModel[id] = -1
}

public Native_SetPlayerModel(iPlugin, iParams)
{
	new id = get_param(1)
	new sModelName[MAX_MODEL_NAME_LEN]; get_string(2, sModelName, charsmax(sModelName))
	fm_DebugPrintLevel(1, "Native_SetPlayerModel(%d, %s)", id, sModelName)

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

	new iModelIndex = GetModelIndexByName(sModelName)
	if (iModelIndex == -1)
	{
		fm_WarningLog("Invalid model passed to Native_SetPlayerModel: \"%s\"", sModelName)
		return 0
	}
	
	g_iPlayerCurrentPlayerModel[id] = iModelIndex

	set_kvd(0, KV_ClassName, "player")
	set_kvd(0, KV_KeyName, "replacement_model")
	set_kvd(0, KV_Value, sModelName)
	set_kvd(0, KV_fHandled, 0)
	dllfunc(DLLFunc_KeyValue, id, 0)

	engfunc(EngFunc_SetClientKeyValue, id, engfunc(EngFunc_GetInfoKeyBuffer, id), "model", sModelName) // Update straight away
	return 1
}

public Native_SetPlayerBody(iPlugin, iParams)
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

	new iGroup = get_param(2)
	new iValue = get_param(3)

	fm_DebugPrintLevel(1, "Native_SetPlayerBody(%d, %d, %d)", id, iGroup, iValue)

	// animation.cpp from hlsdk was a useful reference here. See SetBodygroup[...]
	// TODO: BOUNDS CHECKS
	new Model[eModel_t]; ArrayGetArray(Array:GetModelArray(), g_iPlayerCurrentPlayerModel[id], Model)
	if (Model[m_iModelBodyCount] <= 1 || Model[m_ModelBodyParts] == Invalid_Array)
	{
		return 0
	}

	new BodyPart[eBodyPart_t]; ArrayGetArray(Model[m_ModelBodyParts], iGroup, BodyPart)
	new iPlayerBody = pev(id, pev_body)
	new iCurrent = (iPlayerBody / BodyPart[m_iBodyPartBase]) % BodyPart[m_iBodyPartCount]
	new iNew = iPlayerBody + (iValue - iCurrent) * BodyPart[m_iBodyPartBase]
	set_pev(id, pev_body, iNew)

	fm_DebugPrintLevel(2, "Native_SetPlayerBody: set_pev body to %d", iNew)

	return 1
}

public Native_SetPlayerBodyValue(iPlugin, iParams)
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

	new iValue = get_param(2)
	set_pev(id, pev_body, iValue )
	fm_DebugPrintLevel(2, "Native_SetPlayerBodyValue: set_pev body to %d", iValue)

	return 1
}


public Native_SetPlayerSkin(iPlugin, iParams)
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

	new iSkin = get_param(2)
	//TODO: BOUNDS CHECKS

	new sSkin[8]; num_to_str(iSkin, sSkin, charsmax(sSkin))
	set_kvd(0, KV_ClassName, "player")
	set_kvd(0, KV_KeyName, "replacement_model_skin")
	set_kvd(0, KV_Value, sSkin)
	set_kvd(0, KV_fHandled, 0)
	dllfunc(DLLFunc_KeyValue, id, 0)

	return 1
}

ReadModelData(Model[eModel_t], sModelPath[])
{
	new iTextureCount, iTextureOffset, iSkinCount, iSkinFamilyCount, iSkinOffset, iBodyCount, iBodyOffset, iSkinTextureIndex
	new iFileHandle = fopen(sModelPath, "rb")
	if (!iFileHandle)
	{
		return 0
	}

	// Get texture info from the header
	fseek(iFileHandle, 180, SEEK_SET) // Skip 180 bytes into the mdl header
	fread(iFileHandle, iTextureCount, BLOCK_INT) // Read Texture Count
	fread(iFileHandle, iTextureOffset, BLOCK_INT) // Read Texture Offset
	fseek(iFileHandle, 4, SEEK_CUR) // Skip Texture Data Offset 
	fm_DebugPrintLevel(2, "iTextureCount: %d iTextureOffset: %d", iTextureCount, iTextureOffset)

	// Get skin info from the header
	fread(iFileHandle, iSkinCount, BLOCK_INT) // Read Skin Count
	fread(iFileHandle, iSkinFamilyCount, BLOCK_INT) // Read Skin Family Count
	fread(iFileHandle, iSkinOffset, BLOCK_INT) // Read Skin Offset
	Model[m_iModelSkinCount] = iSkinFamilyCount
	fm_DebugPrintLevel(2, "iSkinCount: %d iSkinFamilyCount: %d iSkinOffset: %d", iSkinCount, iSkinFamilyCount, iSkinOffset)

	// Get body info from the header
	fread(iFileHandle, iBodyCount, BLOCK_INT) // Read Body Count	
	fread(iFileHandle, iBodyOffset, BLOCK_INT) // Read Body Offset
	Model[m_iModelBodyCount] = iBodyCount
	fm_DebugPrintLevel(2, "iBodyCount: %d iBodyOffset: %d", iBodyCount, iBodyOffset)

	// Seek to the bodypart data and store the name and values needed for menu generation and pev_body calculations later
	if (iBodyCount > 1)
	{
		Model[m_ModelBodyParts] = ArrayCreate(eBodyPart_t)
		new Buffer[eBodyPart_t]
		for (new i = 0; i < iBodyCount; i++)
		{
			fseek(iFileHandle, iBodyOffset + (i * STRUCT_SIZE_BODYDATA), SEEK_SET)
			fread_blocks(iFileHandle, Buffer[m_sBodyPartName], BODY_NAME_LEN, BLOCK_CHAR)
			fread(iFileHandle, Buffer[m_iBodyPartCount], BLOCK_INT) // Read Body Part Num Models
			fread(iFileHandle, Buffer[m_iBodyPartBase], BLOCK_INT) // Read Body Part Base

			fm_DebugPrintLevel(2, "Body %d: %s m_iBodyPartCount: %d m_iBodyPartBase: %d", i, Buffer[m_sBodyPartName], Buffer[m_iBodyPartCount], Buffer[m_iBodyPartBase])				
			ArrayPushArray(Model[m_ModelBodyParts], Buffer)
		}
	}

	if (iSkinFamilyCount > 1)
	{
		new sTextureName[SKIN_NAME_LEN]
		Model[m_ModelSkinNames] = ArrayCreate(SKIN_NAME_LEN)
		for (new i = 0; i < iSkinFamilyCount; i++)
		{
			// Seek to the skin data offset
			fseek(iFileHandle, iSkinOffset + (i * BLOCK_SHORT * iSkinCount), SEEK_SET) 

			// Read the index of the texture this skin uses. 
			// BUGBUG: Here there is an assumption that the first texture is the one that contains the name to use. 
			// A model can have multiple skins in each skin family, thus this is wrong for some models and I will have to fix later.
			fread(iFileHandle, iSkinTextureIndex, BLOCK_SHORT) 
		
			// Seek to the offset of the texture name based on the index above
			fseek(iFileHandle, iTextureOffset + (iSkinTextureIndex * STRUCT_SIZE_TEXDATA), SEEK_SET) 
		
			// Read the texture name and store for later
			fread_blocks(iFileHandle, sTextureName, SKIN_NAME_LEN, BLOCK_CHAR) 
			sTextureName[strlen(sTextureName) - 4] = 0 // Remove ".bmp" file ext
			ArrayPushString(Model[m_ModelSkinNames], sTextureName)

			fm_DebugPrintLevel(2, "iSkinTextureIndex: %d sTextureName: %s", iSkinTextureIndex, sTextureName)
		}
	}
	return 1
}

// This function returns the index of the specified model name in the g_sModelList array
GetModelIndexByName(sModel[])
{
	new Buffer[eModel_t]
	for(new i = 0; i < g_iModelNum; i++)
	{
		ArrayGetArray(Array:GetModelArray(), i, Buffer)
		if (equali(sModel, Buffer[m_sModelName]))
		{
			return i
		}
	}
	return -1
}

public plugin_end()
{
	if (g_ModelList != Invalid_Array)
	{
		new Buffer[eModel_t]
		for(new i = 0; i < g_iModelNum; i++)
		{
			ArrayGetArray(g_ModelList, i, Buffer)
			if (Buffer[m_ModelSkinNames] != Invalid_Array)
			{
				ArrayDestroy(Buffer[m_ModelSkinNames])
			}
			if (Buffer[m_ModelBodyParts] != Invalid_Array)
			{
				ArrayDestroy(Buffer[m_ModelBodyParts])
			}
		}
		ArrayDestroy(g_ModelList)
	}
}

public DebugPrintModelData(id)
{
	new Array:ModelArray = GetModelArray()
	new Buffer[eModel_t]

	for(new i = 0; i < g_iModelNum; i++)
	{
		ArrayGetArray(ModelArray, i, Buffer)
		console_print(id, "%d Ident: %d Name: %s", i, Buffer[m_iModelIdent], Buffer[m_sModelName])
	}	
}