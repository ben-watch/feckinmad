#include "feckinmad/fm_global"

#include <fakemeta>

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
	
	if (!equal(sOldName, sNewName) && sNewName[0] == '#')
	{
		if (!sOldName[0])
		{
			copy(sOldName, charsmax(sOldName), "Player")
		}
	
		engfunc(EngFunc_SetClientKeyValue, id, Buffer, "name", sOldName)
		client_cmd(id, "name \"%s\"; setinfo name \"%s\"", sOldName, sOldName)
		return FMRES_SUPERCEDE
	}

	return FMRES_IGNORED
}
