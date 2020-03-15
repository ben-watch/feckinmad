#include "feckinmad/fm_global"
#include "feckinmad/fm_point" // fm_GetAimOrigin()

#include "feckinmad/entmod/fm_entmod_misc" // fm_EntSetOrigin()
#include "feckinmad/entmod/fm_entmod_command" // fm_CommandCheckEntity()
#include "feckinmad/entmod/fm_entmod_access" // fm_CheckUserEntAccess()
#include "feckinmad/entmod/fm_entmod_render" // Restoring original rendering after moving
#include "feckinmad/entmod/fm_entmod_solid" // Restoring original solid after moving

#include <fakemeta>

new g_iPlayerMoveEnt[MAX_PLAYERS + 1] // The entity the player is moving

new Float:g_fPlayerViewMoveEntOffset[MAX_PLAYERS + 1][3] // The offset between the entity origin and the aimed origin
new Float:g_fPlayerMaxEntDist[MAX_PLAYERS + 1] // The maximum distance to hold the ent away from the player
new Float:g_fPlayerEntLastDist[MAX_PLAYERS + 1] // The current distance of the entity from the player when moving

new g_iMaxPlayers

public  plugin_init()
{
	fm_RegisterPlugin()

	g_iMaxPlayers = get_maxplayers()

	register_forward(FM_PlayerPreThink, "Forward_PreThink") 

	register_clcmd("+fm_ent_move", "Player_StartMove")
	register_clcmd("-fm_ent_move", "Player_StopMove")

	register_clcmd("fm_ent_further", "Player_Further")
	register_clcmd("fm_ent_closer", "Player_Closer")
}


public Player_StartMove(id)
{
	if (g_iPlayerMoveEnt[id] > 0)
	{
		return PLUGIN_HANDLED
	}
	
	// Issues with +commands???
	if (!is_user_connected(id) || !fm_CheckUserEntAccess(id))
	{
		return PLUGIN_HANDLED
	}

	if (!is_user_alive(id))
	{
		return PLUGIN_HANDLED
	}


	new iEnt = fm_GetAimEntity(id)
	if (!iEnt || !fm_CommandCheckEntity(id, iEnt, ENTCMD_MODIFY)) 
	{
		return PLUGIN_HANDLED
	}

	StartMoving(id, iEnt, 255, 0, 0)

	return PLUGIN_HANDLED
}

StartMoving(id, iEnt, iRed, iGreen, iBlue)
{
	g_iPlayerMoveEnt[id] = iEnt

	new Float:fPlayerOrigin[3]; pev(id, pev_origin, fPlayerOrigin)
	new Float:fEntOrigin[3]; pev(iEnt, pev_origin, fEntOrigin)
	new Float:fAimOrigin[3]; fm_GetAimOrigin(id, fAimOrigin)

	// -------------------------------------------------------------------------------------------------------------
	// Get the distance between the player and the aim origin so we can keep the entity at the same distance when moving
	// -------------------------------------------------------------------------------------------------------------
	g_fPlayerMaxEntDist[id] = get_distance_f(fPlayerOrigin, fAimOrigin)

	// -------------------------------------------------------------------------------------------------------------
	// Get the offset between the entity origin and the player aim origin to make moving more accurate
	// For example if I aimed at the edge of a brush entity, I want to move it by that edge, not the ent origin
	// -------------------------------------------------------------------------------------------------------------
	for (new i = 0; i < 3; i++) 
	{
		g_fPlayerViewMoveEntOffset[id][i] = fEntOrigin[i] - fAimOrigin[i]
	}

	// -------------------------------------------------------------------------------------------------------------
	// Render the entity a colour to signify it is being moved whilst storing the original render to revert back to
	// The same with solidity
	// -------------------------------------------------------------------------------------------------------------
	fm_TempSetSolidity(iEnt, SOLID_NOT)
	fm_TempRenderColour(iEnt, iRed, iGreen, iBlue)
}

/* fucking doors

#define OFFSET_TOGGLE_STATE 288
#define OFFSET_TOGGLE_STATE_LINUXDIFF 4

enum
{
	TS_AT_TOP,
	TS_AT_BOTTOM,
	TS_GOING_UP,
	TS_GOING_DOWN
}

new iToggleState = get_pdata_int(iEnt, OFFSET_TOGGLE_STATE, OFFSET_TOGGLE_STATE_LINUXDIFF)
if (iToggleState == TS_GOING_UP || iToggleState == TS_GOING_DOWN)
{

}
*/

