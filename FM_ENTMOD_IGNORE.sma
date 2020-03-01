#include "feckinmad/fm_global"
#include "feckinmad/entmod/fm_entmod_base"

stock const g_sIgnoreKey[] = "fm_entmod_ignore"

public plugin_init()
{
	fm_RegisterPlugin()
}

public fm_RunEntCommand(id, iEnt, iMode)
{
	if (fm_GetCachedEntKey(iEnt, g_sIgnoreKey) != -1)
	{
		client_print(id, print_chat, "* You cannot use entmod commands on this entity")
		return PLUGIN_HANDLED
	}
	return PLUGIN_CONTINUE
}