#if defined _fm_debug_included
  #endinput
#endif
#define _fm_debug_included

stock const g_sTextDebug[] = "DEBUG: [%s] %s"

stock fm_DebugPrintLevel(iLevelReq, sFormat[], any:...)
{
	static iDebugStatus

	// Check if debugging has been disabled until mapchange
	if (iDebugStatus == -1)
		return 0 
	
	static pCvarDebugLevel, pCvarDebugDest, pCvarDebugFilter

	// Check if the debug cvars have been registered and get pointers to them
	if (iDebugStatus == 0)
	{
		pCvarDebugLevel = register_cvar("fm_debug_level", "0") // amxx will check if its already registered and still return its pointers
		pCvarDebugFilter = register_cvar("fm_debug_filter", "")
		pCvarDebugDest = register_cvar("fm_debug_dest", "0")
		iDebugStatus = 1
	}
	
	static iDebugLevel; iDebugLevel = get_pcvar_num(pCvarDebugLevel)

	// If the debug cvar is set to < 0, totally disable debug logging until mapchange
	// This allows me to forgo the ability to enable logging midmap in order to make it more efficient
	if (iDebugLevel < 0)
	{
		iDebugStatus = -1
		return 0
	}

	// Allow stages of debugging similar to "meta_debug" or "developer"
	if (iDebugLevel < iLevelReq)
		return 0

	// Get the name of the plugin
	static sFileName[32]
	if (!sFileName[0])
		get_plugin(-1, sFileName, charsmax(sFileName))

	// Check if we want to filter out all debug not belonging to a specific plugin
	static sPluginFilter[32]
	get_pcvar_string(pCvarDebugFilter, sPluginFilter, charsmax(sPluginFilter))	

	if (sPluginFilter[0] != '\0' && !equali(sPluginFilter, sFileName))
		return 0

	static sMessage[255]; sMessage[0] = '\0'
	vformat(sMessage, charsmax(sMessage), sFormat, 3)

	switch(get_pcvar_num(pCvarDebugDest))
	{
		case 1: 
		{
			static sLogFile[32]; get_time("debug_%Y%m%d.log", sLogFile, charsmax(sLogFile))
			log_to_file(sLogFile, g_sTextDebug, sFileName, sMessage)
		}
		case 2: log_message(g_sTextDebug, sFileName, sMessage)
		case 3: client_print(0, print_chat, g_sTextDebug, sFileName, sMessage)
		case 4: client_print(0, print_console, g_sTextDebug, sFileName, sMessage)
		default: server_print(g_sTextDebug, sFileName, sMessage)
	}

	return 1
}

