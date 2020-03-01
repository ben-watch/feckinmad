#if defined _fm_entmod_command_included
  #endinput
#endif
#define _fm_entmod_command_included

#define ENTCMD_READ	(1<<0)
#define ENTCMD_MODIFY	(1<<1)
#define ENTCMD_DELETE	(1<<2)

native fm_CommandGetEntity(id, sArg[])
native fm_CommandCheckEntity(id, iEnt, iMode)