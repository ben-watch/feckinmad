#include "feckinmad/fm_global"
#include "feckinmad/fm_menu"
#include "feckinmad/fm_precache"

#include <fakemeta>

#define MAX_MENU_ENTRIES 9
#define MAX_MENU_NAME_LEN 32
#define MAX_MENU_COMMAND_LEN 32

enum eMenuItem_t
{
	m_iMenuEntryIdent,
	m_iMenuEntryEnabled,
	m_iMenuEntryName[MAX_MENU_NAME_LEN],
	m_iMenuEntryCommand[MAX_MENU_COMMAND_LEN]
}

new const g_sMenuFile[] = "fm_menu.ini"

new g_sMenuItems[MAX_MENU_ENTRIES][eMenuItem_t]
new g_iMenuItemCount

new g_sMenuText[MAX_MENU_STRING], g_iMenuKeys

public plugin_precache()
{
	fm_SafePrecacheSound(FM_MENU_SELECT_SOUND)
}

public plugin_init()
{
	fm_RegisterPlugin()

	register_menucmd(register_menuid("[FM] Menu:"), ALL_MENU_KEYS, "Command_Main_Menu")

	register_clcmd("say menu", "MainMenu")
	register_clcmd("say_team menu", "MainMenu")
	register_clcmd("menu", "MainMenu")
	register_clcmd("fm_menu_bind", "BindKeys")

	ReadMenuFile()
}

ReadMenuFile()
{
	new sFile[128]; fm_BuildAMXFilePath(g_sMenuFile, sFile, charsmax(sFile), "amxx_configsdir")
	new iFileHandle = fopen(sFile, "rt")
	if (!iFileHandle)
	{
		fm_WarningLog(FM_FOPEN_WARNING, sFile)
		return 0
	}

	new iLen = formatex(g_sMenuText, charsmax(g_sMenuText), "[FM] Menu:\n\n")

	new sData[128], sName[MAX_MENU_NAME_LEN], sCommand[MAX_MENU_COMMAND_LEN]
	while (!feof(iFileHandle))
	{			
		fgets(iFileHandle, sData, charsmax(sData))
		trim(sData)		

		if(sData[0] == ';' || sData[0] == '#' || (sData[0] == '/' && sData[1] == '/' )) 
		{
			continue
		}

		if (g_iMenuItemCount >= MAX_MENU_ENTRIES)
		{
			fm_WarningLog("Max menu entries loaded (%d)", MAX_MENU_ENTRIES)
			break
		}

		if (!sData[0])
		{
			iLen += formatex(g_sMenuText[iLen], charsmax(g_sMenuText) - iLen, "\n")
		}
		else
		{
			if (parse(sData, sName, charsmax(sName), sCommand, charsmax(sCommand)) != 2)
			{
				fm_WarningLog("Error lOLOloloolololaodakjndjhawndyuaw")
				continue
			}

			remove_quotes(sName)
			iLen += formatex(g_sMenuText[iLen], charsmax(g_sMenuText) - iLen, "%d) %s\n", g_iMenuItemCount + 1, sName)
			g_iMenuKeys |= (1 << g_iMenuItemCount)

			copy(g_sMenuItems[g_iMenuItemCount], MAX_MENU_COMMAND_LEN - 1, sCommand)
		}		
		g_iMenuItemCount++
	}
	fclose(iFileHandle)

	iLen += formatex(g_sMenuText[iLen], charsmax(g_sMenuText) - iLen, "\n0) Cancel")
	g_iMenuKeys |= (1<<9)	
		
	log_amx("Loaded %d menu items from \"%s\"", g_iMenuItemCount, sFile)
	return 1
}

public MainMenu(id)
{
	if (!g_iMenuItemCount) 
	{
		client_print(id, print_chat,"* Error: No menu commands have been loaded")
		return PLUGIN_HANDLED
	}

	show_menu(id, g_iMenuKeys, g_sMenuText)

	return PLUGIN_HANDLED // Block say chat from appearing
}

public Command_Main_Menu(id, iKey)
{
	if (iKey >= 0 && iKey < g_iMenuItemCount)
	{
		client_cmd(id, g_sMenuItems[iKey])
		fm_PlaySound(id, FM_MENU_SELECT_SOUND)
	}
}

public BindKeys(id)
{	
	client_cmd(id, "bind 1 slot1;bind 2 slot2;bind 3 slot3;bind 4 slot4;bind 5 slot5;bind 6 slot6;bind 7 slot7;bind 8 slot8;bind 9 slot9;bind 0 slot10")
	client_print(id, print_chat,"* Menu keys (0 - 9) have been bound successfully")
}
