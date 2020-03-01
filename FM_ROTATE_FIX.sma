// This plugin attempts to fix a bug with func_rotating on linux servers where the rotating entity visually stop but physically continue rotating.
// When a func_rotating spins its angle values increase. i.e. 360 would be a full rotation, 2790 would be 7.75 rotations. 
// Each axis has a seperate value and these values can also be negative depending on which direction the entity is spinning
// Once these values overflow the maximum value an integer can hold the bug occurs. The time this takes depends on how fast the entity is spinning
// This plugin checks the entity periodically and seamlessly reduces the angle values down so they do not overflow

#include "feckinmad/fm_global"
#include <fakemeta>

new const g_sRotateClassname[] = "func_rotating"

public plugin_init() 
{
	fm_RegisterPlugin()

	if (engfunc(EngFunc_FindEntityByString, -1, "classname", g_sRotateClassname) > 0)
	{
		register_forward(FM_Think, "Forward_Think")
	}

	return PLUGIN_CONTINUE
}

// func_rotating think every 10 seconds or every 0.1 seconds if its spinning down/up
public Forward_Think(iEnt)
{
	if (!pev_valid(iEnt))
	{ 
		return FMRES_IGNORED
	}

	static sClassname[sizeof g_sRotateClassname]
	pev(iEnt, pev_classname, sClassname, charsmax(sClassname))

	if (!equal(sClassname[5], g_sRotateClassname[5])) // Skip "func_" to optimize
	{
		return FMRES_IGNORED	
	}

	static Float:fAngles[3]
	pev(iEnt, pev_angles, fAngles)

	new bool:bUpdate
	
	for (new i = 0; i < 3; i++)
	{
		if (fAngles[i] >= 360.0 || fAngles[i] <= -360.0) 
		{
			fAngles[i] -= float(360 * (floatround(fAngles[i]) / 360)) 
			bUpdate = true
		}
	}

	if (bUpdate)
	{
		set_pev(iEnt, pev_angles, fAngles)
	}

	return FMRES_IGNORED
}
