#include <amxmodx>
#include <fakemeta>

#define PLUGIN "Jolt_GateImmunity"
#define VERSION "2.0"
#define AUTHOR "watch"

#define GATES_CLOSED 0
#define GATES_OPEN 1
#define SPEAK_MUTED 0

new g_iGateStatus
new g_iVoiceForward
new g_iAllTalk
new g_iDetectEnt

stock set_keyvalue(entity, const key[], const value[], const classname[] = "")
{
	if (classname[0])
		set_kvd(0, KV_ClassName, classname)
	else {
		new class[32]
		pev(entity, pev_classname, class, 31)
		set_kvd(0, KV_ClassName, class)
	}

	set_kvd(0, KV_KeyName, key)
	set_kvd(0, KV_Value, value)
	set_kvd(0, KV_fHandled, 0)

	return dllfunc(DLLFunc_KeyValue, entity, 0)
}

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	// Setting the teams to allied will fuck up say_team and voice so we hook it and fix it!
	register_clcmd("say_team", "Handle_Say")
	g_iVoiceForward = register_forward(FM_Voice_SetClientListening, "Forward_SetListen")
	g_iAllTalk = register_cvar("sv_alltalk", "0")
	
	register_message(get_user_msgid("HudText"), "Gates_Open")

	g_iDetectEnt = engfunc(EngFunc_FindEntityByString, 0, "classname", "info_tfdetect")
	if (!g_iDetectEnt)
		return PLUGIN_CONTINUE
			
	set_keyvalue(g_iDetectEnt, "team1_allies", "2")
	set_keyvalue(g_iDetectEnt, "team2_allies", "1")
	
	return PLUGIN_CONTINUE
}

public Forward_SetListen(iReceiver, iSender, iListen)
{
	if (get_pcvar_num(g_iAllTalk))
		return FMRES_IGNORED

	if (pev(iReceiver, pev_team) != pev(iSender, pev_team))
	{
		engfunc(EngFunc_SetClientListening, iReceiver, iSender, SPEAK_MUTED)
		return FMRES_SUPERCEDE
	}
	
	return FMRES_IGNORED
}

public Handle_Say(id) // Because we ally the teams we have to catch say_team and send it manually
{
	if (g_iGateStatus != GATES_CLOSED)
		return PLUGIN_CONTINUE
		
	static sArgs[192]
	static iTeam
	
	iTeam = pev(id, pev_team)
	
	read_args(sArgs, 191)
	remove_quotes(sArgs)
	
	if (!sArgs[0])
		return PLUGIN_HANDLED
		
	static iHealth[4], iArmor[4]
		
	formatex(iHealth, 3, "%d", pev(id, pev_health))
	formatex(iArmor, 3, "%d", pev(id, pev_armorvalue))
		
	replace(sArgs, 191, "%h", iHealth)
	replace(sArgs, 191, "%a", iArmor)
		
	static sName[32]
	get_user_name(id, sName, 31)
	format(sArgs, 191, "(TEAM) %s: %s^n", sName, sArgs)

	new iPlayers[32], iNum, player
	get_players(iPlayers, iNum)
	for (new i = 0; i < iNum; i++)
	{
		player = iPlayers[i]
		
		if (!is_user_connected(player))
			continue
	
		if(pev(player, pev_team) == iTeam)
		{
			message_begin(MSG_ONE, get_user_msgid("SayText"), {0,0,0}, player)
			write_byte(player)
			write_string(sArgs)
			message_end
		}
	}
	return PLUGIN_HANDLED
}	


/* Ally the teams when the gates are down. This fixes: 
 - Defence spamming nades in their own spawn when Offence cap
 - Throwing nades over the gates
 - Damage before the gates go up */
 
public Gates_Open()
{
	static sBuffer[32]
	get_msg_arg_string(1, sBuffer, 31)

	if (equal(sBuffer, "#dustbowl_gates_open"))
	{
		// message is sent multiple times (for each player) we only need it once
		if (g_iGateStatus != GATES_CLOSED)
			return PLUGIN_CONTINUE

		g_iGateStatus = GATES_OPEN
			
		set_keyvalue(g_iDetectEnt, "team1_allies", "0")
		set_keyvalue(g_iDetectEnt, "team2_allies", "0")
		
		unregister_forward(FM_Voice_SetClientListening, g_iVoiceForward)
		
	}
	else if (equal(sBuffer, "#dustbowl_90_secs"))
	{
		if (g_iGateStatus != GATES_OPEN)
			return PLUGIN_CONTINUE

		g_iGateStatus = GATES_CLOSED
				
		set_keyvalue(g_iDetectEnt, "team1_allies", "2")
		set_keyvalue(g_iDetectEnt, "team2_allies", "1")
		
		g_iVoiceForward = register_forward(FM_Voice_SetClientListening, "Forward_SetListen")
	}
	return PLUGIN_CONTINUE
}

/*
// This fixes demomen making megalag by inserting pipes into the gate
public touch_hook(ent, touched)
{
	if (!pev_valid(ent))
		return FMRES_IGNORED
		
	pev(ent, pev_classname,  g_buffer, 31)
	if (equal(g_buffer, "tf_gl_pipebomb") || equal(g_buffer, "tf_gl_grenade"))
	{				
		
		new Float:velocity[3]
		pev(ent, pev_velocity, velocity)
		//client_print(0, print_chat, "pipe %f %f %f", velocity[0], velocity[1], velocity[2])
		if (velocity[0] == 0.0 && velocity[1] == 0.0)
		{
			if (velocity[2] < 0.0)
			{
				pev(touched, pev_classname,  g_buffer, 31)
				
				if (equal(g_buffer, "func_door")) //|| equal(g_buffer, "func_wall_toggle")) // this fucked up the ripent thing
					set_pev(ent, pev_nextthink, 0.1)
				else
					set_pev(ent, pev_movetype, 0)
			}
		}
	}
	return FMRES_IGNORED
}
*/

