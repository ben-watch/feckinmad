#include "feckinmad/fm_global"

#include "feckinmad/entmod/fm_entmod_base" // fm_DestroyEntKeys()
#include "feckinmad/entmod/fm_entmod_access" // fm_CheckUserEntAccess()
#include "feckinmad/entmod/fm_entmod_command" // fm_CommandGetEntity()

#include <fakemeta>

#define MAX_CLASSNAME_LEN 32

new const g_sDeleteExcludeFile[] = "fm_entmod_delete_exclude.ini"
new Array:g_aDeleteExclude
new g_iDeleteExcludeCount

public plugin_init()
{
	fm_RegisterPlugin()

	register_clcmd("fm_ent_delete", "Player_EntDelete")

	g_aDeleteExclude = ArrayCreate(MAX_CLASSNAME_LEN)
	ReadDeleteExcludeFile()
}

public Player_EntDelete(id)
{
	if (!fm_CheckUserEntAccess(id))
	{
		return PLUGIN_HANDLED
	}

	new sArg[8]; read_argv(1, sArg, charsmax(sArg))
	new iEnt = fm_CommandGetEntity(id, sArg)
	if (!iEnt || !fm_CommandCheckEntity(id, iEnt, ENTCMD_DELETE)) 
	{
		return PLUGIN_HANDLED
	}
	
	fm_DestroyCachedEntKeys(iEnt)
	engfunc(EngFunc_RemoveEntity, iEnt)

	return PLUGIN_HANDLED
}

ReadDeleteExcludeFile()
{
	new sFile[128]; fm_BuildAMXFilePath(g_sDeleteExcludeFile, sFile, charsmax(sFile), FM_AMXX_LOCAL_CONFIGS)
	new iFileHandle = fopen(sFile, "rt")
	if (!iFileHandle)
	{
		fm_WarningLog(FM_FOPEN_WARNING, sFile)
		return 0
	}

	new sData[MAX_CLASSNAME_LEN]
	while (!feof(iFileHandle))
	{
		fgets(iFileHandle, sData, charsmax(sData))
		trim(sData) 

		if(fm_Comment(sData)) 
		{
			continue 
		}

		ArrayPushString(g_aDeleteExclude, sData)
		g_iDeleteExcludeCount++
	}

	log_amx("Loaded %d entmod delete excludes from \"%s\"", g_iDeleteExcludeCount, sFile)

	fclose(iFileHandle)
	return 1
}

public fm_RunEntCommand(id, iEnt, iMode)
{
	if (iMode == ENTCMD_DELETE)
	{
		new sData[MAX_CLASSNAME_LEN], sClassName[MAX_CLASSNAME_LEN]
		pev(iEnt, pev_classname, sClassName, charsmax(sClassName))

		for (new i = 0; i < g_iDeleteExcludeCount; i++)
		{
			ArrayGetString(g_aDeleteExclude, i, sData, charsmax(sData))
		
			if (equali(sData, sClassName))
			{
				client_print(id, print_chat, "* You cannot use entmod delete commands on this entity")
				return PLUGIN_HANDLED	
			}
		}
	}
	return PLUGIN_CONTINUE
}