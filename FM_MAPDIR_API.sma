#include "feckinmad/fm_global"

new g_sMapDir[] = "maps/"

new Array:g_ValidMapList
new g_iValidMapCount

public plugin_natives()
{
	register_native("fm_IsValidMap", "Native_IsValidMap")
	register_native("fm_GetValidMapName", "Native_GetValidMapName")
	register_native("fm_GetValidMapCount", "Native_GetValidMapCount")
	register_native("fm_GetValidMapNameByIndex", "Native_GetValidMapNameByIndex")

	register_library("fm_mapdir_api")
}

public plugin_precache()
{
	g_ValidMapList = ArrayCreate(MAX_MAP_LEN)
	ReadMapDir()
}

public plugin_init() 
{
	fm_RegisterPlugin()
}

public plugin_end()
	ArrayDestroy(g_ValidMapList)

ReadMapDir()
{
	new sMap[MAX_MAP_LEN], iLen

	new iDirHandle = open_dir(g_sMapDir, sMap, charsmax(sMap))
	if (!iDirHandle)
	{
		fm_WarningLog("Unable to open maps directory")
		return 0
	}
			
	do {
		iLen = strlen(sMap) - 4
		if (iLen < 0)
			continue 		
			
		if(!equali(sMap[iLen], ".bsp")) 
			continue

		sMap[iLen] = 0		

		ArrayPushString(g_ValidMapList, sMap)
		g_iValidMapCount++

	} while (next_file(iDirHandle, sMap, charsmax(sMap)))
	close_dir(iDirHandle)

	log_amx("Loaded %d valid maps from \"%s\"", g_iValidMapCount, g_sMapDir)

	ArraySort(g_ValidMapList, "Handle_Compare")

	return 1
}

public Handle_Compare(Array:List, iItem1, iItem2)
{
	static sItem1[MAX_MAP_LEN]; ArrayGetString(List, iItem1, sItem1, charsmax(sItem1))
	static sItem2[MAX_MAP_LEN]; ArrayGetString(List, iItem2, sItem2, charsmax(sItem2))

	return strcmp(sItem1, sItem2, 1) 
}

BinarySearch(sMap[], iLow, iHigh)
{
	if (iHigh < iLow)
		return -1 // Not found

	new iMid = iLow + ((iHigh - iLow) / 2)
	static sBuffer[MAX_MAP_LEN]; ArrayGetString(g_ValidMapList, iMid, sBuffer, charsmax(sBuffer))
	
	new iRet = strcmp(sBuffer, sMap, 1)

	if (iRet > 0)
		return BinarySearch(sMap, iLow, iMid - 1)
	else if (iRet < 0)
		return BinarySearch(sMap, iMid + 1, iHigh)

	return iMid // Found
}

public Native_IsValidMap()
{
	new sMap[MAX_MAP_LEN]; get_string(1, sMap, charsmax(sMap))
	return BinarySearch(sMap, 0, g_iValidMapCount - 1) != -1 ? 1 : 0
}

public Native_GetValidMapName()
{
	new sMap[MAX_MAP_LEN]; get_string(1, sMap, charsmax(sMap))

	new iIndex = BinarySearch(sMap, 0, g_iValidMapCount - 1)
	if (iIndex != -1)
	{
		ArrayGetString(g_ValidMapList, iIndex, sMap, charsmax(sMap))
		set_string(2, sMap, get_param(3))
		return 1
	}
	return 0
}

public Native_GetValidMapCount()
	return g_iValidMapCount

public Native_GetValidMapNameByIndex()
{
	new iIndex = get_param(1)
	if (iIndex < 0 || iIndex >= g_iValidMapCount)
	{
		log_error(AMX_ERR_NATIVE, "Invalid map index (%d)", iIndex)
		return 0
	}

	new sMap[MAX_MAP_LEN]; ArrayGetString(g_ValidMapList, iIndex, sMap, charsmax(sMap))
	set_string(2, sMap, get_param(3))
	return 1
}

