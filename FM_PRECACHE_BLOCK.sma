#include "feckinmad/fm_global"
#include "feckinmad/fm_sortedlist"

#include <fakemeta>
#include <hamsandwich>

// For reading keyvalue pairs from the .bsp entdata
#define BSPVERSION 30
#define	MAX_KEY	32
#define	MAX_VALUE 1024

// The different types of resources that can be precached
enum {
	TYPE_SOUND,
	TYPE_MODEL,
	TYPE_GENERIC,
	TYPE_NUM
}

enum {
	READ_BLACKLIST,
	READ_WHITELIST
}

// Class limitations specified in the info_tfdetect
#define NUM_CLASS_BLOCKS 10
new const g_sValidClassBlocks[NUM_CLASS_BLOCKS][] = 
{
	"scout",   // 1<<0 = 1
	"sniper",  // 1<<1 = 2 
	"soldier", // 1<<2 = 4
	"demoman", // 1<<3 = 8
	"medic",   // 1<<4 = 16
	"hwguy",   // 1<<5 = 32
	"pyro",    // 1<<6 = 64
	"random",  // 1<<7 = 128
	"spy",     // 1<<8 = 256
	"engineer" // 1<<9 = 512
}
#define MAX_CLASS_BLOCK_VAL 1023

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

new const g_sReplacementModel[] = "models/fm/missing.mdl" // Model to use if we accidently block precache of a model that is used.
new iReplacement

new HamHook:g_iWeaponBlockHandles[NUM_WEAPON_BLOCKS] // Handles for the Hamsandwich hooks
new Array:g_ResourceBlockList[TYPE_NUM] // The lists of resources that will be blocked
new g_iResourceCount[TYPE_NUM] // Counts for the above
new g_sPrecacheDir[128] // Typically "amxmodx/configs/precache"

public plugin_precache()
{
	// SETUP: To do any blocking, we're going to need to hook onto the precache calls
	register_forward(FM_PrecacheGeneric, "Forward_PrecacheGeneric")
	register_forward(FM_PrecacheSound, "Forward_PrecacheSound")
	register_forward(FM_PrecacheModel, "Forward_PrecacheModel")

	// Create the dynamic arrays which hold the list of blocked resources
	for (new i = 0; i < TYPE_NUM; i++)
	{
		g_ResourceBlockList[i] = ArrayCreate(MAX_RESOURCE_LEN)
	}

	// Lets store the precache config dir as a global as we'll use it several times
	new Buffer[128]; get_localinfo("amxx_configsdir", Buffer, charsmax(Buffer))
	formatex(g_sPrecacheDir, charsmax(g_sPrecacheDir), "%s/precache", Buffer)

	// Read the default precache blocks. This will include everything that we could potentially block that isn't always needed in a map
	formatex(Buffer, charsmax(Buffer), "%s/default.ini", g_sPrecacheDir)
	ReadPrecacheFile(Buffer, READ_BLACKLIST)

	// Now lets remove the stuff we know we'll need for this map. i.e. resources used in the world OR by the allowed classes
	// If the map config file exists, read it, else create it by reading the .bsp entdata
	new sCurrentMap[MAX_MAP_LEN]; get_mapname(sCurrentMap, charsmax(sCurrentMap))

	// TODO: Handle some kind of saving of this so we don't need to read it all the time from the.bsp
	//new sMapConfig[128]; formatex(sMapConfig, charsmax(sMapConfig), "%s/maps/%s.ini", g_sPrecacheDir, sCurrentMap)
	//if (file_exists(sMapConfig)) { ReadPrecacheFile( ... } else {....

	ReadMapEntData(sCurrentMap)

	// Lets try to catch where the models or sounds are used by hooking onto the common way these resources are used. It is not the intention of this plugin to replace resources,
	// and this is an attempt to protect against crashing if we blocked something that is used. This shouldn't happen unless mistakes are made.
	if (g_iResourceCount[TYPE_SOUND] > 0)
	{
		register_forward(FM_EmitSound, "Forward_EmitSound")
	}
	if (g_iResourceCount[TYPE_MODEL] > 0)
	{
		iReplacement = engfunc(EngFunc_PrecacheModel, g_sReplacementModel)
		register_forward(FM_SetModel, "Forward_SetModel")
	}
}

public plugin_init()
{
	fm_RegisterPlugin()
	//TODO: Precache is still called after precache has ended. If I unregister the forwards, I expect it will crash. I need to test.
}

