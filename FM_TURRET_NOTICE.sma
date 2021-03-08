#include "feckinmad/fm_global"
#include <fakemeta>
#include <orpheu>

new OrpheuHook:HookTurretPing // g_iEmitSoundForward
new Float:g_fNextHudMessage

public plugin_init()
{
	fm_RegisterPlugin()
}

public plugin_precache()
{
	register_forward(FM_Spawn, "Forward_Spawn_Post", 1)
}

public Forward_Spawn_Post(iEnt)
{
	if (pev_valid(iEnt))
	{
		static sClassName[32]; pev(iEnt, pev_classname, sClassName, charsmax(sClassName))
		if (equal(sClassName, "monster_turret") || equal(sClassName, "monster_miniturret"))
		{
			// Set the m_flMaxWait time for the sentry so they don't stay searching for so long.	
			set_ent_data_float(iEnt, "CBaseTurret", "m_flMaxWait", 7.0)

			// Register the Emitsound Hook if a turret exists on the map
			if (!HookTurretPing) // !g_iEmitSoundForward
			{
				HookTurretPing = OrpheuRegisterHook(OrpheuGetFunction("Ping", "CBaseTurret"), "OnTurretPing") // g_iEmitSoundForward = register_forward(FM_EmitSound, "Forward_EmitSound")
			}
		}
	}
}

public OrpheuHookReturn:OnTurretPing() //public Forward_EmitSound(iEnt, iChannel, sSound[]) {  if (equal(sSound, "turret/tu_ping.wav")) { [...]
{
	fm_DebugPrintLevel(1, "OnTurretPing()")

	// Throttle the display of the hudmessage incase of multiple turrets
	static Float:fGameTime; fGameTime = get_gametime()
	if (!g_fNextHudMessage || g_fNextHudMessage < fGameTime)
	{
		set_hudmessage(255, 0, 0, -1.0, 0.8, 0, 0.0, 0.5, 0.0, 0.0, 4)
		show_hudmessage(0, "TURRET SEARCHING FOR TARGET\n* STAY DOWN *")
		g_fNextHudMessage = fGameTime + 1.0
	}
}