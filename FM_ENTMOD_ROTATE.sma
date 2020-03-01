#include "feckinmad/fm_global"

#include "feckinmad/entmod/fm_entmod_base" // fm_SetCachedEntKeyVector()
#include "feckinmad/entmod/fm_entmod_access" // fm_CheckUserEntAccess()
#include "feckinmad/entmod/fm_entmod_command" // fm_CommandGetEntity()

#include <fakemeta>

public  plugin_init()
{
	fm_RegisterPlugin()

	register_clcmd("fm_ent_rotate_x", "Player_RotateAngle")
	register_clcmd("fm_ent_rotate_y", "Player_RotateAngle")
	register_clcmd("fm_ent_rotate_z", "Player_RotateAngle")
}

public Player_RotateAngle(id)
{
	if (!fm_CheckUserEntAccess(id))
	{
		return PLUGIN_HANDLED
	}

	new sArg[8]; read_argv(1, sArg, charsmax(sArg))
	new iEnt = fm_CommandGetEntity(id, sArg)
	if (!iEnt || !fm_CommandCheckEntity(id, iEnt, ENTCMD_MODIFY)) 
	{
		return PLUGIN_HANDLED
	}

	// Rely on data from base ent plugin on map load, as moving ents stores origin for consistency
	if (!fm_EntityHasOriginBrush(iEnt))
	{
		console_print(id, "Entity #%d: Unable to rotate as it has no origin", iEnt)
		return PLUGIN_HANDLED
	}

	read_argv(2, sArg, charsmax(sArg))
	new Float:fAngles[3]; pev(iEnt, pev_angles, fAngles)

	new sCommand[16]; read_argv(0, sCommand, charsmax(sCommand))
	switch(sCommand[14])
	{
		case 'x': fAngles[0] += str_to_float(sArg)
		case 'y': fAngles[1] += str_to_float(sArg)
		case 'z': fAngles[2] += str_to_float(sArg)
	}

	set_pev(iEnt, pev_angles, fAngles)
	fm_SetCachedEntKeyVector(iEnt, "angles", fAngles)

	console_print(id, "Entity #%d: rotated %d degrees on the %c axis", iEnt, str_to_num(sArg), sCommand[14])

	return PLUGIN_HANDLED	
}