#include "feckinmad/fm_global"
#include "feckinmad/fm_admin_access"

new g_pCvarEntModAccess, g_iMaxPlayers, g_iAdminAccessLib

public plugin_init()
{
	fm_RegisterPlugin()
	g_iMaxPlayers = get_maxplayers()
	g_pCvarEntModAccess = register_cvar("fm_entmod_access", "0")
	g_iAdminAccessLib = LibraryExists(g_sAdminAccessLibName, LibType_Library)
}

public plugin_natives()
{
	register_native("fm_GetEntModAccess", "Native_GetEntModAccess")

	set_module_filter("Module_Filter")
	set_native_filter("Native_Filter")

	register_library("fm_entmod_access")
}

public Native_GetEntModAccess()
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

	switch(get_pcvar_num(g_pCvarEntModAccess))
	{
		case 1:
		{
			if (g_iAdminAccessLib && fm_GetUserAccess(id) <= 0)
			{
				return 0				
			}
			return 1
		}
		case 2: return 1
		default: return 0
	}
	return 0
}

public Module_Filter(sModule[])
{
	if (equal(sModule, g_sAdminAccessLibName))
	{
		return PLUGIN_HANDLED
	}
	return PLUGIN_CONTINUE
}

public Native_Filter(sName[], iIndex, iTrap)
{
	if (!iTrap)
	{
		return PLUGIN_HANDLED
	}
	return PLUGIN_CONTINUE
}


