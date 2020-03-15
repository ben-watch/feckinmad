#include "feckinmad/fm_global"
#include "feckinmad/fm_admin_access"

public plugin_init()
{
	fm_RegisterPlugin()
	register_concmd("admin_help", "Admin_Help")
}

public Admin_Help(id, iLevel, iCommand)
{
	if (!id)
	{
		return PLUGIN_HANDLED // Ignore rcon. (Making this a clcmd means I cannot run the command on a local server)
	}

	new iPlayerAccess = fm_GetUserAccess(id)
	new iCommandNum = get_concmdsnum(iPlayerAccess, id)

	if (!iCommandNum)
	{
		console_print(id, "You don't have access to any commands")
		return PLUGIN_HANDLED
	}

	new sArgs[8]; read_args(sArgs, charsmax(sArgs))
	new iStart = str_to_num(sArgs) - 1

	if (iStart < 0)
	{
		iStart = 0
	}

	if (iStart >= iCommandNum)
	{
		iStart = iCommandNum - 1
	}

	new iEnd = iStart + 10
	if (iEnd > iCommandNum)
	{
		iEnd = iCommandNum
	}

	console_print(id, "\nAvailiable Commands:")
	
	new sCommand[32], sInfo[128], iFlag
	for (new i = iStart; i < iEnd; i++)
	{
		get_concmd(i, sCommand, charsmax(sCommand), iFlag, sInfo, charsmax(sInfo), iPlayerAccess, id)
		console_print(id, "\t#%d %s %s", i + 1, sCommand, sInfo)
	}

	if (iEnd < iCommandNum)
	{
		console_print(id, "Displaying commands %d to %d. Type \"admin_help %d\" for more\n", iStart + 1, iEnd, iEnd + 1)
	}

	return PLUGIN_HANDLED
}