ReadMapEntData(sMap[])
{
	new sFile[128]; formatex(sFile, charsmax(sFile), "maps/%s.bsp", sMap)
	new iFileHandle = fopen(sFile, "rb") 
	if (!iFileHandle)
	{
		fm_WarningLog(FM_FOPEN_WARNING, sFile)
		return 0
	}

	new iVersion
	if (fread(iFileHandle, iVersion, BLOCK_INT) != BLOCK_INT)
	{
		fm_WarningLog("%s: Failed to read BSP version.", sMap)
		return 0
	}

	if (iVersion != BSPVERSION)
	{
		fm_WarningLog("%s: Unexpected BSP version. Expected %d. Got %d", sMap, BSPVERSION, iVersion)
		return 0
	}

	new iEntOffset
	if (fread(iFileHandle, iEntOffset, BLOCK_INT) != BLOCK_INT) 
	{
		fm_WarningLog("%s: Failed to read entdata file offset", sMap)
		return 0
	}

	new iEntDataSize
	if (fread(iFileHandle, iEntDataSize, BLOCK_INT) != BLOCK_INT)  
	{
		fm_WarningLog("%s: Failed to read entdata size", sMap)
		return 0
	}

	if (fseek(iFileHandle, iEntOffset, SEEK_SET))
	{
		fm_WarningLog("%s: Failed to seek to entdata offset", sMap)
		return 0
	}

	new iEndOffset = iEntOffset + iEntDataSize // Calculate end offset of entdata	
	new sData[MAX_KEY + MAX_VALUE + 8], sKey[MAX_KEY], sValue[MAX_VALUE]
	new bool:bDetectEnt, bool:bClassLimitDone, iClassValue = MAX_CLASS_BLOCK_VAL
	new bool:bCivilianClass

	while(ftell(iFileHandle) < iEndOffset)
	{	
		if (feof(iFileHandle))
		{
			fm_WarningLog("%s: Unexpected end of file", sMap)
			return 0
		}
		
		fgets(iFileHandle, sData, charsmax(sData))

		if (!sData[0] || sData[0] == '{' || sData[0] == '}')
		{
			// Entity we are working on is now changing. If the current entity the info_tfdetect lets process what we (hopefully) read from the class keys
			if (bDetectEnt)
			{		
				fm_DebugPrintLevel(2, "Finished processing info_tfdetect. iClassValue: %d bCivilianClass: %s", iClassValue, bCivilianClass ? "Y" : "N")		
				bClassLimitDone = true // Avoid any more processing of keys. TFC shares keys so the keys used for class restrictions aren't unique to the info_tfdetect entity
				bDetectEnt = false // Mark that we're no longer working with the info_tfdetect

				new sBuffer[128]
				// If a civilian class was found whitelist the resources associated with it
				if (bCivilianClass)
				{
					formatex(sBuffer, charsmax(sBuffer), "%s/tf_class_civilian.ini", g_sPrecacheDir)
					ReadPrecacheFile(sBuffer, READ_WHITELIST)
				}

				// Run through each class config and whitelist if the class is availiable on the map
				for (new i = 0; i < NUM_CLASS_BLOCKS; i++)
				{
					if (~iClassValue & (1<<i) || iClassValue == MAX_CLASS_BLOCK_VAL)
					{
						formatex(sBuffer, charsmax(sBuffer), "%s/tf_class_%s.ini", g_sPrecacheDir, g_sValidClassBlocks[i])
						ReadPrecacheFile(sBuffer, READ_WHITELIST)
					}
				}
			}
			else
			{
				// There's a chance that we read keys that belong to another entity and not the info_tfdetect. Reset the variables after each non info_tfdetect entity.
				bCivilianClass = false
				iClassValue = MAX_CLASS_BLOCK_VAL
				bClassLimitDone = false
			}	
		}
		else if (parse(sData, sKey, charsmax(sKey), sValue, charsmax(sValue)) == 2)
		{
			if (equali(sKey, "classname")) 
			{
				if (equali(sValue, "info_tfdetect"))
				{
					fm_DebugPrintLevel(2, "Detected info_tfdetect classname")

					// Now THIS is podracing! Flag that we've seen the info_tfdetect. Note: This can appear at the after of all the others keyvalue pairs
					bDetectEnt = true 
				}
				else if (equal(sKey, "replacement_model")) // item_tfgoal allows the player model to be replaced. Make sure we whitelist it
				{
					new sBuffer[128]; formatex(sBuffer, charsmax(sBuffer), "models/player/%s/%s.mdl", sValue, sValue)
					if (fm_InsertIntoSortedList(Array:g_ResourceBlockList[TYPE_MODEL], sBuffer))
					{
						g_iResourceCount[TYPE_MODEL]++
					}	
				}
				else
				{
					// Some escape maps spawn weapons which the civilian class can pickup. Catch that here and unblock as required
					for (new i = 0; i < NUM_WEAPON_BLOCKS; i++)
					{
						if (equali(sValue, g_sValidWeaponBlocks[i]))
						{
							// Remove from the block list so we don't block any of it's precache
							new sBuffer[128]; formatex(sBuffer, charsmax(sBuffer), "%s/%s.ini", g_sPrecacheDir, g_sValidWeaponBlocks[i])
							ReadPrecacheFile(sBuffer, READ_WHITELIST)
							AllowWeaponDeploy(g_sValidWeaponBlocks[i]) // Allow the deployment of the weapon
						}
					}
				}
			}
			// TFC shares keys, so the keys used for class restrictions aren't unique to the info_tfdetect entity.
			// We can't be sure that we're working with the keys for an info_tfdetect, as classname could be the last key read
			// Lets just read the values and we can reset them later if it turns out this isn't the info_tfdetect.
			else if (!bClassLimitDone && (equal(sKey, "maxammo_shells") || equal(sKey, "maxammo_nails") || equal(sKey, "maxammo_rockets") || equal(sKey, "maxammo_cells")))
			{
				fm_DebugPrintLevel(2, "Class key: \"%s\": \"%s\"", sKey, sValue)
				new iValue = str_to_num(sValue)
				switch (iValue)
				{
					case -1: // Only civilian on this team
					{
						bCivilianClass = true
					}
					case 0: // All classes are allowed, so we can't unprecache any class related resources. 
					{
						bClassLimitDone = true // Lets end it all... it's pointless from here on out.
						iClassValue = MAX_CLASS_BLOCK_VAL // Mark all classes as valid
					}
					default: // Other class limit TODO: Handle this after all the keys are processed to avoid reading files that have already been read.
					{
						fm_DebugPrintLevel(3, "iClassValue: %d iValue: %d (iClassValue & iValue): %d", iClassValue, iValue, iClassValue & iValue)
						iClassValue &= iValue
					}
				}
				continue
			}
			else
			{
				// Check the end of the value info to see if it matches a file extension. There's a tiny change for false positives here, but this is easier than trying to catch all the keys where a resource could be set.
				new iType = GetResourceType(sValue)
				if (iType != -1)
				{
					if (fm_RemoveFromSortedList(g_ResourceBlockList[iType], sValue[iType == TYPE_SOUND ? 6 : 0]))
					{
						g_iResourceCount[iType]--
					}
				}
			}

			// TODO: Handle some other keys here that would need resources whitelisted for example entities with effects such as quad.
			// invincible_finished(integer) : "Invincibility duration"
			// invisible_finished(integer) : "Invisibility duration"
			// super_damage_finished(integer) : "Quad duration"
			// radsuit_finished	
		}
	}
	return 1
}

