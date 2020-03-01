// This plugin provides other plugins with the function to check if a map exists in the map list located in fm_maps.ini
// It uses binary searching for speed and the sorted list of maps is cached in fm_maps_sorted.dat and updated if fm_maps.ini is updated by the user

#include "feckinmad/fm_global"
#include "feckinmad/fm_mapfile_api"
#include "feckinmad/fm_sortedlist" // fm_InsertIntoSortedList(...), fm_BinarySearch(...)
#include "feckinmad/fm_mapfunc"

new Array:g_MapList
new g_iMapCount

new const g_sMapConfigFile[] = "fm_maps.ini" // The human edited list of maps availiable on the server
new const g_sMapSortedFile[] = "fm_maps_sorted.dat" // The plugin generated list of maps sorted alphabetically

public plugin_precache()
{
	//----------------------------------------------------------------------------------------------------
	// Create the dynamic array to hold the list of maps
	//----------------------------------------------------------------------------------------------------

	g_MapList = ArrayCreate(MAX_MAP_LEN)

	//----------------------------------------------------------------------------------------------------
	// Read the sorted map file, if it retuns 0 it either cannot be opened or the hash has changed
	// In which case read the map config file instead
	//----------------------------------------------------------------------------------------------------

	if (!ReadMapSortedFile())
	{
		ReadMapConfigFile()
	}
}

ReadMapSortedFile()
{
	fm_DebugPrintLevel(1, "ReadMapSortedFile()")

	//----------------------------------------------------------------------------------------------------
	// Open the plugin generated alphabetically sorted map list binary file
	//----------------------------------------------------------------------------------------------------

	new sMapSortedPath[128]; fm_BuildAMXFilePath(g_sMapSortedFile, sMapSortedPath, charsmax(sMapSortedPath), "amxx_datadir") 
	new iFileHandle = fopen(sMapSortedPath, "rb")
	if (!iFileHandle)
	{
		return 0
	}

	//----------------------------------------------------------------------------------------------------
	// Compare the hash of the human edited map list config file against the one stored in the sorted file
	//----------------------------------------------------------------------------------------------------

	new sMapConfigPath[128], sHash[34], sSavedHash[34]

	fm_BuildAMXFilePath(g_sMapConfigFile, sMapConfigPath, charsmax(sMapConfigPath), "amxx_configsdir")
	md5_file(sMapConfigPath, sHash)
	fread_blocks(iFileHandle, sSavedHash, sizeof(sHash), BLOCK_CHAR)
	
	if (!equal(sSavedHash, sHash))
	{
		return 0
	}

	//----------------------------------------------------------------------------------------------------
	// Read the number of map names that have been stored in the file
	//----------------------------------------------------------------------------------------------------
	
	new iCount; fread(iFileHandle, iCount, BLOCK_INT)
	
	//----------------------------------------------------------------------------------------------------
	// Loop through the binary file and read map names
	//----------------------------------------------------------------------------------------------------
	
	new sMap[MAX_MAP_LEN]
	for (new i = 0; i < iCount; i++)
	{
		//----------------------------------------------------------------------------------------------------
		// Check number of blocks read matches up
		//----------------------------------------------------------------------------------------------------

		if (fread_blocks(iFileHandle, sMap, MAX_MAP_LEN, BLOCK_CHAR) != MAX_MAP_LEN)
		{
			fm_WarningLog("Error reading file: \"%s\"", sMapSortedPath)
			break
		}

		//----------------------------------------------------------------------------------------------------
		// Check map is actually valid
		//----------------------------------------------------------------------------------------------------

		if (!fm_IsMapValid(sMap)) 
		{
			fm_WarningLog("Skipping missing map: \"%s\"", sMap)
			continue
		}

		//----------------------------------------------------------------------------------------------------
		// Add map name to the dynamic array
		//----------------------------------------------------------------------------------------------------

		ArrayPushString(g_MapList, sMap)
		g_iMapCount++
	}

	fclose(iFileHandle)
	log_amx("Loaded %d maps from \"%s\"", g_iMapCount, sMapSortedPath)

	return 1
}

