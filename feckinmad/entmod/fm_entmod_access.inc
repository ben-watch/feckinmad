#if defined _fm_entmod_access_included
  #endinput
#endif
#define _fm_entmod_access_included

#pragma reqlib "fm_entmod_access"

#include "feckinmad/entmod/fm_entmod_base"

native fm_GetEntModAccess(id)

stock fm_CheckUserEntAccess(id)
{
	if (!fm_IsEntModEnabled())
	{
		console_print(id, "Entmod is currently disabled")
		return 0
	}

	if (!fm_GetEntModAccess(id))
	{
		console_print(id, "You don't have access to that command")
		return 0
	}
	return 1
}