ReadPrecacheFile(sFile[], iBlackList)
{
	fm_DebugPrintLevel(1, "ReadPrecacheFile(\"%s\")", sFile)

	new iFileHandle = fopen(sFile, "rt")
	if (!iFileHandle)
	{
		fm_WarningLog(FM_FOPEN_WARNING, sFile)	
		return 0
	}

	new sData[512]
	while (!feof(iFileHandle))
	{
		fgets(iFileHandle, sData, charsmax(sData))
		trim(sData)

		if(!sData[0] || sData[0] == ';' || sData[0] == '#' || equal(sData, "//", 2)) 
		{
			continue
		}

		if (sData[0] == '@')
		{
			if (equal(sData[1], "import ", 7) && !(equali(sFile, sData[8])))
			{
				// If the file to read is a weapon make and we're whitelisting, make sure we unblock the weapon deploy
				for (new i = 0; i < NUM_WEAPON_BLOCKS; i++)
				{
					if (equali(sData[8], g_sValidWeaponBlocks[i]))
					{
						if (iBlackList == READ_BLACKLIST)
						{
							BlockWeaponDeploy(g_sValidWeaponBlocks[i]) 
						}
						else
						{
							AllowWeaponDeploy(g_sValidWeaponBlocks[i]) 
						}
						break
					}
				}

				// Read the file referenced in this file
				new sBuffer[128]; formatex(sBuffer, charsmax(sBuffer), "%s/%s", g_sPrecacheDir, sData[8])
				ReadPrecacheFile(sBuffer, iBlackList)
			}
		}
		else
		{
			new iType = GetResourceType(sData)
			if (iType != -1)
			{
				if (iBlackList == READ_BLACKLIST)
				{
					if (fm_InsertIntoSortedList(g_ResourceBlockList[iType], sData[iType == TYPE_SOUND ? 6 : 0]))
					{
						fm_DebugPrintLevel(2, "Added: \"%s\" to blacklist (%d)", sData[iType == TYPE_SOUND ? 6 : 0], iType)
						g_iResourceCount[iType]++
					}
				}
				else // Assume type whitelist
				{
					if (fm_RemoveFromSortedList(g_ResourceBlockList[iType], sData[iType == TYPE_SOUND ? 6 : 0]))
					{
						fm_DebugPrintLevel(2, "Removed: \"%s\" from blacklist (%d)", sData[iType == TYPE_SOUND ? 6 : 0], iType)
						g_iResourceCount[iType]--
					}
				}
			}
			else
			{
				// fm_WarningLog
			}
		}		
	}
	fclose(iFileHandle)
	return 1
}

