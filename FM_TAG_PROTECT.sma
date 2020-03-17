#include "feckinmad/fm_global"
#include "feckinmad/fm_admin_access"

#include <fakemeta>

new const g_sTag[] = "[FM]"

public plugin_init()
{
	fm_RegisterPlugin()
	register_forward(FM_ClientUserInfoChanged, "Forward_ClientUserInfoChanged")
}

public Forward_ClientUserInfoChanged(id, Buffer)
{
	if (!is_user_connected(id))
	{
		return FMRES_IGNORED
	}

	new sOldName[MAX_NAME_LEN]; get_user_name(id, sOldName, charsmax(sOldName))
	new sNewName[MAX_NAME_LEN]; engfunc(EngFunc_InfoKeyValue, Buffer, "name", sNewName, charsmax(sNewName))	
	
	if (!equal(sOldName, sNewName) && containi(sNewName, g_sTag) != -1 && !(fm_GetUserAccess(id) & ADMIN_MEMBER))
	{
		engfunc(EngFunc_SetClientKeyValue, id, Buffer, "name", sOldName)
		client_cmd(id, "name \"%s\"; setinfo name \"%s\"", sOldName, sOldName)
		console_print(id, "You do not have access to the %s tag", g_sTag)
		return FMRES_SUPERCEDE
	}

	return FMRES_IGNORED
}