ReadMapConfigFile()
{	
	fm_DebugPrintLevel(1, "ReadMapConfigFile()")

	//----------------------------------------------------------------------------------------------------
	// Open the human edited unsorted map list plaintext file
	//----------------------------------------------------------------------------------------------------

	new sMapConfigPath[128]; fm_BuildAMXFilePath(g_sMapConfigFile, sMapConfigPath, charsmax(sMapConfigPath), "amxx_configsdir")
	new iFileHandle = fopen(sMapConfigPath, "rt")
	if (!iFileHandle)
	{
		fm_WarningLog(FM_FOPEN_WARNING, sMapConfigPath)
		return 0
	}

	//----------------------------------------------------------------------------------------------------
	// Read all the map names contained within
	//----------------------------------------------------------------------------------------------------

	new sData[MAX_MAP_LEN]
	while (!feof(iFileHandle))
	{
		fgets(iFileHandle, sData, charsmax(sData))

		//----------------------------------------------------------------------------------------------------
		// Clean spaces and line breaks from either end. Ignore comments and blank lines
		//----------------------------------------------------------------------------------------------------

		trim(sData) 

		if(!sData[0] || sData[0] == ';' || sData[0] == '#' || equal(sData, "//", 2)) 
		{
			continue 
		}

		//----------------------------------------------------------------------------------------------------
		// Check map is actually valid
		//----------------------------------------------------------------------------------------------------

		if (!fm_IsMapValid(sData)) 
		{
			fm_WarningLog("Skipping missing map: \"%s\"", sData)
			continue
		}

		//----------------------------------------------------------------------------------------------------
		// Always deal with maps in lowercase for http download consistency (and faster searching)
		//----------------------------------------------------------------------------------------------------

		strtolower(sData)

		//----------------------------------------------------------------------------------------------------
		// Add map name to the dynamic array
		//----------------------------------------------------------------------------------------------------

		if (!fm_InsertIntoSortedList(g_MapList, sData))
		{
			fm_WarningLog("Skipping duplicate map: \"%s\"", sData)
			continue
		}

		g_iMapCount++					
	}

	fclose(iFileHandle)
	
	log_amx("Loaded %d maps from \"%s\"", g_iMapCount, sMapConfigPath)
	WriteMapSortedFile()

	return 1
}

WriteMapSortedFile()
{
	fm_DebugPrintLevel(1, "WriteMapSortedFile()")

	//----------------------------------------------------------------------------------------------------
	// Open the plugin generated alphabetically sorted map list binary file
	//----------------------------------------------------------------------------------------------------

	new sMapSortedPath[128]; fm_BuildAMXFilePath(g_sMapSortedFile, sMapSortedPath, charsmax(sMapSortedPath), "amxx_datadir") 
	new iFileHandle = fopen(sMapSortedPath, "wb")
	if (!iFileHandle)
	{
		fm_WarningLog(FM_FOPEN_WARNING, sMapSortedPath)
		return 0
	}

	//----------------------------------------------------------------------------------------------------
	// Write the hash of the map config file to the sorted file
	// This is so we can check for changes and resort alphabetically on maploads only when required
	//----------------------------------------------------------------------------------------------------

	new sMapConfigPath[128]; fm_BuildAMXFilePath(g_sMapConfigFile, sMapConfigPath, charsmax(sMapConfigPath), "amxx_configsdir")
	new sHash[34]; md5_file(sMapConfigPath, sHash)
	fwrite_blocks(iFileHandle, sHash, sizeof(sHash), BLOCK_CHAR)

	//----------------------------------------------------------------------------------------------------
	// Write map count
	//----------------------------------------------------------------------------------------------------

	fwrite(iFileHandle, g_iMapCount, BLOCK_INT)

	//----------------------------------------------------------------------------------------------------
	// Loop through the dynamic array and write map names
	//----------------------------------------------------------------------------------------------------

	new sMap[MAX_MAP_LEN]	
	for (new i = 0; i < g_iMapCount; i++)
	{
		arrayset(sMap, 0, sizeof(sMap))

		ArrayGetString(g_MapList, i, sMap, charsmax(sMap))
		fwrite_blocks(iFileHandle, sMap, MAX_MAP_LEN, BLOCK_CHAR)
	}

	fclose(iFileHandle)
	log_amx("Wrote %d maps to \"%s\"", g_iMapCount, sMapSortedPath)

	return 1
}

