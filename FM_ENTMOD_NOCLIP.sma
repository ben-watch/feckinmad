#include "feckinmad/fm_global"
#include "feckinmad/entmod/fm_entmod_access" // fm_CheckUserEntAccess()

#include <fakemeta>

public  plugin_init()
{
	fm_RegisterPlugin()

	register_clcmd("+fm_ent_noclip", "Player_StartNoclip")
	register_clcmd("-fm_ent_noclip", "Player_StopNoclip")
	register_clcmd("fm_ent_noclip", "Player_ToggleNoclip")
}

public Player_StartNoclip(id)
{
	if (fm_CheckUserEntAccess(id) && is_user_alive(id))
	{
		set_pev(id, pev_movetype, MOVETYPE_NOCLIP)
	}
}

public Player_StopNoclip(id)
{
	if (pev(id, pev_movetype) == MOVETYPE_NOCLIP  && is_user_alive(id))
	{	
		set_pev(id, pev_movetype, MOVETYPE_WALK)
	}
}

public Player_ToggleNoclip(id)
{
	if (is_user_alive(id))
	{
		if (pev(id, pev_movetype) == MOVETYPE_NOCLIP)
		{
			set_pev(id, pev_movetype, MOVETYPE_WALK) 
		}
		else if (fm_CheckUserEntAccess(id))
		{
			set_pev(id, pev_movetype, MOVETYPE_NOCLIP)
		}
	}
}