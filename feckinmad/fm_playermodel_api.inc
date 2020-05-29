#if defined _fm_playermodel_included
  #endinput
#endif
#define _fm_playermodel_included

#define MAX_MODEL_NAME_LEN 32
#define SKIN_NAME_LEN 64
#define BODY_NAME_LEN 64

stock const g_sPlayerModelAPILibName[] = "fm_playermodel_api"
stock const g_sTextDisabled[] = "Custom player models are currently disabled"
stock const g_sExcludeFile[] = "fm_models_exlude.ini" // File containing list of maps that models should be disabled on. 

enum eModel_t
{
	m_iModelIdent,
	m_sModelName[MAX_MODEL_NAME_LEN],
	m_iModelSkinCount,
	m_iModelBodyCount,
	Array:m_ModelSkinNames,
	Array:m_ModelBodyParts
}

enum eBodyPart_t
{
	m_sBodyPartName[BODY_NAME_LEN],
	m_iBodyPartCount,
	m_iBodyPartBase
}

enum
{
	MENU_TYPE_MODEL = 0,
	MENU_TYPE_SKIN,
	MENU_TYPE_BODYGROUP,
	MENU_TYPE_BODYSUB,
	MENU_TYPE_COUNT
}

native fm_GetPlayerModelStatus()
native fm_GetPlayerModelCount()
native fm_SetPlayerModelDisabled()
native fm_SetPlayerModel(id, ModelName[])
native fm_SetPlayerSkin(id, iSkin)
native fm_SetPlayerBody(id, iGroup, iBody)
native fm_SetPlayerBodyValue(id, iValue)
native fm_AddPlayerModel(iModelIdent, sModelName[])
native fm_RemovePlayerModel(id)
native fm_GetPlayerModelIndexByName(sModelName[])
native fm_GetPlayerModelDataByIndex(iModelIdent, ModelData[eModel_t])
native fm_GetPlayerModelNameByIndex(iModelIdent, sModelName[], iSize)
native fm_GetPlayerModelIndexByIdent(iModelIdent)
native fm_GetPlayerModelIdentByIndex(iModelIndex)