public plugin_init()
{
	fm_RegisterPlugin()
}

public plugin_natives()
{
	register_native("fm_IsMapInMapsFile", "Native_IsMapInMapsFile")
	register_native("fm_GetMapCount", "Native_GetMapCount")
	register_native("fm_GetMapNameByIndex", "Native_GetMapNameByIndex")
	register_native("fm_ReloadMapList", "Native_ReloadMapList")

	register_library("fm_mapfile_api")
}

//----------------------------------------------------------------------------------------------------
// fm_ReloadMapList() - Reloads the map list, returns the number of maps return
//----------------------------------------------------------------------------------------------------

public Native_ReloadMapList()
{
	//----------------------------------------------------------------------------------------------------
	// Reset current map list
	//----------------------------------------------------------------------------------------------------

	ArrayClear(g_MapList)
	g_iMapCount = 0

	//----------------------------------------------------------------------------------------------------
	// Reload from map config file, returning the number of maps read
	//----------------------------------------------------------------------------------------------------

	ReadMapConfigFile()
	return g_iMapCount
}

//----------------------------------------------------------------------------------------------------
// fm_IsMapInMapsFile(sMap[]) - Returns 1 if the mapname exists in the list
//----------------------------------------------------------------------------------------------------

public Native_IsMapInMapsFile()
{
	new sMap[MAX_MAP_LEN]; get_string(1, sMap, charsmax(sMap))

	//----------------------------------------------------------------------------------------------------
	// Always deal with maps in lowercase for http download consistency (and faster searching)
	//----------------------------------------------------------------------------------------------------
	strtolower(sMap)

	return fm_BinarySearch(g_MapList, sMap, 0, g_iMapCount - 1) != -1 ? 1 : 0
}

//----------------------------------------------------------------------------------------------------
// fm_GetMapCount() - Returns the number of maps stored in the list
//----------------------------------------------------------------------------------------------------

public Native_GetMapCount()
{
	return g_iMapCount
}

//----------------------------------------------------------------------------------------------------
// fm_GetMapNameByIndex(iIndex, sMap[], iLen) - Returns the mapname at the specified index in the list
//----------------------------------------------------------------------------------------------------

public Native_GetMapNameByIndex()
{
	new iIndex = get_param(1)
	if (iIndex < 0 || iIndex >= g_iMapCount)
	{
		log_error(AMX_ERR_NATIVE, "Invalid map index (%d)", iIndex)
		return 0
	}

	new sMap[MAX_MAP_LEN]; ArrayGetString(g_MapList, iIndex, sMap, charsmax(sMap))
	set_string(2, sMap, get_param(3))
	return 1
}

public plugin_end()
{
	ArrayDestroy(g_MapList)
}


public fm_ScreenMessage(sBuffer[], iSize)
{
	if (g_iMapCount < 3)
	{
		return PLUGIN_HANDLED
	}

	new iRandomIndex = random(g_iMapCount)
	new sMap[MAX_MAP_LEN]; 

	new iLen = formatex(sBuffer, iSize - 1, "There are %d maps availiable for vote! Type \"listmaps\" to see them all. Why not check out ", g_iMapCount)

	for (new i = 0; i < 3; i ++)
	{
		if (iRandomIndex + i >= g_iMapCount)
		{
			iRandomIndex = 0 - i
		}

		ArrayGetString(g_MapList, iRandomIndex + i, sMap, charsmax(sMap))
		iLen += formatex(sBuffer[iLen], iSize - iLen - 1, "%s", sMap)

		if (i < 1)
		{
			iLen += formatex(sBuffer[iLen], iSize - iLen - 1, ", ")
		}
		else if (i == 1)
		{
			iLen += formatex(sBuffer[iLen], iSize - iLen - 1, " or ")
		}		
	}
	return PLUGIN_HANDLED	
}