#include "feckinmad/fm_global"

#include <fakemeta>

public plugin_init()
{
	register_forward(FM_ClientKill, "Forward_ClientKill")
}

public Forward_ClientKill(id)
{
	if (pev(id, pev_team) > 0)
	{
		return FMRES_SUPERCEDE
	}
	return FMRES_IGNORED
}
