#include "feckinmad/fm_global"

new const g_sFactFile[] = "fm_message_facts.ini"

new Array:g_MessageList
new g_iMessageCount
new g_iCurrentMessage

public plugin_init()
{
	fm_RegisterPlugin()
	g_MessageList = ArrayCreate(MAX_HUDMSG_LEN)
	ReadFactFile()

	g_iCurrentMessage = random(g_iMessageCount)
}

public plugin_end()
{
	ArrayDestroy(g_MessageList)
}

ReadFactFile()
{
	new sFile[128]; fm_BuildAMXFilePath(g_sFactFile, sFile, charsmax(sFile), "amxx_configsdir")
	new iFileHandle = fopen(sFile, "rt")
	if (!iFileHandle)
	{
		fm_WarningLog(FM_FOPEN_WARNING, sFile)
		return 0	
	}

	new sData[MAX_HUDMSG_LEN]
	while (!feof(iFileHandle))
	{
		fgets(iFileHandle, sData, charsmax(sData))
		trim(sData)
					
		if (!fm_Comment(sData))
		{
			ArrayPushString(g_MessageList, sData)
			g_iMessageCount++
		}		
	}
	fclose(iFileHandle)
	log_amx("Loaded %d facts from %s", g_iMessageCount, sFile)

	return g_iMessageCount
}

public fm_ScreenMessage(sBuffer[], iSize)
{
	if (!g_iMessageCount)
	{
		// Error handling needs to be added to FM_MESSAGE.amxx
		formatex(sBuffer, iSize, "")
		return PLUGIN_HANDLED	
	}

	if (g_iCurrentMessage >= g_iMessageCount)
	{
		g_iCurrentMessage = 0
	}

	ArrayGetString(g_MessageList, g_iCurrentMessage, sBuffer, iSize)
	g_iCurrentMessage++

	return PLUGIN_HANDLED
}