#include "feckinmad/fm_global"

#include <fakemeta>
#include <hamsandwich>

public plugin_init()
{
	fm_RegisterPlugin()
	RegisterHam(Ham_AddPlayerItem, "player", "Forward_Ham_AddPlayerItem")
}

public Forward_Ham_AddPlayerItem(id, iEnt)
{
	static sClassName[32]; pev(iEnt, pev_classname, sClassName, charsmax(sClassName))
	if (equal(sClassName, "tf_weapon_autorifle"))
	{
		ExecuteHam(Ham_Item_Kill, iEnt)
		return HAM_SUPERCEDE
	}
	return HAM_IGNORED	
}

