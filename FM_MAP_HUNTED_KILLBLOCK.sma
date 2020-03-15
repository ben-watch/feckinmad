#include "feckinmad/fm_global"

#include <fakemeta>

public plugin_init()
{
	fm_RegisterPlugin()
	register_forward(FM_ClientKill, "Forward_ClientKill")
}

public Forward_ClientKill(id)
{
	if (pev(id, pev_team) == 1)
	{
		return FMRES_SUPERCEDE
	}
	return FMRES_IGNORED
}
