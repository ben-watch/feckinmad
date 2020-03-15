//	FM_PrecacheEvent,
//	FM_PlaybackEvent,

#include "feckinmad/fm_global"
#include "feckinmad/fm_sortedlist"

#include <fakemeta>
#include <hamsandwich>

enum {
	TYPE_SOUND,
	TYPE_MODEL,
	TYPE_GENERIC,
	TYPE_NUM
}

new g_sPrecacheDir[128]

new Array:g_ResourceList[TYPE_NUM]
new g_iResourceCount[TYPE_NUM]

new const g_sReplacement[] = "models/fm/missing.mdl"
new iReplacement

public plugin_precache()
{
	// Create the dynamic arrays which hold the list of resources
	for (new i = 0; i < TYPE_NUM; i++)
	{
		g_ResourceList[i] = ArrayCreate(MAX_RESOURCE_LEN)
	}

	// Hold the directory of the precache files globally as it will be used multiple times
	new sBuffer[128]; get_localinfo("amxx_configsdir", sBuffer, charsmax(sBuffer))
	formatex(g_sPrecacheDir, charsmax(g_sPrecacheDir), "%s/fm/precache/", sBuffer)

	// The Read the precache file for the currentmap 
	// Maybe in the future we may require 

	new sCurrentMap[MAX_MAP_LEN]; get_mapname(sCurrentMap, charsmax(sCurrentMap))
	formatex(sBuffer, charsmax(sBuffer), "%s.ini", sCurrentMap)
	ReadPrecacheFile(sBuffer, 1)
	
	if (g_iResourceCount[TYPE_SOUND] > 0)
	{
		register_forward(FM_PrecacheSound, "Forward_PrecacheSound")
		register_forward(FM_EmitSound, "Forward_EmitSound")
	}
	
	if (g_iResourceCount[TYPE_MODEL] > 0)
	{
		register_forward(FM_PrecacheModel, "Forward_PrecacheModel")
		register_forward(FM_SetModel, "Forward_SetModel")
		iReplacement = engfunc(EngFunc_PrecacheModel, g_sReplacement)
	}
	
	if (g_iResourceCount[TYPE_GENERIC] > 0)
	{
		register_forward(FM_PrecacheGeneric, "Forward_PrecacheGeneric")
	}

	/*
	fm_DebugPrintLevel(2, "iReplacement: %d g_iResourceCount[ TYPE_SOUND: %d, TYPE_MODEL: %d, TYPE_GENERIC: %d ]", iReplacement, g_iResourceCount[TYPE_SOUND], g_iResourceCount[TYPE_MODEL], g_iResourceCount[TYPE_GENERIC])

	new sBuffer[MAX_RESOURCE_LEN]
	for (new i = 0; i < TYPE_NUM; i++)
	{	
		fm_DebugPrintLevel(3, "Resource List: %d", i)
		for (new j = 0; j < g_iResourceCount[i]; j++)
		{
			ArrayGetString(g_ResourceList[i], j, sBuffer, charsmax(sBuffer))
			fm_DebugPrintLevel(3, "%d: \"%s\"", j, sBuffer)

		}
	}
	*/
}

