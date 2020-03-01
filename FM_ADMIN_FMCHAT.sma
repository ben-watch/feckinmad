#include "feckinmad/fm_global"
#include "feckinmad/fm_admin_access"

new g_iMaxPlayers

public plugin_init()
{
	fm_RegisterPlugin()
	register_concmd("admin_fmchat", "Admin_FmChat", ADMIN_MEMBER, "<message>")
	g_iMaxPlayers = get_maxplayers()
}

public Admin_FmChat(id, iLevel, iCommand) 
{
	//----------------------------------------------------------------------------------------------------
	// Check the user has access and entered the correct number of arguments
	//----------------------------------------------------------------------------------------------------

	if (!fm_CommandAccess(id, iLevel, false) || !fm_CommandUsage(id, iCommand, 2))
	{
		return PLUGIN_HANDLED
	}

	//----------------------------------------------------------------------------------------------------
	// Read the message they wish to print and remove the quotes associated with "messagemode" binds
	//----------------------------------------------------------------------------------------------------

	new sArgs[192]; read_args(sArgs, charsmax(sArgs))
	remove_quotes(sArgs) 
	
	//----------------------------------------------------------------------------------------------------
	// Trim and check to avoid printing blank lines
	//----------------------------------------------------------------------------------------------------

	trim(sArgs)
	if (!sArgs[0]) 
	{
		return PLUGIN_HANDLED  
	}

	//----------------------------------------------------------------------------------------------------
	// Replace % characters with an actual % to avoid formatting errors
	//----------------------------------------------------------------------------------------------------

	replace_all(sArgs, charsmax(sArgs), "%", "%%%%")
	
	//----------------------------------------------------------------------------------------------------
	// Gather command user information to print alongside the message
	//----------------------------------------------------------------------------------------------------

	new sName[MAX_NAME_LEN]; get_user_name(id, sName, charsmax(sName))
	new sAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAuthid, charsmax(sAuthid))
	new sAdminRealName[MAX_NAME_LEN]; fm_GetUserRealname(id, sAdminRealName, charsmax(sAdminRealName))
	
	//----------------------------------------------------------------------------------------------------
	// Print the message with thier "real" name if they are using a different alias
	//----------------------------------------------------------------------------------------------------
	new sMessage[MAX_CHAT_LEN]
	if (equali(sName, sAdminRealName))
	{	
		formatex(sMessage, charsmax(sMessage), "(FM) #%d %s: %s", fm_GetUserIdent(id), sName, sArgs)
	}
	else
	{
		formatex(sMessage, charsmax(sMessage), "(FM) #%d %s (%s): %s", fm_GetUserIdent(id), sName, sAdminRealName, sArgs)
	}

	//----------------------------------------------------------------------------------------------------
	// Print the message to everyone on the server who has access to the command
	//----------------------------------------------------------------------------------------------------

	for (new i = 1; i <= g_iMaxPlayers; i++)
	{
		if (is_user_connected(i) && (fm_GetUserAccess(i) & iLevel)) // Display the message to players that have access to this command
		{
			client_print(i, print_chat, sMessage)
		}
	}
	
	//----------------------------------------------------------------------------------------------------
	// Log to amx log file
	//----------------------------------------------------------------------------------------------------
	log_amx("\"%s<%s>(%s)\" admin_fmchat \"%s\"", sName, sAuthid, sAdminRealName, sArgs)
	
	return PLUGIN_HANDLED
}