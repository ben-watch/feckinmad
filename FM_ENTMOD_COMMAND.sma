#include "feckinmad/fm_global"
#include "feckinmad/fm_point" // fm_GetAimEntity()
#include "feckinmad/entmod/fm_entmod_move" // fm_GetPlayerMoveEnt()
#include "feckinmad/entmod/fm_entmod_command" // fm_CommandGetEntity()

#include <fakemeta>

new g_iForward, g_iMaxPlayers
new g_iMovePlugin

public plugin_natives()
{
	register_native("fm_CommandGetEntity", "Native_CommandGetEntity")
	register_native("fm_CommandCheckEntity", "Native_CommandCheckEntity")

	register_library("fm_entmod_command")

	set_module_filter("Module_Filter")
	set_native_filter("Native_Filter")
}

public plugin_init()
{
	fm_RegisterPlugin()

	g_iMaxPlayers = get_maxplayers()
	g_iForward = CreateMultiForward("fm_RunEntCommand", ET_STOP, FP_CELL, FP_CELL, FP_CELL)
	g_iMovePlugin = LibraryExists("fm_entmod_move", LibType_Library)
}

public plugin_end()
{
	if (g_iForward > 0) 
	{
		DestroyForward(g_iForward)
	}
}

public Native_CommandGetEntity()
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

	static sArg[8]; get_string(2, sArg, charsmax(sArg))
	new iLen = strlen(sArg)
	if (!iLen) 
	{
		console_print(id, "You must specify an enitity")
		return 0 
	}

	// If you press the up arrow to repeat a command in the hl console it adds a space to the end of the line. Remove it.
	new iEndChar = iLen - 1
	if (sArg[iEndChar] == ' ')
	{
		sArg[iEndChar] = 0
	}

	// If the player specifies -1, I use the entity they are moving or the entity they are looking at
	new iEnt = str_to_num(sArg)
	if (iEnt == -1)
	{
		if (g_iMovePlugin)
		{
			iEnt = fm_GetPlayerMoveEnt(id)
		}

		if (!iEnt)
		{
			iEnt = fm_GetAimEntity(id)
		}
	}
	return iEnt
}

public Native_CommandCheckEntity()
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

	new iEnt = get_param(2)
	if (!pev_valid(iEnt))
	{
		console_print(id, "Entity %d is not valid", iEnt)
		return 0
	}

	if (iEnt > 0 && iEnt <= g_iMaxPlayers)
	{	
		console_print(id, "You cannot run ent commands on players")
		return 0
	}
 
	new iReturn, iMode = get_param(3)
	ExecuteForward(g_iForward, iReturn, id, iEnt, iMode)

	if (iReturn == PLUGIN_HANDLED)
	{
		return 0
	}
	return 1
}


public Module_Filter(sModule[])
{
	// Load the plugin even if the entmod move plugin is not running
	if (equal(sModule, "fm_entmod_move"))
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
