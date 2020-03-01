#include "feckinmad/fm"
#include "feckinmad/fm_mapfile_api"

enum ePreviousMap_t
{
	m_sMapName[MAX_MAP_LEN],
	m_iLastPlayed,
	m_iLengthPlayed
}

new const g_sPreviousFile[] = "fm_previousmaps.dat"
new const g_iPreviousTimeLimit = 7200 // 2 hours

new Array:g_PreviousMapList
new g_iPreviousMapCount 

new g_sCurrentMap[MAX_MAP_LEN]
new g_iStartTime

public fm_PluginInit() 
{
	get_mapname(g_sCurrentMap, charsmax(g_sCurrentMap))
	g_iStartTime = get_systime()

	g_PreviousMapList = ArrayCreate(ePreviousMap_t)

	ReadPreviousMapFile()
}

ReadPreviousMapFile()
{
	fm_DebugPrintLevel(1, "ReadPreviousMapFile()")

	new sFile[128]; get_localinfo("amxx_datadir", sFile, charsmax(sFile))
	format(sFile, charsmax(sFile), "%s/%s", sFile, g_sPreviousFile)

	new iFileHandle = fopen(sFile, "rb")
	if (!iFileHandle) 
	{
		return 0
	}

	new iCount; fread(iFileHandle, iCount, BLOCK_INT)
	
	new Buffer[ePreviousMap_t]
	for (new i = 0; i < iCount; i++)
	{
		fread_blocks(iFileHandle, Buffer, ePreviousMap_t, BLOCK_INT)

		fm_DebugPrintLevel(2, "%s: %d - %d = %d", Buffer[m_sMapName], get_systime(), Buffer[m_iLastPlayed], get_systime() - Buffer[m_iLastPlayed])

		if (get_systime() - Buffer[m_iLastPlayed] < g_iPreviousTimeLimit)
		{
			ArrayPushArray(g_PreviousMapList, Buffer)
			g_iPreviousMapCount++
		}
	}

	fclose(iFileHandle)
	log_amx("Read %d previous maps from \"%s\"", g_iPreviousMapCount, sFile)

	return 1	
}

public plugin_end()
{	
	WritePreviousMapFile()

	if (g_PreviousMapList != Invalid_Array)
	{
		ArrayDestroy(g_PreviousMapList)
	}
}

WritePreviousMapFile()
{
	fm_DebugPrintLevel(1, "WritePreviousMapFile()")

	new sFile[128]; get_localinfo("amxx_datadir", sFile, charsmax(sFile))
	format(sFile, charsmax(sFile), "%s/%s", sFile, g_sPreviousFile)

	new iFileHandle = fopen(sFile, "wb")
	if (!iFileHandle) 
	{
		fm_WarningLog(FM_FOPEN_WARNING, sFile)
		return 0
	}

	fwrite(iFileHandle, g_iPreviousMapCount + 1, BLOCK_INT)

	new Buffer[ePreviousMap_t]
	for (new i = 0; i < g_iPreviousMapCount; i++)
	{
		ArrayGetArray(g_PreviousMapList, i, Buffer)
		fwrite_blocks(iFileHandle, Buffer, ePreviousMap_t, BLOCK_INT)
	}

	Buffer[m_iLastPlayed] = get_systime()
	Buffer[m_iLengthPlayed] = Buffer[m_iLastPlayed] - g_iStartTime
	copy(Buffer[m_sMapName], MAX_MAP_LEN - 1, g_sCurrentMap)
	fwrite_blocks(iFileHandle, Buffer, ePreviousMap_t, BLOCK_INT)

	fclose(iFileHandle)
	log_amx("Wrote %d previous maps to \"%s\"", g_iPreviousMapCount + 1, sFile)

	return 1	
}

public plugin_natives()
{
	register_native("fm_IsPreviousMap", "Native_IsPreviousMap")
	register_library("fm_mapvote_previous")
}

public Native_IsPreviousMap()
{
	fm_DebugPrintLevel(1, "Native_IsPreviousMap()")

	new sMap[MAX_MAP_LEN]; get_string(1, sMap, charsmax(sMap))

	new Buffer[ePreviousMap_t]
	for (new i = 0; i < g_iPreviousMapCount; i++)
	{
		ArrayGetArray(g_PreviousMapList, i, Buffer)
		if (equali(sMap, Buffer[m_sMapName]))
		{
			return 1
		}
	}
	return 0
}

public fm_CanUserNominate(id, sMap[])
{
	new Buffer[ePreviousMap_t]
	for (new i = 0; i < g_iPreviousMapCount; i++)
	{
		ArrayGetArray(g_PreviousMapList, i, Buffer)
		if (equali(sMap, Buffer[m_sMapName]))
		{
			new sTime[64]; fm_SecondsToText(get_systime() - Buffer[m_iLastPlayed], sTime, charsmax(sTime))
			client_print(id, print_chat, "* You cannot nominate \"%s\" because it was played recently (%s ago)", sMap, sTime)
			return PLUGIN_HANDLED

		}
	}
	return PLUGIN_CONTINUE
}