GetResourceType(sFile[])
{
	// Position of the file extension
	new iExt = strlen(sFile) - 4
	if (iExt <= 0 || sFile[iExt++] != '.')
	{
		return -1
	}
	else if (equali(sFile[iExt], "wav")) 
	{
		return TYPE_SOUND
	}
	else if (equali(sFile[iExt], "mdl") || equali(sFile[iExt], "spr"))
	{
		return TYPE_MODEL
	}
	return TYPE_GENERIC						
}


//  TODO: Implement some kind of writing to file / caching
/*
WritePrecaceFile(sFile[])
{
	new iFileHandle = fopen(sFile, "wt")
	if (!iFileHandle)
	{
		fm_WarningLog(FM_FOPEN_WARNING, sFile)	
		return 0
	}

	new sResource[MAX_RESOURCE_LEN]
	for (new i = 0; i < TYPE_NUM; i++)
	{	
		for (new j = 0; j < g_iResourceCount[i]; j++)
		{
			ArrayGetString(g_ResourceBlockList[i], j, sResource, charsmax(sResource))
			fprintf(iFileHandle, "%s\n", sResource)
		}
	}
	fclose(iFileHandle)
	return 1
}
*/

// The "sound/" directory at the start of the string is assumed by PrecacheSound and not included in the path
public Forward_PrecacheSound(sFile[])
{
	if (fm_BinarySearch(Array:g_ResourceBlockList[TYPE_SOUND], sFile, 0, g_iResourceCount[TYPE_SOUND] - 1) != -1)
	{
		fm_DebugPrintLevel(2, "Blocked precache for file: \"sound/%s\"", sFile)
		return FMRES_SUPERCEDE
	}

	fm_DebugPrintLevel(2, "Allowed precache for file: \"sound/%s\"", sFile)
	return FMRES_IGNORED
}

public Forward_PrecacheModel(sFile[])
{
	if (fm_BinarySearch(Array:g_ResourceBlockList[TYPE_MODEL], sFile, 0, g_iResourceCount[TYPE_MODEL] - 1) != -1)
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
	if (fm_BinarySearch(Array:g_ResourceBlockList[TYPE_GENERIC], sFile, 0, g_iResourceCount[TYPE_GENERIC] - 1, 0) != -1)
	{
		fm_DebugPrintLevel(2, "Blocked precache for file: \"%s\"", sFile)
		return FMRES_SUPERCEDE
	}

	fm_DebugPrintLevel(2, "Allowed precache for file: \"%s\"", sFile)
	return FMRES_IGNORED
}

// The "sound/" directory at the start of the string is assumed by EmitSound and not included in the path
public Forward_EmitSound(iEnt, iChannel, sSound[])
{	
	if (fm_BinarySearch(Array:g_ResourceBlockList[TYPE_SOUND], sSound, 0, g_iResourceCount[TYPE_SOUND] - 1, 0) != -1)
	{
		fm_WarningLog("Blocked emitsound for file: \"sound/%s\"", sSound)	
		return FMRES_SUPERCEDE
	}
	return FMRES_IGNORED
}

public Forward_SetModel(iEnt, sModel[])
{	
	if (fm_BinarySearch(Array:g_ResourceBlockList[TYPE_MODEL], sModel, 0, g_iResourceCount[TYPE_MODEL] - 1, 0) != -1)
	{
		fm_WarningLog("Blocked setmodel for file: \"%s\"", sModel)
		engfunc(EngFunc_SetModel, iEnt, g_sReplacementModel) // Replace unprecached models with replacement "error" model
		return FMRES_SUPERCEDE
	}
	return FMRES_IGNORED
}

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
		// Check if the weapon deploy hook has already been created. If not, create it. Else just ensure we didn't disable it.
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

// CanDeploy is called by the engine before a weapon is deployed, if the weapon models have not been precached it will crash.
// This hook on CanDeploy blocks the weapon being deployed in case of a mistake in the precache config for the currentmap.
// We're only aiming to block class based weapons on maps where those classes are not available, so log an error.
public Forward_HamCanDeploy(iEnt)
{
	new sCurrentMap[MAX_MAP_LEN]; get_mapname(sCurrentMap, charsmax(sCurrentMap))
	fm_WarningLog("Blocked weapon deployment! Check precache files for %s", sCurrentMap)

	// Return 0 and SUPERCEDE so the weapon is not deployed
	SetHamReturnInteger(0)
	return HAM_SUPERCEDE
}




