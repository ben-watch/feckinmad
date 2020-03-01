#include "feckinmad/fm_global"
#include "feckinmad/fm_admin_access"
#include "feckinmad/fm_mapfunc"

#include <fakemeta>
#include <hamsandwich>

new g_iMaxEnts, g_iMaxPlayers
new g_iThinkForward, g_iEnt

new const g_sSemiMapsFile[] = "fm_semiclip_maps.ini"

public plugin_init()
{
	fm_RegisterPlugin()

	g_iMaxEnts = global_get(glb_maxEntities)
	g_iMaxPlayers = get_maxplayers()
		
	register_concmd("admin_semiclip", "Admin_SemiClip", ADMIN_HIGHER)

	new sFile[128]; fm_BuildAMXFilePath(g_sSemiMapsFile, sFile, charsmax(sFile), "amxx_configsdir")
	new sCurrentMap[MAX_MAP_LEN]; get_mapname(sCurrentMap, charsmax(sCurrentMap))

	if (fm_IsMapNameInFile(sCurrentMap, sFile) == 1)
	{
		CreateSemiClipThinkEntity()
	}
}

CreateSemiClipThinkEntity()
{
	g_iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target")) 
	if (!g_iEnt)
	{
		fm_WarningLog(FM_ENT_WARNING)
		return 0
	}
	
	if (!g_iThinkForward)
	{
		g_iThinkForward = register_forward(FM_Think, "Forward_Think")
	}

	set_pev(g_iEnt, pev_nextthink, get_gametime() + 0.025)	
	return 1	
}

RemoveSemiClipThinkEntity()
{
	if (pev_valid(g_iEnt))
	{
		engfunc(EngFunc_RemoveEntity, g_iEnt)
		g_iEnt = 0
	}

	if (g_iThinkForward)
	{
		unregister_forward(FM_StartFrame, g_iThinkForward)
		g_iThinkForward = 0
	}
}
 
public Admin_SemiClip(id, iLevel, iCommand)
{
	if (!fm_CommandAccess(id, iLevel, false))
	{
		return PLUGIN_HANDLED
	}
	
	if (!g_iEnt)
	{
		CreateSemiClipThinkEntity()
	}
	else
	{
		RemoveSemiClipThinkEntity() 

		for (new i = 1; i <= g_iMaxPlayers; i++)
		{
			if (is_user_connected(i) && is_user_alive(i))
			{
				set_pev(i, pev_solid, SOLID_BBOX)
			}
		}
	}	
	
	console_print(id, "You have %s semiclip", g_iEnt ? "enabled" : "disabled")
	
	return PLUGIN_HANDLED
}


public Forward_Think(iEnt)
{
	if (iEnt != g_iEnt)
	{
		return FMRES_IGNORED
	} 

	static Float:fEntMaxs[3], Float:fEntMins[3]
	static Float:fPlayerMaxs[3], Float:fPlayerMins[3]
	static Float:fPlayerOrigin[3], Float:fOtherPlayerOrigin[3]
	static bool:bPlayerSemiClipped[MAX_PLAYERS + 1] 

	// Loop through every player on the server
	for (new i = 1; i <= g_iMaxPlayers; i++)
	{
		// Check they are connected and alive
		if (!is_user_connected(i) || !is_user_alive(i))
			continue

		bPlayerSemiClipped[i] = false

		// Loop through every player on the server
		for (new j = 1; j <= g_iMaxPlayers; j++)
		{
			// Make sure they are a different player that is both connected and alive
			if (i == j || !is_user_connected(j) || !is_user_alive(j))
				continue
			
			// Check the distance between the 2 players origins
			pev(i, pev_origin, fPlayerOrigin); pev(j, pev_origin, fOtherPlayerOrigin)
			if (vector_distance(fPlayerOrigin, fOtherPlayerOrigin) < 200)
			{
				bPlayerSemiClipped[i] = true
				break
			}
		}

		if (bPlayerSemiClipped[i])
		{
			set_pev(i, pev_solid, SOLID_NOT)

			pev(i, pev_absmax, fPlayerMaxs); pev(i, pev_absmin, fPlayerMins)

			// Loop through every entitiy in the map
			for (new j = g_iMaxPlayers + 1; j < g_iMaxEnts; j++)
			{
				// Ignore ents that the player wouldn't beable to touch normally
				if (!pev_valid(j) || pev(j, pev_solid) == SOLID_NOT)
					continue
				
				// Check if the player would normally touch the entity. EDIT GRRR I_T_G.. +1.0 -1.0
				pev(j, pev_maxs, fEntMaxs) //pev(j, pev_absmax, fEntMaxs)
				pev(j, pev_mins, fEntMins) //pev(j, pev_absmin, fEntMins)

				if (fPlayerMins[0] > fEntMaxs[0] ||
				    fPlayerMins[1] > fEntMaxs[1] ||
				    fPlayerMins[2] > fEntMaxs[2] ||
				    fPlayerMaxs[0] < fEntMins[0] ||
				    fPlayerMaxs[1] < fEntMins[1] ||
				    fPlayerMaxs[2] < fEntMins[2])
					continue

				// Don't allow projectiles to hit their owners
				// Would this effect anything else? Or is this similar to the way the HL engine does the touch... ahhhh
				if (pev(j, pev_owner) != i)
				{
					ExecuteHam(Ham_Touch, j, i)
				}
				
				// Check the entity hasn't been deleted by the touch above
				if (pev_valid(j))
				{
					ExecuteHam(Ham_Touch, i, j)
				}
			}
		}
		else
			set_pev(i, pev_solid, SOLID_BBOX)
	}
	set_pev(g_iEnt, pev_nextthink, get_gametime() + 0.025)

	return FMRES_IGNORED
}



// i_t_g brush triggers seem to be spawned as info_tfgoals, but their absmin and absmax are weridly huge e.g.
// #30 info_tfgoal: { 3778.000000 3778.000000 3778.000000 } { -3778.000000 -3778.000000 -3778.000000 }
// A fairly reliable way to filter the tfgoal trigger brush from a point is to check pev_effects and set the absmin from absmax
// It will pick up some point ents, but it doesn't matter because the end result is the same
/*ITGHack()
{
	new iEnt, Float:fEntMaxs[3], Float:fEntMins[3]
	while ((iEnt = engfunc(EngFunc_FindEntityByString, iEnt, "classname", "info_tfgoal")) > 0)
	{	
		if (pev(iEnt, pev_effects) & EF_NODRAW)
		{
			pev(iEnt, pev_maxs, fEntMaxs); pev(iEnt, pev_mins, fEntMins)

			for (new i = 0; i < 3; i++)
			{
				fEntMaxs[i] += 1.0
				fEntMins[i] -= 1.0
			}

			engfunc(EngFunc_SetSize, iEnt, fEntMins, fEntMaxs)
		}		
	}
}
*/


