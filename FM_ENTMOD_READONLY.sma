#include "feckinmad/fm_global"
#include "feckinmad/entmod/fm_entmod_base"

stock const g_sReadOnlyKey[] = "fm_entmod_readonly"

public plugin_init()
{
	fm_RegisterPlugin()
}

public fm_RunEntCommand(id, iEnt)
{
	if (fm_GetCachedEntKey(iEnt, g_sReadOnlyKey) != -1)
	{
		client_print(id, print_chat, "* This entity is read only. In order to make any modifications you must make a copy")
		return PLUGIN_HANDLED
	}
	return PLUGIN_CONTINUE
}