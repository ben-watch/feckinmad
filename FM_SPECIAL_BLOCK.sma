#include "feckinmad/fm_global"

#include <fakemeta>

new g_iEnt, g_iMaxPlayers
new const Float:g_fTimerFrequency = 15.0

new Float:g_fPlayerLastSpecial[MAX_PLAYERS + 1]
new bool:g_bPlayerSpecial[MAX_PLAYERS + 1]

public plugin_init()
{
	fm_RegisterPlugin()

	CreateTimerEntity()
	g_iMaxPlayers = get_maxplayers()

	register_forward(FM_PlayerPreThink,"Forward_PlayerPreThink")
	//register_forward( FM_ClientCommand, "ClientCommand")

	register_clcmd("_special", "Player_Special")
}
 
CreateTimerEntity()
{
	g_iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	if (!g_iEnt) 
	{
		fm_WarningLog(FM_ENT_WARNING)
	}
	else
	{
		set_pev(g_iEnt, pev_nextthink, get_gametime() + g_fTimerFrequency)
		register_forward(FM_Think, "Forward_Think")	
	}	
}

public client_putinserver(id)
{
	g_fPlayerLastSpecial[id] = get_gametime()
}

public client_disconnected(id)
{
	g_bPlayerSpecial[id] = false
}

public Forward_Think(iEnt)
{
	if (iEnt != g_iEnt)
	{
		return FMRES_IGNORED
	}

	new Float:fGameTime = get_gametime()

	for (new i = 1; i <= g_iMaxPlayers; i++)
	{
		if (!is_user_connected(i) || is_user_bot(i) || g_bPlayerSpecial[i])
		{
			continue
		}

		//client_print(i, print_chat, "fGameTime %0.2f, g_fPlayerLastSpecial[i]: %0.2f", fGameTime, g_fPlayerLastSpecial[i])
		//fm_WarningLog("fGameTime %0.2f, g_fPlayerLastSpecial[%d]: %0.2f", fGameTime, i, g_fPlayerLastSpecial[i])

		if (fGameTime - g_fPlayerLastSpecial[i] >  g_fTimerFrequency * 3) 
		{
			g_bPlayerSpecial[i] = true
			client_cmd(i, ";alias _special")

			new sPlayerName[MAX_NAME_LEN]; get_user_name(i, sPlayerName, charsmax(sPlayerName))
			new sPlayerAuthid[MAX_AUTHID_LEN]; get_user_authid(i, sPlayerAuthid, charsmax(sPlayerAuthid))
			log_amx("Detected \"%s<%s>\" using _special alias", sPlayerName, sPlayerAuthid)
		}
		else
		{
			client_cmd(i, "_special ping")
		}		
	}

	set_pev(g_iEnt, pev_nextthink, fGameTime + g_fTimerFrequency)
	return FMRES_IGNORED
}

public Player_Special(id)
{
	//fm_WarningLog("%d used _special. fGameTime: %0.2f", id, get_gametime())
	g_fPlayerLastSpecial[id] = get_gametime()

	new sArg[8]; read_argv(1, sArg, charsmax(sArg))
	if (equal(sArg, "ping"))
	{
		return PLUGIN_HANDLED
	}
	return PLUGIN_CONTINUE
}

/*
public ClientCommand(id)
{
	new sCommand[9]; read_argv(0, sCommand, charsmax(sCommand))
	if (equal(sCommand, "_special"))
	{
		//fm_WarningLog("%d used _special. fGameTime: %0.2f", id, get_gametime())
		g_fPlayerLastSpecial[id] = get_gametime()
		return PLUGIN_HANDLED // Don't continue with _special. TODO: Is special a default bind? Should we exec the special class function
	}
	return PLUGIN_CONTINUE
}
*/

public Forward_PlayerPreThink(id)
{
	if(!g_bPlayerSpecial[id] || !is_user_alive(id))
	{
		return FMRES_IGNORED
	}

	// When the player presses the jump key send the client command to alias _special to prevent bhop scripts
	if((pev(id, pev_button) & IN_JUMP) && !(pev(id, pev_oldbuttons) & IN_JUMP))
	{
		client_cmd(id, ";alias _special")		
	}

	return FMRES_IGNORED
}
		






