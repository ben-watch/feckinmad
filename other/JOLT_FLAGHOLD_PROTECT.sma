//#define DEBUG

#include <amxmodx>
#include <fakemeta>

#define PLUGIN "Jolt_FlagHold"
#define VERSION "2.0"
#define AUTHOR "watch"

#define FLAG_MESSAGE "Server has detected you as a flag holder! Please attack with the flag. You will be punished if you still have it in %d seconds"

#define GATES_CLOSED 0
#define GATES_OPEN 1

new g_iFlagHoldHandleEnt
new g_iPlayerFlagHolder
new g_iFlagWarningCount
new g_iFlagWarningTime
new g_iGateStatus
new g_sLogFile[64]

FlagHold_Message(str[], {Float,Sql,Result,_}:...)
{
	static sBuffer[128]
	vformat(sBuffer, 127, str, 2)
	
	static bool:g_bToggleHud
	
	if (g_bToggleHud)
	{
		set_hudmessage(255, 0, 0, -1.0, 0.7, 2, 0.5, 60.0, 0.0, 0.0, 2) // map uses channel 3
		g_bToggleHud = false
	}
	else
	{
		set_hudmessage(255, 255, 255, -1.0, 0.7, 2, 0.5, 60.0, 0.0, 0.0, 2)
		g_bToggleHud = true
	}

	show_hudmessage(g_iPlayerFlagHolder, sBuffer)
}

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_cvar("jolt_flagwarning", "60")
	register_cvar("jolt_flagpunish", "90")
	
	g_iFlagWarningCount = get_cvar_num("jolt_flagpunish") - get_cvar_num("jolt_flagwarning")
	g_iFlagWarningTime = g_iFlagWarningCount
	
	register_message(get_user_msgid("HudText"), "Handle_Message")
	register_message(get_user_msgid("TextMsg"), "Gates_Closed")	
	
	g_iFlagHoldHandleEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	register_forward(FM_Think, "Forward_Think")
	
	register_event("DeathMsg", "Event_Death", "a")
	
	get_time("Flagholding_%m.log", g_sLogFile, 63)	
}

public Handle_Message(id, iDest, iEnt)
{
	static sBuffer[32]
	get_msg_arg_string(1, sBuffer, 31)

	if (g_iGateStatus == GATES_CLOSED) // Message is sent multiple times, per player, we only need it once.
	{
		if (equal(sBuffer, "#dustbowl_gates_open"))
		{
			#if defined DEBUG
			client_print(0, print_chat, "[%s] Gates are now open", PLUGIN)
			#endif
				
			g_iGateStatus = GATES_OPEN
			
			if (g_iPlayerFlagHolder > 0)
			{
				#if defined DEBUG
				client_print(0, print_chat, "Started think as flag is held when gates opened")
				#endif
					
				set_pev(g_iFlagHoldHandleEnt, pev_nextthink, get_gametime() + get_cvar_num("jolt_flagwarning"))
			}
		}
	}
	
	// flag picked up
	if (equal(sBuffer, "#dustbowl_take_flag_one") || equal(sBuffer, "#dustbowl_take_flag_two") || equal(sBuffer, "#dustbowl_take_flag_HQ"))
	{
		#if defined DEBUG
		client_print(0, print_chat, "Flag picked up by %d. Gates are %s", iEnt, g_iGateStatus? "Open" : "Closed")
		#endif
	
		g_iPlayerFlagHolder = iEnt
		
		if (g_iGateStatus == GATES_OPEN)
		{
			#if defined DEBUG
			client_print(0, print_chat, "Started timer beause gates are open")
			#endif	
			
			set_pev(g_iFlagHoldHandleEnt, pev_nextthink, get_gametime() + get_cvar_num("jolt_flagwarning"))	
		}
	}
}

public Gates_Closed(id, dest, ent)
{
	static sBuffer[32]
	
	if (g_iGateStatus == GATES_OPEN)
	{
		get_msg_arg_string(2, sBuffer, 31)
	
		if (equal(sBuffer, "#dustbowl_blue_secures_one") || equal(sBuffer, "#dustbowl_blue_secures_two") || equal(sBuffer, "#dustbowl_blue_caps") )
		{
			g_iGateStatus = GATES_CLOSED
					
			Reset_Flag()
			
			#if defined DEBUG
			client_print(0, print_chat, "Gates are now closed")
			#endif
			
		}
	}
}

public Forward_Think(iEnt)
{
	if (iEnt != g_iFlagHoldHandleEnt)
		return FMRES_IGNORED
		
	new sName[32], sAuthid[32] 
	
	get_user_name(g_iPlayerFlagHolder, sName ,31)
	get_user_authid(g_iPlayerFlagHolder, sAuthid, 31)
	
	if (g_iFlagWarningCount <= 0) // Count has finished and they still have the flag, slay.
	{		
		log_to_file(g_sLogFile, "%s<%s> - Slayed for flag holding", sName, sAuthid)
		console_print(g_iPlayerFlagHolder, "Automatically killed for flag holding")
		user_kill(g_iPlayerFlagHolder)
	} 
	else 
	{
		FlagHold_Message(FLAG_MESSAGE, g_iFlagWarningCount)
		
		set_pev(iEnt, pev_nextthink, get_gametime() + 1.0)
		
		if (g_iFlagWarningCount == g_iFlagWarningTime)			
			log_to_file(g_sLogFile, "%s<%s> - Warned for flag holding", sName, sAuthid)
		
		g_iFlagWarningCount--
	}
	return FMRES_IGNORED
}

public client_disconnect(id)
{
	if (id != g_iPlayerFlagHolder)
		return PLUGIN_CONTINUE

	#if defined DEBUG
	client_print(0, print_chat, "Player left! Resetting flag")
	#endif
		
	Reset_Flag()
	return PLUGIN_CONTINUE
}

public Event_Death()
{
	new id = read_data(2)
	
	if (id != g_iPlayerFlagHolder)
		return PLUGIN_CONTINUE

	#if defined DEBUG
	client_print(0, print_chat, "Flag dropped by %d. Gates: %s", id, g_iGateStatus? "Open" : "Closed")
	#endif	

	Reset_Flag()
		
	set_hudmessage(255, 0, 0, -1.0, 0.7, 2, 0.5, 60.0, 0.0, 0.0, 2) // map uses channel 3
	show_hudmessage(id, "")
	return PLUGIN_CONTINUE
}

Reset_Flag()
{
	set_pev(g_iFlagHoldHandleEnt, pev_nextthink, 0.0)
	
	g_iFlagWarningCount = g_iFlagWarningTime
	g_iPlayerFlagHolder = 0

	#if defined DEBUG
	client_print(0, print_chat, "Reset Flag")
	#endif	
}