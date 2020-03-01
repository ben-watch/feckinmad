#include "feckinmad/fm_global"

#include <fakemeta>

public plugin_init()
{
	fm_RegisterPlugin()
}

public client_putinserver(id)
{
	engfunc(EngFunc_SetView, id, id)
}