public client_disconnected(id)
{
	StopMoving(id)
}

public Player_StopMove(id)
{
	StopMoving(id)
}

StopMoving(id)
{
	new iEnt = g_iPlayerMoveEnt[id]
	g_iPlayerMoveEnt[id] = 0

	if (pev_valid(iEnt))
	{
		// -------------------------------------------------------------------------------------------------------------
		// Update cached keyvalue origin so that it corresponds with the current position
		// -------------------------------------------------------------------------------------------------------------
		new Float:fVector[3]; pev(iEnt, pev_origin, fVector)	
		fm_SetCachedEntKeyVector(iEnt, "origin", fVector)

		// -------------------------------------------------------------------------------------------------------------
		// Revert back to the original render and solidity
		// -------------------------------------------------------------------------------------------------------------
		fm_RestoreSolidity(iEnt)
		fm_RestoreRendering(iEnt)

		DoorFix(iEnt)
	}
}


// -------------------------------------------------------------------------------------------------------------
// Entity moving! TODO: Add check to check the player has access, as it can change (cvar). Too lazy todo right now.
// -------------------------------------------------------------------------------------------------------------
public Forward_PreThink(id) 
{	
	static Float:fGameTime, Float:fPlayerNextEntMoveTime[MAX_PLAYERS], Float:fPlayerOrigin[3], Float:fAimOrigin[3]
	
	if (g_iPlayerMoveEnt[id] != 0)
	{
		// -------------------------------------------------------------------------------------------------------------
		// Don't allow players to move entities whilst they are dead
		// -------------------------------------------------------------------------------------------------------------
		if (!is_user_alive(id))
		{
			return FMRES_IGNORED
		}
		
		// -------------------------------------------------------------------------------------------------------------
		// Since we are in prethink, it has the potential to be called very often since it is based on client and server fps*
		// -------------------------------------------------------------------------------------------------------------
		fGameTime = get_gametime()
		if (fPlayerNextEntMoveTime[id] > fGameTime)
		{
			return FMRES_IGNORED
		}

		// -------------------------------------------------------------------------------------------------------------
		// Check the entity they are moving is valid as it may have been removed by the engine
		// -------------------------------------------------------------------------------------------------------------
		if (!pev_valid(g_iPlayerMoveEnt[id]))
		{
			g_iPlayerMoveEnt[id] = 0
			return FMRES_IGNORED
		}

		// -------------------------------------------------------------------------------------------------------------
		// Get the origin based on the players view up to a distance speficied by g_fPlayerMaxEntDist
		// This distance is set by the original distance between the player and the entity when moving is started
		// and can also be altered with the "closer" and "further" commands
		// -------------------------------------------------------------------------------------------------------------
		fm_GetAimOrigin(id, fAimOrigin, g_fPlayerMaxEntDist[id])
		
		// -------------------------------------------------------------------------------------------------------------
		// Ensure the offset between the ent origin and the aimed origin on the entity is retained for accurate moving
		// -------------------------------------------------------------------------------------------------------------
		for (new i = 0; i < 3; i++)
		{
			fAimOrigin[i] += g_fPlayerViewMoveEntOffset[id][i]
		}

		// -------------------------------------------------------------------------------------------------------------
		// Move the entity to the resultant origin
		// -------------------------------------------------------------------------------------------------------------
		fm_EntSetOrigin(g_iPlayerMoveEnt[id], fAimOrigin)

		// -------------------------------------------------------------------------------------------------------------
		// Store the distance between the entity and the aim origin as if the player aims at a wall the results of
		// fm_GetAimOrigin() will be less than g_fPlayerMaxEntDist[id] and if the player uses the "closer" or "further"
		// command I want to use the current distance as it is what the player would expect.
		// -------------------------------------------------------------------------------------------------------------
		pev(id, pev_origin, fPlayerOrigin)
		g_fPlayerEntLastDist[id] = get_distance_f(fPlayerOrigin, fAimOrigin)

		// -------------------------------------------------------------------------------------------------------------
		// * so throttle it. 30 fps max!
		// -------------------------------------------------------------------------------------------------------------
		fPlayerNextEntMoveTime[id] = fGameTime + 0.033 

	}
	return FMRES_IGNORED	
}

public Player_Further(id)
{
	if (!fm_CheckUserEntAccess(id))
	{
		return PLUGIN_HANDLED
	}

	g_fPlayerMaxEntDist[id] += 32.0
	
	// -------------------------------------------------------------------------------------------------------------
	// Set the maximum move distance for the prethink. Don't allow the object to get too far
	// -------------------------------------------------------------------------------------------------------------
	if (g_fPlayerMaxEntDist[id] > 4096.0)
	{
		g_fPlayerMaxEntDist[id] = 4096.0
	}
	return PLUGIN_HANDLED
}

