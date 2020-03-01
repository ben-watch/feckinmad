#include "feckinmad/fm_global"
#include "feckinmad/fm_config"

stock const g_sConfigFile[] = "fm.cfg"
stock const g_sConfigForward[] = "fm_InitConfigExec"

public plugin_init()
{
	fm_RegisterPlugin()
}

// -------------------------------------------------------------------------------------------------------------
// Ensure the plugins that depend on fm_InitConfigExec fail if it isn't running. (reqlib in fm_config.inc)
// -------------------------------------------------------------------------------------------------------------
public plugin_natives()
{
	register_library(g_sConfigModule)
}

// -------------------------------------------------------------------------------------------------------------
// Execute fm.cfg and <mapname>.cfg on the server. plugin_cfg() is called after all plugins have run plugin_init()
// -------------------------------------------------------------------------------------------------------------
public plugin_cfg()
{
	new sConfigDir[128]; get_localinfo("amxx_configsdir", sConfigDir, charsmax(sConfigDir))
	new sCurrentMap[MAX_MAP_LEN]; get_mapname(sCurrentMap, charsmax(sCurrentMap))

	// -------------------------------------------------------------------------------------------------------------
	// Run the fm.cfg and the map specific config. Force it to do this NOW with server_exec()
	// -------------------------------------------------------------------------------------------------------------
	server_cmd("exec \"%s/%s\"", sConfigDir, g_sConfigFile)	
	server_cmd("exec \"%s/maps/cfgs/%s.cfg\"",  sConfigDir, sCurrentMap)
	server_exec() 

	// -------------------------------------------------------------------------------------------------------------
	// Let other plugins know that the config has been run so they can work based on updated cvars
	// -------------------------------------------------------------------------------------------------------------
	new iReturn, iForward = CreateMultiForward(g_sConfigForward, ET_IGNORE)
	ExecuteForward(iForward, iReturn)
	DestroyForward(iForward)

	return PLUGIN_CONTINUE
}

// -------------------------------------------------------------------------------------------------------------
// Execute fm.cfg on the player shortly after they connect for any fm specific binds / cvars they want
// -------------------------------------------------------------------------------------------------------------
public client_putinserver(id)
{
	set_task(1.0, "ExecPlayerConfig", id)
}

public ExecPlayerConfig(id)
{
	if (is_user_connected(id))
	{
		client_cmd(id, "exec \"%s\"", g_sConfigFile)
	}
}