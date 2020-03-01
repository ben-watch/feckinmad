#include "feckinmad/fm_global"
#include "feckinmad/fm_admin_access"
#include "feckinmad/fm_mapfunc" // fm_IsMapNameInFile

new const g_sBalanceFile[] = "fm_balance.ini"
#define VGUI_TEAM_SELECT 2

new bool:g_bBalanceEnabled

public plugin_init()
{
	fm_RegisterPlugin()

	new sFile[128]; fm_BuildAMXFilePath(g_sBalanceFile, sFile, charsmax(sFile), "amxx_configsdir")
	new sCurrentMap[MAX_MAP_LEN]; get_mapname(sCurrentMap, charsmax(sCurrentMap))
	g_bBalanceEnabled = fm_IsMapNameInFile(sCurrentMap, sFile) ? true : false

	register_clcmd("jointeam", "Handle_Jointeam")
	register_concmd("admin_balance", "Admin_Balance", ADMIN_MEMBER)
}

public Admin_Balance(id, iLevel, iCommand)
{
	if (!fm_CommandAccess(id, iLevel, false))
		return PLUGIN_HANDLED
	
	g_bBalanceEnabled = g_bBalanceEnabled ? false : true
	
	new sArgs[8]; read_args(sArgs, charsmax(sArgs))
	if (g_bBalanceEnabled && str_to_num(sArgs) == 1)
	{
		new sFile[128]; fm_BuildAMXFilePath(g_sBalanceFile, sFile, charsmax(sFile), "amxx_configsdir")
		new sCurrentMap[MAX_MAP_LEN]; get_mapname(sCurrentMap, charsmax(sCurrentMap))
		if (!fm_IsMapNameInFile(sCurrentMap, sFile))
		{
			new iFileHandle = fopen(sFile, "at")
			if (iFileHandle)
			{
				fprintf(iFileHandle, "\n%s", sCurrentMap)
				fclose (iFileHandle)
			}
		}
	}

	new sAdminName[MAX_NAME_LEN]; get_user_name(id, sAdminName, charsmax(sAdminName))
	new sAdminAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAdminAuthid, charsmax(sAdminAuthid))
	new sAdminRealName[MAX_NAME_LEN]; fm_GetUserRealname(id, sAdminRealName, charsmax(sAdminRealName))

	client_print(0, print_chat, "* ADMIN #%d %s: %s team balancing", fm_GetUserIdent(id), sAdminRealName, g_bBalanceEnabled ? "enabled" : "disabled")
	log_amx("\"%s<%s>(%s)\" admin_balance \"%s\"", sAdminName, sAdminAuthid, sAdminRealName, g_bBalanceEnabled ? "enabled" : "disabled")

	return PLUGIN_HANDLED
}


public Handle_Jointeam(id)
{
	if (!g_bBalanceEnabled)
		return PLUGIN_CONTINUE

	new sArgs[2]; read_args(sArgs, charsmax(sArgs))
	new iTeam = str_to_num(sArgs)

	if (iTeam < 0 || iTeam > 4)
		return PLUGIN_CONTINUE

	client_print(id, print_center, "Team balancing is enabled\nYou may only select AUTO ASSIGN")
	set_task(1.0, "Show_TeamVGUI", id) // Show VGIU after they have had a chance to read message above

	return PLUGIN_HANDLED
}

public Show_TeamVGUI(id)
{
	if (!is_user_connected(id))
		return PLUGIN_CONTINUE

	message_begin(MSG_ONE, get_user_msgid("VGUIMenu"), {0, 0, 0} , id)
	write_byte(VGUI_TEAM_SELECT)
	message_end()

	return PLUGIN_CONTINUE
}


