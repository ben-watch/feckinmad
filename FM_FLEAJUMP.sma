#include "feckinmad/fm_global"

#include <fakemeta>
#include <hamsandwich>

#define PLAYER_SPEED 600
#define PLAYER_JUMP_MULTIPLIER 1250.0

new Float:g_fNextPchew[MAX_PLAYERS + 1] // The gametime a player can next do a flea jump

public plugin_init()
{
	fm_RegisterPlugin()

	server_cmd("sv_maxspeed %d", PLAYER_SPEED) // Server maxspeed must be increased for pev_maxspeed to work

	register_forward(FM_PlayerPreThink,"Forward_PreThink") // Hook prethink so we can detect when mouse2 is pressed for superjump
	register_event("CurWeapon", "Event_Weapon", "be", "1=1")	
}

public Event_Weapon(id)
{
	set_pev(id, pev_maxspeed, float(PLAYER_SPEED))
}

public Forward_PreThink(id) 
{	
	if (!is_user_alive(id))
	{
		return FMRES_IGNORED
	}

	if(pev(id, pev_button) & IN_ATTACK2) 
	{		
		// Limit rate
		static Float:fGameTime; fGameTime = get_gametime() 
		if (g_fNextPchew[id] > fGameTime) 
		{
			return FMRES_IGNORED
		}
		
		if (pev(id, pev_flags) & FL_ONGROUND)
		{
			static Float:fAngles[3]; pev(id, pev_v_angle, fAngles)

			engfunc(EngFunc_MakeVectors, fAngles) // Convert view angle to normalised vector
			global_get(glb_v_forward, fAngles) // No longer require angles so use it to hold vector instead
				
			for (new i = 0; i < 3; i++)
			{
				fAngles[i] *= PLAYER_JUMP_MULTIPLIER // Scale up vector
			}

			set_pev(id, pev_velocity, fAngles)
			g_fNextPchew[id] = fGameTime + 0.25
		}
	}
	return FMRES_IGNORED
}

public client_putinserver(id)
{
	client_cmd(id, "cl_forwardspeed %d", PLAYER_SPEED)
	client_cmd(id, "cl_backspeed %d", PLAYER_SPEED)
	client_cmd(id, "cl_sidespeed %d", PLAYER_SPEED)
}