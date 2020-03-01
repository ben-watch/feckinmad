#include "feckinmad/fm_global"
#include "feckinmad/fm_admin_access"

public plugin_init() 
{ 
	fm_RegisterPlugin()
	register_concmd("admin_command","Admin_Command", ADMIN_MEMBER)
}

public Admin_Command(id, iLevel, iCommand)
{	
	if (!fm_CommandAccess(id, iLevel, false))
	{
		return PLUGIN_HANDLED
	}

	new sArgs[192]; read_args(sArgs, charsmax(sArgs))
	remove_quotes(sArgs)

	if (sArgs[0])
	{
		client_cmd(id, sArgs)
	}

	return PLUGIN_HANDLED
}
