#include "feckinmad/fm_global"

#define MAX_COLOURS 128
#define MAX_COLOUR_NAME_LEN 12

new const g_sColourFile[] = "fm_colours.ini"

new g_sColourList[MAX_COLOURS][MAX_COLOUR_NAME_LEN] // List of colours
new g_iColourValues[MAX_COLOURS][3] // The RGB colours
new g_iColourNum // Total number of colours loaded

new const g_sTextColourIndexRange[] = "Colour index out of range (%d)"
new const g_sTextColour[][] =
{
	"red",
	"green",
	"blue"
}

public plugin_precache()
{
	ReadColourFile()
}

ReadColourFile() 
{
	new sFile[128]; fm_BuildAMXFilePath(g_sColourFile, sFile, charsmax(sFile), "amxx_configsdir")
	new iFileHandle = fopen(sFile, "rt")
	if (!iFileHandle)
	{	
		fm_WarningLog(FM_FOPEN_WARNING, sFile)
		return 0
	}

	new sData[128], iValueCount, sColourValue[4], iColourValue
	while (!feof(iFileHandle))
	{
		fgets(iFileHandle, sData, charsmax(sData))
		trim(sData)		

		if(!sData[0] || sData[0] == ';' || sData[0] == '#' || equal(sData, "//", 2)) 
			continue
	
		if (g_iColourNum >= MAX_COLOURS)
		{
			fm_WarningLog("Maximum colours reached")	
			break
		}	
	
		strbreak(sData, g_sColourList[g_iColourNum], MAX_COLOUR_NAME_LEN - 1, sData, charsmax(sData)) // Store the colour name

		iValueCount = sColourValue[0] = 0
		while (iValueCount < 3) // Load the R G & B values
		{
			strbreak(sData, sColourValue, charsmax(sColourValue), sData, charsmax(sData))

			if (!sColourValue[0])
			{
				break
			}

			iColourValue = str_to_num(sColourValue)

			if (iColourValue < -1 || iColourValue > 255)
			{
				fm_WarningLog("Colour \"%s\" has invalid %s value (%d)", g_sColourList[g_iColourNum], g_sTextColour[iValueCount], iColourValue)
			}
		
			g_iColourValues[g_iColourNum][iValueCount++] = iColourValue
		}
		
		if (iValueCount < 3)
		{
			fm_WarningLog("Ignoring colour \"%s\": Missing colour values", g_sColourList[g_iColourNum])	
		}
		else
		{
			fm_DebugPrintLevel(2, "Loaded colour: \"%s\": { %d, %d, %d }", g_sColourList[g_iColourNum], g_iColourValues[g_iColourNum][0], g_iColourValues[g_iColourNum][1], g_iColourValues[g_iColourNum][2])
			g_iColourNum++
		}

	}
	
	fclose(iFileHandle)
	log_amx("Loaded %d colours from \"%s\"", g_iColourNum, sFile)

	return 1
}

public plugin_init()
{
	fm_RegisterPlugin()
}

public plugin_natives()
{	
	register_native("fm_GetColourCount", "Native_GetColourCount")
	register_native("fm_GetColourIndex", "Native_GetColourIndex")
	register_native("fm_GetColourNameByIndex", "Native_GetColourNameByIndex")
	register_native("fm_GetColoursByIndex", "Native_GetColoursByIndex")
	register_library("fm_colour_api")
}

public Native_GetColourCount()
{
	return g_iColourNum
}

public Native_GetColourIndex()
{
	new sColour[MAX_COLOUR_NAME_LEN]; get_string(1, sColour, charsmax(sColour))

	for (new i = 0; i < g_iColourNum; i++) 
	{
		if (equali(g_sColourList[i], sColour)) 
		{
			return i
		}
	}
	return -1
}


public Native_GetColourNameByIndex()
{
	new iIdent = get_param(1)

	if (iIdent < 0 || iIdent >= g_iColourNum) 
	{
		log_error(AMX_ERR_NATIVE, g_sTextColourIndexRange, iIdent)
		return 0
	}
	set_string(2, g_sColourList[iIdent], MAX_COLOUR_NAME_LEN)
	return 1
}

public Native_GetColoursByIndex()
{
	new iIdent = get_param(1)

	if (iIdent < 0 || iIdent >= g_iColourNum) 
	{
		log_error(AMX_ERR_NATIVE,  g_sTextColourIndexRange, iIdent)
		return 0
	}

	set_array(2, g_iColourValues[iIdent], 3)
	return 1
}

public fm_ScreenMessage(sBuffer[], iSize)
{
	// TODO: Move this to FM_GLOW.amxx
	formatex(sBuffer, iSize - 1, "There are %d colours availiable for you to glow. Type \"glow menu\" to see them all. I hear %s is in this season", g_iColourNum, g_sColourList[random(g_iColourNum)])	
}