ReadPrecacheFile(sReadFile[], iLogError)
{
	fm_DebugPrintLevel(1, "ReadPrecacheFile(\"%s\")", sReadFile)

	new sFile[128]; formatex(sFile, charsmax(sFile), "%s%s", g_sPrecacheDir, sReadFile)
	new iFileHandle = fopen(sFile, "rt")
	if (!iFileHandle)
	{
		if (iLogError)
		{
			fm_WarningLog(FM_FOPEN_WARNING, sFile)	
		}
		return 0
	}

	new sData[128], iPos, iType, iLine
	while (!feof(iFileHandle))
	{
		fgets(iFileHandle, sData, charsmax(sData))
		trim(sData); iLine++

		if(!sData[0] || sData[0] == ';' || sData[0] == '#' || equal(sData, "//", 2)) 
		{
			continue
		}

		if (sData[0] == '@')
		{
			if (equal(sData[1], "import ", 7) && !(equali(sReadFile, sData[8])))
			{
				ReadPrecacheFile(sData[8], 1)
			}
			else if (equal(sData[1], "blockdeploy ", 12))
			{
				// When blocking weapon models, it is important to block the weapon from being deployed otherwise the game will crash
				// Although the plan is to only block models that aren't used, mistakes might be made on custom maps that allow weapon pickups
				BlockWeaponDeploy(sData[13])
			}
			else if (equal(sData[1], "allowdeploy ", 12))
			{
			 	AllowWeaponDeploy(sData[13])
			}
			else
			{
				// Position of the file extension
				iPos = strlen(sData) - 4
				if (iPos < 0)
				{
					continue
				}

				// Determine the type of resource
				if (equali(sData[iPos], ".wav")) 
				{
					// The "sound/" directory at the start of the string is assumed by emitsound and precachesound and they don't actually include it
					// But check here to ensure the resource file was not written incorrectly by the user
					if (!equali(sData[7], "sound/", 6))
					{
						fm_WarningLog("Sound file not in \"sound\" (\"%s\") directory", sData[7])
						continue
					}
					iType = TYPE_SOUND
				}

				else if (equali(sData[iPos], ".mdl") || equali(sData[iPos], ".spr"))
				{
					iType = TYPE_MODEL
				}
				else
				{
					iType = TYPE_GENERIC						
				}

				// Block or allow the resource file
				if (equal(sData[1], "block ", 6))
				{
					if (fm_InsertIntoSortedList(g_ResourceList[iType], sData[iType == TYPE_SOUND ? 13 : 7]))
					{
						g_iResourceCount[iType]++
					}
				}
				else if (equal(sData[1], "allow ", 6)) 
				{
					// Because some player classes share weapons and resources, allow the blocking to be undone
					// This allows a map precache file to block classes that are not used followed by allowing the classes that are.
					// I could even make this automatic at some point by hooking keyvalue and reading the keys set in info_tfdetect

					fm_RemoveFromSortedList(g_ResourceList[iType], sData[iType == TYPE_SOUND ? 13 : 7])
				}
				else
				{
					fm_WarningLog("Unknown command (\"%s\") in file \"%s\"", sData[1], sFile)				
				}
			}
		}
		else
		{
			fm_WarningLog("Unknown command in file \"%s\" Line: %d", sFile, iLine)
		}
	}
	fclose(iFileHandle)
	return 1
}

//------------------------------------------------------------------------------------
// PRECACHE BLOCKING
//------------------------------------------------------------------------------------

public Forward_PrecacheSound(sFile[])
{
	if (fm_BinarySearch(Array:g_ResourceList[TYPE_SOUND], sFile, 0, g_iResourceCount[TYPE_SOUND] - 1) != -1)
	{
		fm_DebugPrintLevel(2, "Blocked precache for file: \"sound/%s\"", sFile)
		return FMRES_SUPERCEDE
	}

	fm_DebugPrintLevel(2, "Allowed precache for file: \"sound/%s\"", sFile)
	return FMRES_IGNORED
}

public Forward_PrecacheModel(sFile[])
{
	if (fm_BinarySearch(Array:g_ResourceList[TYPE_MODEL], sFile, 0, g_iResourceCount[TYPE_MODEL] - 1) != -1)
	{
		fm_DebugPrintLevel(2, "Blocked precache for file: \"%s\"", sFile) 
		forward_return(FMV_CELL, iReplacement)
		return FMRES_SUPERCEDE
	}

	fm_DebugPrintLevel(2, "Allowed precache for file: \"%s\"", sFile)
	return FMRES_IGNORED
}

public Forward_PrecacheGeneric(sFile[])
{
	if (fm_BinarySearch(Array:g_ResourceList[TYPE_GENERIC], sFile, 0, g_iResourceCount[TYPE_GENERIC] - 1, 0) != -1)
	{
		fm_DebugPrintLevel(2, "Blocked precache for file: \"%s\"", sFile)
		return FMRES_SUPERCEDE
	}

	fm_DebugPrintLevel(2, "Allowed precache for file: \"%s\"", sFile)
	return FMRES_IGNORED
}

//------------------------------------------------------------------------------------
// EMITSOUND/SETMODEL BLOCKING
//------------------------------------------------------------------------------------

