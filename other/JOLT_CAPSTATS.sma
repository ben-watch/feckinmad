#include <amxmodx>
#include <fakemeta>

#define PLUGIN "Jolt_DustCapStats"
#define VERSION "2.0"
#define AUTHOR "watch"

#define GATES_CLOSED 0
#define GATES_OPEN 1

new g_iCapNum
new g_iCapTime[4]
new g_iGateStatus

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	register_message(get_user_msgid("HudText"), "Flag_Capped")
}

public Flag_Capped(id, iDest, iEnt) // iEnt = Player who message is sent to
{
	static sBuffer[32]
	get_msg_arg_string(1, sBuffer, 31)
	
	if (equal(sBuffer, "#dustbowl_gates_open"))
	{
		if (g_iGateStatus == GATES_CLOSED) // Message is called multiple times, due to being sent to everyone on server. We only need it once		
			g_iCapTime[g_iCapNum] = floatround(get_gametime()) // Time taken is from when the gates open
	}
	// When a player gets sent the cap message (Note: Last one is ripented into map)
	else if (equal(sBuffer, "#dustbowl_you_secure_one") || equal(sBuffer, "#dustbowl_you_secure_two") || equal(sBuffer, "You secured", 11))
	{
		get_user_name(iEnt, sBuffer, 31)

		new sMsg[256], sClass[12]
		switch(pev(iEnt, pev_playerclass))
		{
			case 1: copy(sClass, 11, "Scout")
			case 2: copy(sClass, 11, "Sniper")
			case 3: copy(sClass, 11, "Soldier")
			case 4: copy(sClass, 11, "Demoman")
			case 5: copy(sClass, 11, "Medic")
			case 6: copy(sClass, 11, "HWGuy")
			case 7: copy(sClass, 11, "Pyro")
			case 8: copy(sClass, 11, "Spy")
			case 9: copy(sClass, 11, "Engineer")
		}

		new iSecs = floatround(get_gametime()) - g_iCapTime[g_iCapNum] // Seconds between the cap and the gates openning
		g_iCapNum++		

		
		if (iSecs > 60)
		{
			new iMins = iSecs / 60
			iSecs %= 60
			formatex(sMsg, 255, "%s secures CP %d as %s^nTime taken: %dm %ds Health: %d Armour: %d", sBuffer, g_iCapNum, sClass, iMins, iSecs, get_user_health(iEnt), get_user_armor(iEnt))
		}
		else
			formatex(sMsg, 255, "%s secures CP %d as %s^nTime taken: %ds Health: %d Armour: %d", sBuffer, g_iCapNum, sClass, iSecs, get_user_health(iEnt), get_user_armor(iEnt))

		set_hudmessage(200, 200, 255, -1.0, 0.9, 2, 0.5, 10.0, 0.01, 0.05, 4)
		show_hudmessage(0, sMsg)
		console_print(0, sMsg)

		if (g_iGateStatus == GATES_OPEN)
			g_iGateStatus = GATES_CLOSED
	}
}

