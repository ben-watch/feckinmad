#if defined _fm_admin_access_included
  #endinput
#endif
#define _fm_admin_access_included

#pragma reqlib "fm_admin_access"

stock const g_sAdminAccessLibName[] = "fm_admin_access"

#define ADMIN_LIST (1<<2)
#define ADMIN_MEMBER (1<<8)
#define ADMIN_HIGHER (1<<19)

native fm_GetUserRealname(id, sName[], iLen)
native fm_GetUserAccess(id)
native fm_GetUserIdent(id)

stock fm_CommandAccess(id, iLevel, bool:bAllowRcon)
{
	// Always have access if not dedicated server
	if (!is_dedicated_server())
	{
		return 1
	}

	// Check if the server console is allowed to run this command (rcon)
	// else check the user has the access level required to run the command
	if (!id)
	{
		if (!bAllowRcon)
		{
			console_print(id, "You cannot run that command via the server console")
			return 0
		}
	}
	else if (!(fm_GetUserAccess(id) & iLevel))
	{
		console_print(id, "You don't have access to that command")
		return 0
	}

	return 1
}