/*
FM_PROFILETEST.amxx

public plugin_init()
{
	for (new i = 0; i < 100000; i++)
		fm_DebugPrintLevel(2, "Testing Debug %d. This is a test heh.", 1234567890)
}

fm_debug_level -1 / fm_debug_dest 0 / fm_debug_filter ""
-------------------------------------------------------------------
   n |                    get_pcvar_num |          1 | 0.000001 / 0.000001 / 0.000001
   p |                      plugin_init |          1 | 0.077244 / 0.077244 / 0.077244
   f |               fm_DebugPrintLevel |     100000 | 0.075868 / 0.000001 / 0.000695
   f |        fm_GetRegisterCvarPointer |          3 | 0.000005 / 0.000001 / 0.000002


fm_debug_level 0 / fm_debug_dest 0 / fm_debug_filter "" (default)
-------------------------------------------------------------------
   n |                    get_pcvar_num |     100000 | 0.074766 / 0.000001 / 0.000827
   p |                      plugin_init |          1 | 0.077524 / 0.077524 / 0.077524
   f |               fm_DebugPrintLevel |     100000 | 0.154416 / 0.000001 / 0.000708
   f |        fm_GetRegisterCvarPointer |          3 | 0.000005 / 0.000002 / 0.000002

fm_debug_level 2 / fm_debug_dest 0 / fm_debug_filter ""
-------------------------------------------------------------------
   n |                    get_pcvar_num |     200000 | 0.150137 / 0.000001 / 0.000726
   n |                       get_plugin |          1 | 0.000001 / 0.000001 / 0.000001
   n |                 get_pcvar_string |     100000 | 0.077927 / 0.000001 / 0.000826
   n |                          vformat |     100000 | 0.100281 / 0.000001 / 0.000317
   n |                     server_print |     100000 | 1.378683 / 0.000012 / 0.000913
   n |                 get_cvar_pointer |          3 | 0.000009 / 0.000002 / 0.000004
   p |                      plugin_init |          1 | 0.080240 / 0.080240 / 0.080240
   f |               fm_DebugPrintLevel |     100000 | 0.474373 / 0.000004 / 0.000841
   f |        fm_GetRegisterCvarPointer |          3 | 0.000006 / 0.000001 / 0.000002

fm_debug_level 2 / fm_debug_dest 0 / fm_debug_filter "FM_NOPLUGINLOL.amxx"
-------------------------------------------------------------------
   n |                    get_pcvar_num |     100000 | 0.075028 / 0.000001 / 0.000754
   n |                       get_plugin |          1 | 0.000001 / 0.000001 / 0.000001
   n |                 get_pcvar_string |     100000 | 0.078189 / 0.000001 / 0.000471
   n |                           equali |     100000 | 0.077623 / 0.000001 / 0.000176
   n |                 get_cvar_pointer |          3 | 0.000008 / 0.000003 / 0.000003
   p |                      plugin_init |          1 | 0.080408 / 0.080408 / 0.080408
   f |               fm_DebugPrintLevel |     100000 | 0.308311 / 0.000003 / 0.001880
   f |        fm_GetRegisterCvarPointer |          3 | 0.000007 / 0.000002 / 0.000002


fm_debug_level 2 / fm_debug_dest 0 / fm_debug_filter "FM_PROFILETEST.amxx"
-------------------------------------------------------------------
   n |                    get_pcvar_num |     200000 | 0.150540 / 0.000001 / 0.000378
   n |                       get_plugin |          1 | 0.000001 / 0.000001 / 0.000001
   n |                 get_pcvar_string |     100000 | 0.082526 / 0.000001 / 0.000335
   n |                           equali |     100000 | 0.098599 / 0.000001 / 0.001028
   n |                          vformat |     100000 | 0.104077 / 0.000001 / 0.000984
   n |                     server_print |     100000 | 1.397960 / 0.000012 / 0.001162
   n |                 get_cvar_pointer |          3 | 0.000009 / 0.000003 / 0.000003
   p |                      plugin_init |          1 | 0.080484 / 0.080484 / 0.080484
   f |               fm_DebugPrintLevel |     100000 | 0.551615 / 0.000005 / 0.001170
   f |        fm_GetRegisterCvarPointer |          3 | 0.000005 / 0.000001 / 0.000002


// Testing using engfunc(EngFunc_ServerPrint, sMessage) (and adding the newline) instead of using server_print
// Not a lot of difference, so I'll stick to server print.

fm_debug_level 2 / fm_debug_dest 0
-------------------------------------------------------------------
   n |                    get_pcvar_num |     200000 | 0.145776 / 0.000001 / 0.000169
   n |                       get_plugin |          1 | 0.000001 / 0.000001 / 0.000001
   n |                 get_pcvar_string |     100000 | 0.077034 / 0.000001 / 0.000163
   n |                          vformat |     100000 | 0.099269 / 0.000001 / 0.000234
   n |                           strlen |     100000 | 0.084875 / 0.000001 / 0.000279
   n |                          engfunc |     100000 | 1.179587 / 0.000010 / 0.002614
   n |                 get_cvar_pointer |          3 | 0.000009 / 0.000003 / 0.000004
   p |                      plugin_init |          1 | 0.076067 / 0.076067 / 0.076067
   f |               fm_DebugPrintLevel |     100000 | 0.537973 / 0.000005 / 0.000320
   f |        fm_GetRegisterCvarPointer |          3 | 0.000006 / 0.000002 / 0.000002
*/