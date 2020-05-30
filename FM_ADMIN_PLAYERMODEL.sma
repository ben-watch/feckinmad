#include "feckinmad/fm_global"
#include "feckinmad/fm_admin_access"
#include "feckinmad/fm_playermodel_api"

public plugin_init() 
{ 
	fm_RegisterPlugin()
	register_concmd("admin_disablemodels", "Admin_DisableModels", ADMIN_MEMBER)
}

public Admin_DisableModels(id, iLevel, iCommand)
{
	if (!fm_CommandAccess(id, iLevel, false)) 
	{
		return PLUGIN_HANDLED
	}
	
	// Check that models have not already been disabled
	if (!fm_GetPlayerModelStatus())
	{
		console_print(id, g_sTextDisabled)
		return PLUGIN_HANDLED
	}

	fm_SetPlayerModelDisabled()
	
	for (new i = 1, iMaxPlayers = get_maxplayers(); i <= iMaxPlayers; i++)	
		fm_RemovePlayerModel(i)			

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

//fm_PlayerModelReload