public Forward_EmitSound(iEnt, iChannel, sSound[])
{	
	if (fm_BinarySearch(Array:g_ResourceList[TYPE_SOUND], sSound, 0, g_iResourceCount[TYPE_SOUND] - 1, 0) != -1)
	{
		fm_WarningLog("Blocked emitsound for file: \"sound/%s\"", sSound)	
		return FMRES_SUPERCEDE
	}
	return FMRES_IGNORED
}

public Forward_SetModel(iEnt, sModel[])
{	
	if (fm_BinarySearch(Array:g_ResourceList[TYPE_MODEL], sModel, 0, g_iResourceCount[TYPE_MODEL] - 1, 0) != -1)
	{
		fm_WarningLog("Blocked setmodel for file: \"%s\"", sModel)
		engfunc(EngFunc_SetModel, iEnt, g_sReplacement) // Replace unprecached models with replacement "error" model
		return FMRES_SUPERCEDE
	}
	return FMRES_IGNORED
}

//------------------------------------------------------------------------------------
// WEAPON DEPLOYMENT BLOCKING
//------------------------------------------------------------------------------------

#define NUM_WEAPON_BLOCKS 18
new const g_sValidWeaponBlocks[NUM_WEAPON_BLOCKS][] = 
{
	"tf_weapon_ac",
	"tf_weapon_autorifle",
	"tf_weapon_axe",
	"tf_weapon_flamethrower",
	"tf_weapon_gl",
	"tf_weapon_ic",
	"tf_weapon_knife",
	"tf_weapon_medikit",
	"tf_weapon_ng",
	"tf_weapon_pl",
	"tf_weapon_railgun",
	"tf_weapon_rpg",
	"tf_weapon_sniperrifle",
	"tf_weapon_spanner", 
	"tf_weapon_superng", 
	"tf_weapon_shotgun",
	"tf_weapon_supershotgun",
	"tf_weapon_tranq"
}

new HamHook:g_iWeaponBlockHandles[NUM_WEAPON_BLOCKS]

GetWeaponBlockIndex(sWeapon[])
{
	for (new i = 0; i < NUM_WEAPON_BLOCKS; i++)
	{
		if (equal(sWeapon, g_sValidWeaponBlocks[i]))
		{
			return i
		}
	}
	fm_WarningLog("Unable to block weapon: \"%s\" as it doesn't exist", sWeapon)
	return -1
}

AllowWeaponDeploy(sWeapon[])
{
	new iIndex = GetWeaponBlockIndex(sWeapon)
	if (iIndex != -1 && g_iWeaponBlockHandles[iIndex])
	{
		DisableHamForward(g_iWeaponBlockHandles[iIndex])
	}
}

BlockWeaponDeploy(sWeapon[])
{
	new iIndex = GetWeaponBlockIndex(sWeapon)
	if (iIndex != -1)
	{
		// -------------------------------------------------------------------------------------------------------------
		// Check if the weapon deploy hook has already been created. If not, create it! Else just ensure it is enabled
		// -------------------------------------------------------------------------------------------------------------
		if (!g_iWeaponBlockHandles[iIndex])
		{
			RegisterHam(Ham_Item_CanDeploy, g_sValidWeaponBlocks[iIndex], "Forward_HamCanDeploy")
		}
		else
		{
			EnableHamForward(g_iWeaponBlockHandles[iIndex])
		}
		return 1
	}
	return 0		
}

// -------------------------------------------------------------------------------------------------------------
// CanDeploy is called by the engine before a weapon is deployed, if the weapon models have not been precached it will crash
// This hook on CanDeploy blocks the weapon being deployed in case of a mistake in the precache config for the currentmap
// it isn't the intention to block weapons that can be selected, only class based weapons on maps where those classes are not available 
// -------------------------------------------------------------------------------------------------------------
public Forward_HamCanDeploy(iEnt)
{
	// -------------------------------------------------------------------------------------------------------------
	// Log an error
	// -------------------------------------------------------------------------------------------------------------
	new sCurrentMap[MAX_MAP_LEN]; get_mapname(sCurrentMap, charsmax(sCurrentMap))
	fm_WarningLog("Blocked weapon deployment! Check precache files for %s", sCurrentMap)

	// -------------------------------------------------------------------------------------------------------------
	// Return 0 and SUPERCEDE so the weapon is not deployed
	// -------------------------------------------------------------------------------------------------------------
	SetHamReturnInteger(0)
	return HAM_SUPERCEDE
}
