#include "feckinmad/fm_global"

#include <fakemeta>

public fm_PluginInit()
{
	register_clcmd("fm_ent_count", "Player_PrintEntCount")
}

public Player_PrintEntCount(id)	
{
	client_print(id, print_chat, "Entity Count: %d/%d", engfunc(EngFunc_NumberOfEntities), global_get(glb_maxEntities))
}