public Player_Closer(id)
{
	if (!fm_CheckUserEntAccess(id))
	{
		return PLUGIN_HANDLED
	}

	// -------------------------------------------------------------------------------------------------------------
	// If the entity distance in LastDist is less than MaxDist it is because the entity the player is moving
	// has been moved closer because the trace was intercepted by another object. In which case we want to 
	// move the entity closer from the LastDist and not the MaxDist!
	// -------------------------------------------------------------------------------------------------------------
	if (g_fPlayerEntLastDist[id] < g_fPlayerMaxEntDist[id])
	{
		g_fPlayerMaxEntDist[id] = g_fPlayerEntLastDist[id] - 32.0
	}
	else
	{
		g_fPlayerMaxEntDist[id] -= 32.0
	}

	// -------------------------------------------------------------------------------------------------------------
	// Set the maximum move distance for the prethink. Don't allow the object to get too close
	// -------------------------------------------------------------------------------------------------------------
	if (g_fPlayerMaxEntDist[id] < 32.0)
	{
		g_fPlayerMaxEntDist[id] = 32.0
	}

	return PLUGIN_HANDLED
}

// -------------------------------------------------------------------------------------------------------------
// When doors are spawned into the world the origin they move to is determined. If we then move a door it gets messed up. So fix it!
// -------------------------------------------------------------------------------------------------------------

DoorFix(iEnt)
{
	new sClassName[32]; pev(iEnt, pev_classname, sClassName, charsmax(sClassName))
	if (equal(sClassName, "func_door") || equal(sClassName, "func_button"))
	{
		new Float:fAngles[3]; pev(iEnt, pev_angles, fAngles)

		// Get original spawn angle because this determines movedir
		new Float:fVector[3]; fm_GetCachedEntKeyVector(iEnt, "angles", fVector) 
		set_pev(iEnt, pev_angles, fVector)

		// Spawn to setup move origin etc
		dllfunc(DLLFunc_Spawn, iEnt)

		// Restore angle
		set_pev(iEnt, pev_angles, fAngles)

	}
}

// -------------------------------------------------------------------------------------------------------------
// Forward from FM_ENTMOD_COMMAND.amxx to let us know someone is doing something to an entity with entmod
// returning PLUGIN_HANDLED to any entities being moved will deny the action
// -------------------------------------------------------------------------------------------------------------
public fm_RunEntCommand(id, iEnt)
{
	for (new i = 1; i <= g_iMaxPlayers; i++)
	{
		if (g_iPlayerMoveEnt[i] == iEnt)
		{
			// -------------------------------------------------------------------------------------------------------------
			// Allow current player to edit the ent they are moving! This is actually a default action when running a command
			// whilst moving an entity. See FM_ENTMOD_COMMAND.amxx
			// -------------------------------------------------------------------------------------------------------------
			if (id == i)
			{
				break
			}

			new sName[MAX_NAME_LEN]; get_user_name(i, sName, charsmax(sName))
			client_print(id, print_chat, "* Entity %d is in use by \"%s\"", iEnt, sName)
			return PLUGIN_HANDLED // DENY!
		}
	}
	return PLUGIN_CONTINUE
}


public plugin_natives()
{
	register_native("fm_GetPlayerMoveEnt", "Native_GetPlayerMoveEnt")
	register_native("fm_SetPlayerMoveEnt", "Native_SetPlayerMoveEnt")
	register_native("fm_StopPlayerMoveEnt", "Native_StopPlayerMoveEnt")

	register_library("fm_entmod_move")
}

public Native_GetPlayerMoveEnt()
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

	return g_iPlayerMoveEnt[id]
}

public Native_SetPlayerMoveEnt()
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
		log_error(AMX_ERR_NATIVE, "Invalid entity (%d)", iEnt)
		return 0
	}

	StartMoving(id, iEnt, get_param(3), get_param(4), get_param(5))
	return 1
}

public Native_StopPlayerMoveEnt()
{
	new id = get_param(1)

	if (id < 1 || id > g_iMaxPlayers)
	{
		log_error(AMX_ERR_NATIVE, "Player out of range (%d)", id)
		return 0
	}

	// Don't check if they are connected since may be called on disconnect

	StopMoving(id)
	return 1
}
