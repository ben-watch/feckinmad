#include "feckinmad/fm"

#include <fakemeta>
#include <hamsandwich>

#define HUD_DISPLAY_DISTANCE 4096.0
#define RESEND_MSG_DELAY 300.0

new g_iEnt, g_iMaxPlayers
new const g_iChannel = 1

new g_iCurrentEnt[MAX_PLAYERS + 1] // Stores the entity the player is currently looking at -1 = world
new bool:g_bPlayerForceUpdate[MAX_PLAYERS + 1]  // Force a HUD update for player where usually there would be none

public fm_PluginInit()
{
	RegisterHam(Ham_TakeDamage, "func_breakable", "TakeDamagePost", 1)

	g_iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target")) 
	if (g_iEnt)
	{
		set_pev(g_iEnt, pev_nextthink, get_gametime() + 0.1)
		register_forward(FM_Think, "Forward_Think")		
	}
	else
	{
		fm_WarningLog(FM_ENT_WARNING)
	}

	g_iMaxPlayers = get_maxplayers()
}

public client_disconnect(id)
	g_iCurrentEnt[id] = -1

public Forward_Think(iEnt)
{
	if (iEnt != g_iEnt)
		return FMRES_IGNORED
						
	static Float:fPlayerOrigin[3]
	static Float:fPlayerViewOff[3]
	static Float:fVector[3]
	static iRetEnt
	static iColours[3]	
	static Float:fMsgLastSent[MAX_PLAYERS + 1]

	static Float:fHealth, Float:fMaxHealth
	static Float:fGameTime; fGameTime = get_gametime()

	for (new i = 1; i <= g_iMaxPlayers; i++)
	{
		if (!is_user_connected(i))
		{
			continue
		}
			
		// Convert view angle to normalised vector
		pev(i, pev_v_angle, fVector)
		engfunc(EngFunc_MakeVectors, fVector)
		global_get(glb_v_forward, fVector)
	
		pev(i, pev_origin, fPlayerOrigin)
		pev(i, pev_view_ofs, fPlayerViewOff)
		
		for (new j = 0; j < 3; j++)
		{
			fPlayerOrigin[j] += fPlayerViewOff[j] // Get start origin for trace
			fVector[j] = fPlayerOrigin[j] + (fVector[j] * HUD_DISPLAY_DISTANCE) // Get End position for trace. Scale up normalised vector and add to start origin
		}

		engfunc(EngFunc_TraceLine, fPlayerOrigin, fVector, IGNORE_MONSTERS, i, 0)
		iRetEnt = get_tr2(0, TR_pHit)
		
		// If the entity they are looking at has not changed since last time
		// Or we have flagged them to force a hudmessage update
		if (g_iCurrentEnt[i] != iRetEnt || fGameTime > fMsgLastSent[i] + RESEND_MSG_DELAY || g_bPlayerForceUpdate[i])
		{
			fMsgLastSent[i] = fGameTime
			g_iCurrentEnt[i] = iRetEnt
			g_bPlayerForceUpdate[i] = false

			if (iRetEnt > 0)
			{	
				static Float:fTakeDamage; pev(iRetEnt, pev_takedamage, fTakeDamage)
				if (fTakeDamage != DAMAGE_NO)
				{
					pev(iRetEnt, pev_health, fHealth)
					pev(iRetEnt, pev_max_health, fMaxHealth)

					new iPercent = floatround(fHealth/fMaxHealth * 100)
					if (iPercent < 1) 
						iPercent = 1
						
					fm_GetColourPercent(iPercent, iColours)
					set_hudmessage(iColours[0], iColours[1], iColours[2], -1.0, 0.5, 0, 0.0, RESEND_MSG_DELAY, 0.0, 0.0, g_iChannel)		
					show_hudmessage(i, "%d%%", iPercent)
	
					continue
				}
				
			}
			ClearPlayerHud(i)
		}	
	}
	set_pev(iEnt, pev_nextthink, get_gametime() + 0.1)
	return FMRES_IGNORED
}

ClearPlayerHud(id)
{
	set_hudmessage(0, 0, 0, 0.0, 0.0, 0, 0.0, 0.0, 0.0, 0.0, g_iChannel)
	show_hudmessage(id, "")	
}

public TakeDamagePost(iEnt, iInflictor, iAttacker, Float:fDamage, iDmgType)
{
	for (new i = 1; i <= g_iMaxPlayers; i++)
	{
		if (g_iCurrentEnt[i] == iEnt)
		{
			g_bPlayerForceUpdate[i] = true
		}
	}
}