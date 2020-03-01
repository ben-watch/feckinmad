#include "feckinmad/fm_global"

#include <fakemeta>

#define PC_SOLDIER 3
#define PD_AMMO_NADE2 15
#define PD_LINUX_DIFF 3

public plugin_init() 
{
	fm_RegisterPlugin()
	
	register_clcmd("primetwo", "Handle_SecondaryGrenade")
	register_clcmd("+gren2", "Handle_SecondaryGrenade")
}

public Handle_SecondaryGrenade(id) 
{
	if (pev(id, pev_playerclass) != PC_SOLDIER)
		return PLUGIN_CONTINUE

	if (!get_pdata_int(id, PD_AMMO_NADE2, PD_LINUX_DIFF))
		return PLUGIN_CONTINUE

	new iEnt
	while ((iEnt = engfunc(EngFunc_FindEntityByString, iEnt, "classname", "tf_weapon_nailgrenade")) > 0)
	{
		if (pev(iEnt, pev_owner) == id)
		{
			client_print(id, print_center, "You already have an active nail grenade")
			return PLUGIN_HANDLED // Block command from being processed by TFC
		}
	}
	return PLUGIN_CONTINUE
}

