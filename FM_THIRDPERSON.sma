#include "feckinmad/fm_global"
#include "feckinmad/fm_module" // Thirdperson is actually just ripped from the engine module with some small modifications

new bool:g_bPlayerThirdperson[MAX_PLAYERS + 1]
new Float:g_fNextChange[MAX_PLAYERS + 1]

public plugin_init()
{
	fm_RegisterPlugin()
	register_concmd("fm_thirdperson", "Thirdperson")
}

public plugin_natives()
{	
	register_native("fm_is_user_thirdperson","Native_GetUserThird")
	register_library("fm_thirdperson")
}

public Native_GetUserThird(iPlugin, iParams)
{
	new id = get_param(1)
	if (id)	
		return g_bPlayerThirdperson[id]
	return 0
}

public Thirdperson(id)
{
	// To stop invalid player messages for now, I think this is related to the menu. I need to check.
	if (!is_user_connected(id))
		return PLUGIN_HANDLED

	new Float:fGameTime = get_gametime()
	
	if (fGameTime < g_fNextChange[id])
	{
		client_print(id, print_chat, "* You can't switch your view mode so soon.")
		return PLUGIN_HANDLED
	}

	g_fNextChange[id] = fGameTime + 1.0
	
	if (!g_bPlayerThirdperson[id])
	{
		set_view(id, 1)
		client_print(id,print_chat, "* Thirdperson mode activated")
		g_bPlayerThirdperson[id] = true
	}
	else 
	{
		set_view(id, 0)	
		client_print(id,print_chat, "* Firstperson mode activated")
		g_bPlayerThirdperson[id] = false
	}
	return PLUGIN_HANDLED
}

public client_disconnect(id)
{
	g_bPlayerThirdperson[id] = false
	g_fNextChange[id] = 0.0
}
