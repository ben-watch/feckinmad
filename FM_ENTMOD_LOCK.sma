#include "feckinmad/fm_global"

#include "feckinmad/entmod/fm_entmod_base"
#include "feckinmad/entmod/fm_entmod_command"
#include "feckinmad/entmod/fm_entmod_access" // fm_CheckUserEntAccess()

stock const g_sLockKey[] = "fm_entmod_lock"

new g_iPlayerLockIdent[MAX_PLAYERS + 1]
new g_iCurrentIdent = 1
new g_iMaxPlayers

public plugin_init()
{
	fm_RegisterPlugin()

	g_iMaxPlayers = get_maxplayers()
	register_clcmd("fm_ent_locktoggle", "Player_LockToggle")
}

public Player_LockToggle(id)
{
	if (!fm_CheckUserEntAccess(id))
	{
		return PLUGIN_HANDLED
	}

	new sArg[8]; read_argv(1, sArg, charsmax(sArg))
	new iEnt = fm_CommandGetEntity(id, sArg)
	if (!iEnt || !fm_CommandCheckEntity(id, iEnt, ENTCMD_MODIFY))
	{
		return PLUGIN_HANDLED
	}

	new sValue[8]
	if (fm_GetCachedEntKey(iEnt, g_sLockKey, sValue, charsmax(sValue)) != -1)
	{
		new iPlayer = GetLockUserByIdent(str_to_num(sValue))
		if (iPlayer != -1)
		{
			if (iPlayer != id)
			{
				new sName[MAX_NAME_LEN]; get_user_name(iPlayer, sName, charsmax(sName))
				client_print(id, print_chat, "* This entity has been locked by \"%s\"", sName)	
			}
			else
			{
				fm_RemoveCachedEntKey(iEnt, g_sLockKey)
				client_print(id, print_chat, "You have unlocked entity #%d", iEnt)
			}
			return PLUGIN_HANDLED
		}
	}

	fm_SetCachedEntKeyInt(iEnt, g_sLockKey, g_iPlayerLockIdent[id])
	client_print(id, print_chat, "You have locked entity #%d", iEnt)
	
	return PLUGIN_HANDLED	

}

// Rather than check every entity in the map, assign each player a unique identifier on connect
public client_putinserver(id)
{
	g_iPlayerLockIdent[id] = g_iCurrentIdent++
}

public fm_RunEntCommand(id, iEnt, iMode)
{
	new sValue[8]
	if (fm_GetCachedEntKey(iEnt, g_sLockKey, sValue, charsmax(sValue)) != -1)
	{
		new iPlayer = GetLockUserByIdent(str_to_num(sValue))
		if (iPlayer != -1 && iPlayer != id)
		{
			new sName[MAX_NAME_LEN]; get_user_name(iPlayer, sName, charsmax(sName))
			client_print(id, print_chat, "* This entity has been locked by \"%s\"", sName)
			return PLUGIN_HANDLED
		}
	}
	return PLUGIN_CONTINUE
}

GetLockUserByIdent(iIdent)
{
	for (new i = 1; i <= g_iMaxPlayers; i++)
	{
		if (iIdent == g_iPlayerLockIdent[i])
		{
			return i
		}
	}
	return -1
}

