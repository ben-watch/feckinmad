#include "feckinmad/fm_global"
#include "feckinmad/fm_sortedlist"

#include <fakemeta>
#include <hamsandwich>
//#include <orpheu>

// For reading keyvalue pairs from the .bsp entdata
#define BSPVERSION 30
#define	MAX_KEY	32
#define	MAX_VALUE 1024

//#define PRECACHE_TEST

// The different types of resources that can be precached
enum {
	RESOURCE_TYPE_SOUND,
	RESOURCE_TYPE_MODEL,
	RESOURCE_TYPE_GENERIC,
	RESOURCE_TYPE_NUM
}

enum {
	READ_BLACKLIST,
	READ_WHITELIST
}

// Class limitations specified in the info_tfdetect
#define NUM_CLASS_BLOCKS 10
#define MAX_CLASS_BLOCK_VAL 1023 // Value of all the below bits added up
#define CLASS_RESTRICTION_RANDOM 7 
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

// TFC weapons used by the different classes
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

// Breakable materials from breakable.h
enum {
	matGlass = 0,
	matWood,
	matMetal,
	matFlesh,
	matCinderBlock,
	matCeilingTile,
	matComputer,
	matUnbreakableGlass,
	matRocks,
	matNone,
	matLastMaterial
}


// Model to use if we accidently block precache of a model that is used.
new const g_sReplacementModel[] = "models/fm/missing.mdl" 
new iReplacement

new HamHook:g_iWeaponBlockHandles[NUM_WEAPON_BLOCKS] // Handles for the Hamsandwich hooks
new Array:g_ResourceBlockList[RESOURCE_TYPE_NUM] // The lists of resources that will be blocked
new g_iResourceCount[RESOURCE_TYPE_NUM] // Counts for the above
new g_sPrecacheDir[128] // Typically "amxmodx/configs/precache"
new g_sCurrentMap[MAX_MAP_LEN]

public plugin_precache()
{
	// Setup: To do any blocking, we're going to need to hook onto the precache calls
	register_forward(FM_PrecacheGeneric, "Forward_PrecacheGeneric")
	register_forward(FM_PrecacheSound, "Forward_PrecacheSound")
	register_forward(FM_PrecacheModel, "Forward_PrecacheModel")

	// Create the dynamic arrays which hold the list of blocked resources
	for (new i = 0; i < RESOURCE_TYPE_NUM; i++)
	{
		g_ResourceBlockList[i] = ArrayCreate(MAX_RESOURCE_LEN)
	}

	// Lets store the precache config dir as a global as we'll use it several times
	new sBuffer[128]; get_localinfo("amxx_configsdir", sBuffer, charsmax(sBuffer))
	formatex(g_sPrecacheDir, charsmax(g_sPrecacheDir), "%s/precache", sBuffer)
	get_mapname(g_sCurrentMap, charsmax(g_sCurrentMap))

	// Reading all the files and entdata is time consuming, so read the cache if we have it
	// We just have to remember to clear the cache if we edit the other config files TODO: md5 the main configs and detect changes
	formatex(sBuffer, charsmax(sBuffer), "%s/cache/%s.ini", g_sPrecacheDir, g_sCurrentMap)
	if (file_exists(sBuffer))
	{
		fm_DebugPrintLevel(1, "Reading cached map blacklist config %s", sBuffer)
		ReadPrecacheFile(sBuffer, READ_BLACKLIST)
	}
	else
	{
		// Read the default precache blocks. This will include everything that we could potentially block that isn't always needed in a map
		formatex(sBuffer, charsmax(sBuffer), "%s/default.ini", g_sPrecacheDir)
		fm_DebugPrintLevel(1, "Reading default config %s", sBuffer)
		ReadPrecacheFile(sBuffer, READ_BLACKLIST)

		// Next unblock the resources we know we'll not use in this map. i.e. Resources linked to classes that are not enabled
		// Or unblock resources where they are used in the map. Read this from the entdata.	
		fm_DebugPrintLevel(1, "Reading map entdata %s", g_sCurrentMap)
		if (!ReadMapEntData(g_sCurrentMap))
		{
			for (new i = 0; i < RESOURCE_TYPE_NUM; i++)
			{
				ArrayClear(g_ResourceBlockList[i])
				g_iResourceCount[i] = 0
			}
			return PLUGIN_CONTINUE
		}

		// Read the resources we always want to remain unblocked
		formatex(sBuffer, charsmax(sBuffer), "%s/default-whitelist.ini", g_sPrecacheDir)
		if (file_exists(sBuffer))
		{
			fm_DebugPrintLevel(1, "Reading default whitelist config %s", sBuffer)
			ReadPrecacheFile(sBuffer, READ_WHITELIST)
		}

		// Repeat this for any map specific config
		formatex(sBuffer, charsmax(sBuffer), "%s/maps/%s-whitelist.ini", g_sPrecacheDir, g_sCurrentMap)
		if (file_exists(sBuffer))
		{
			fm_DebugPrintLevel(1, "Reading default map whitelist config %s", sBuffer)
			ReadPrecacheFile(sBuffer, READ_WHITELIST)
		}

		// Write a log of the blocked resources for troubleshooting / reference
		formatex(sBuffer, charsmax(sBuffer), "%s/cache/%s.ini", g_sPrecacheDir, g_sCurrentMap)
		WritePrecaceLogFile(sBuffer)
	}

	// Lets try to catch where the models or sounds are used by hooking onto the common way these resources are used. It is not the intention of this plugin to replace resources,
	// and this is an attempt to protect against crashing if we blocked something that is used. This shouldn't happen unless mistakes are made.
	if (g_iResourceCount[RESOURCE_TYPE_SOUND] > 0)
	{
		register_forward(FM_EmitSound, "Forward_EmitSound")
		register_forward(FM_EmitAmbientSound, "Forward_EmitAmbientSound")
		//OrpheuRegisterHook(OrpheuGetFunction("SV_LookupSoundIndex"), "Forward_LookupSoundIndex") // BUG with blocking SFX...
	}
	if (g_iResourceCount[RESOURCE_TYPE_MODEL] > 0)
	{
		iReplacement = engfunc(EngFunc_PrecacheModel, g_sReplacementModel)
		register_forward(FM_SetModel, "Forward_SetModel")
		
	}

	#if defined PRECACHE_TEST
	register_forward(FM_KeyValue, "Forward_KeyValue")
	register_forward(FM_Spawn, "Forward_Spawn")
	register_forward(FM_CreateEntity, "Forward_CreateEntity")
	register_forward(FM_CreateNamedEntity, "Forward_CreateNamedEntity_Post", 1)
	register_forward(FM_RemoveEntity, "Forward_RemoveEntity")
	//register_forward(FM_ModelIndex, "Forward_ModelIndex") // Holy spam.
	#endif

	return PLUGIN_CONTINUE
}

public plugin_init()
{
	fm_RegisterPlugin()
	// TODO: Precache is still called after precache has ended. If I unregister the forwards, I expect it will crash. I need to test.
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
	new bool:bDetectEntFound, bool:bDetectEntCurrent, bool:bClassLimitDone, iClassRestrictionValue = MAX_CLASS_BLOCK_VAL
	new bool:bCivilianClass, bool:bClassKeyParsed, iLine, sPath[128]

	// TODO: I'm not super happy about having to capture the info_tfdetect data like this. It works, but is ugly.
	// Need to write parser function that will read all the lines related to entity keys at once.
	while(ftell(iFileHandle) < iEndOffset)
	{	
		if (feof(iFileHandle))
		{
			fm_WarningLog("%s: Unexpected end of file", sMap)
			return 0
		}
		
		fgets(iFileHandle, sData, charsmax(sData))
		trim(sData)
		iLine++

		if (!sData[0] || sData[0] == '{' || sData[0] == '}')
		{
			// Entity we are working on is now changing. If the current entity the info_tfdetect lets process what we (hopefully) read from the class keys
			if (bDetectEntCurrent)
			{		
				fm_DebugPrintLevel(2, "Finished processing info_tfdetect. iClassRestrictionValue: %d bCivilianClass: %s bClassKeyParsed: %s", iClassRestrictionValue, bCivilianClass ? "Y" : "N", bClassKeyParsed ? "Y" : "N")	
	
				bClassLimitDone = true // Avoid any more processing of the class related keys. TFC shares keys so the keys used for class restrictions aren't unique to the info_tfdetect entity
				bDetectEntCurrent = false // Mark that we're no longer working with the info_tfdetect

				// If a civilian class was found whitelist the resources associated with it
				if (bCivilianClass)
				{
					formatex(sPath, charsmax(sPath), "%s/tf_class_civilian.ini", g_sPrecacheDir)
					ReadPrecacheFile(sPath, READ_WHITELIST)
				}
				
				// If no class restriction keys were parsed. There's no restrictions
				// OR if the class restriction value is blocking all classes, we know it's possibly read -1
				// for civilian, and the other class restriction keys are unlisted, but still unrestricted
				if (!bClassKeyParsed || iClassRestrictionValue == MAX_CLASS_BLOCK_VAL)
				{
					iClassRestrictionValue = 0
				}

				// Run through each class config and whitelist if the class is availiable on the map
				for (new i = 0; i < NUM_CLASS_BLOCKS; i++)
				{
					if ((~iClassRestrictionValue & (1<<i) || !iClassRestrictionValue) && (i != CLASS_RESTRICTION_RANDOM)) // 7 is the: No Random class, so nothing to load there.
					{
						formatex(sPath, charsmax(sPath), "%s/tf_class_%s.ini", g_sPrecacheDir, g_sValidClassBlocks[i])
						ReadPrecacheFile(sPath, READ_WHITELIST)
					}
				}
			}
			else
			{
				// There's a chance that we read keys that belong to another entity and not the info_tfdetect. Reset the variables after each non info_tfdetect entity.
				// TODO: This is a bit of shitshow. Lets rewrite some nice entdata parser at a later date...
				bCivilianClass = false
				iClassRestrictionValue = MAX_CLASS_BLOCK_VAL
				bClassLimitDone = false
				bClassKeyParsed = false
			}	
		}
		else if (parse(sData, sKey, charsmax(sKey), sValue, charsmax(sValue)) == 2)
		{
			if (equal(sKey, "classname")) 
			{
				if (equal(sValue, "info_tfdetect"))
				{
					fm_DebugPrintLevel(2, "Detected info_tfdetect classname")

					// Now THIS is podracing! Flag that we've seen the info_tfdetect. Because we want to grab any class restriction keys
					// Note: This can and does often appear after of all the others keyvalue pairs, so often we've already read the keys by this point.
					bDetectEntCurrent = true  
					bDetectEntFound = true
				}

				else if (equal(sValue, "monster_miniturret") || equal(sValue, "monster_turret")) 
				{
					RemoveFromBlockList("sound/weapons/hks1.wav", RESOURCE_TYPE_SOUND)
					RemoveFromBlockList("sound/weapons/hks2.wav", RESOURCE_TYPE_SOUND)
					RemoveFromBlockList("sound/weapons/hks3.wav", RESOURCE_TYPE_SOUND)
				}

				// Not all maps need the healing sound, but the sounds are precached on all. used by medic, but block/unblock in the tf_weapon_medikit config. 
				// But there's a chance someone has used a wall health charger, so unblock if so.
				else if (equal(sValue, "func_healthcharger")) 
				{
					RemoveFromBlockList("sound/items/medshot4.wav", RESOURCE_TYPE_SOUND) // This one is emitted on the server side, but...
					RemoveFromBlockList("sound/items/medshot4.wav", RESOURCE_TYPE_SOUND) // ... I can't see where this is used, possibly clientside when healing.
				}

				// Very little use in TFC, but this wav is precached on all maps. Block in the default config, and handle the slim chance that someone used this entity in a map
				else if (equal(sValue, "func_recharge")) 
				{
					RemoveFromBlockList("sound/items/suitchargeok1.wav", RESOURCE_TYPE_SOUND)
				}

				// Not all maps need the train use sound. Block in default config and unblock here if func_traintrack exists
				else if (equal(sValue, "func_tracktrain"))
				{
					RemoveFromBlockList("sound/plats/train_use1.wav", RESOURCE_TYPE_SOUND)
				}

				// Not all maps have items, e.g. flags, keys, etc. But the sound is precached on all, so block and handle map specifics here
				else if (equal(sValue, "item_tfgoal")) 
				{
					RemoveFromBlockList("sound/items/itembk2.wav", RESOURCE_TYPE_SOUND)
				}

				// Precached by default on every map, but barely used. Block in default config and unblock here if used.
				else if (equal(sValue, "item_suit"))
				{
					RemoveFromBlockList("models/w_suit.mdl", RESOURCE_TYPE_MODEL)
				}

				// Precached by default on every map, but barely used. Block in default config and unblock here if used.
				else if (equal(sValue, "item_battery"))
				{
					RemoveFromBlockList("models/w_battery.mdl", RESOURCE_TYPE_MODEL)
					RemoveFromBlockList("sound/items/gunpickup2.wav", RESOURCE_TYPE_SOUND)
				}

				// Precached by default on every map, but barely used. Block in default config and unblock here if used.
				else if (equal(sValue, "item_antidote"))
				{
					RemoveFromBlockList("models/w_antidote.mdl", RESOURCE_TYPE_MODEL)
				}

				// Precached by default on every map, but barely used. Block in default config and unblock here if used.
				else if (equal(sValue, "item_security"))
				{
					RemoveFromBlockList("models/w_security.mdl", RESOURCE_TYPE_MODEL)
				}

				// Precached by default on every map, but barely used. Block in default config and unblock here if used.
				else if (equal(sValue, "item_longjump"))
				{
					RemoveFromBlockList("models/w_longjump.mdl", RESOURCE_TYPE_MODEL)
				}
				
				// Precached by default on every map. But this and armor are not used heavily in the types of maps that need precache blocking
				// i.e. Escape maps with civilian only. Block in default config and unblock here if used.
				else if (equal(sValue, "item_healthkit"))
				{
					RemoveFromBlockList("models/w_medkit.mdl", RESOURCE_TYPE_MODEL)
					RemoveFromBlockList("sound/items/smallmedkit1.wav", RESOURCE_TYPE_SOUND) // Touch Sound
					RemoveFromBlockList("sound/items/suitchargeok1.wav", RESOURCE_TYPE_SOUND) // Respawn sound
				}

				else if (equal(sValue, "item_armor", 10)) 
				{
					// item_armor1, item_armor2, item_armor3 (Green, Yellow, Red)
					switch (str_to_num(sValue[10]))
					{
						case 1: RemoveFromBlockList("models/g_armor.mdl", RESOURCE_TYPE_MODEL)
						case 2: RemoveFromBlockList("models/y_armor.mdl", RESOURCE_TYPE_MODEL)
						case 3: RemoveFromBlockList("models/r_armor.mdl", RESOURCE_TYPE_MODEL)
					}
					RemoveFromBlockList("sound/items/armoron_1.wav", RESOURCE_TYPE_SOUND) // Touch Sound
					RemoveFromBlockList("sound/items/suitchargeok1.wav", RESOURCE_TYPE_SOUND) // Respawn sound
				}
				else
				{
					// Some escape maps spawn weapons which the civilian class can pickup. Catch that here and unblock as required
					for (new i = 0; i < NUM_WEAPON_BLOCKS; i++)
					{
						if (equali(sValue, g_sValidWeaponBlocks[i]))
						{
							// Remove from the blocklist so we don't block any of it's precache
							new sPath[128]; formatex(sPath, charsmax(sPath), "%s/%s.ini", g_sPrecacheDir, g_sValidWeaponBlocks[i])
							ReadPrecacheFile(sPath, READ_WHITELIST)

							// Make sure the pickup sound is not blocked
							RemoveFromBlockList("sound/items/gunpickup2.wav", RESOURCE_TYPE_SOUND)

							// Allow the deployment of the weapon
							AllowWeaponDeploy(g_sValidWeaponBlocks[i]) 						
						}
					}
				}
			}
			// func_breakable & func_pushable "material" key used for soundfx. Nothing else shares this key
			// TFC precaches wood and glass debris sounds every map. Lets block in default config and handle the unblock here
			else if (equal(sKey, "material")) 
			{
				new iValue = str_to_num(sValue)
				if (iValue == matComputer || iValue == matUnbreakableGlass || iValue == matGlass)
				{
					RemoveFromBlockList("sound/debris/glass1.wav", RESOURCE_TYPE_SOUND)
					RemoveFromBlockList("sound/debris/glass2.wav", RESOURCE_TYPE_SOUND)
					RemoveFromBlockList("sound/debris/glass3.wav", RESOURCE_TYPE_SOUND)
				}
				else if (iValue == matWood) 
				{
					RemoveFromBlockList("sound/debris/wood1.wav", RESOURCE_TYPE_SOUND)
					RemoveFromBlockList("sound/debris/wood2.wav", RESOURCE_TYPE_SOUND)
					RemoveFromBlockList("sound/debris/wood3.wav", RESOURCE_TYPE_SOUND)
				}

				// Finally, unblock the gib model since we block it in the engineer class config (buildables break)
				if (iValue == matComputer)
				{
					RemoveFromBlockList("models/computergibs.mdl", RESOURCE_TYPE_MODEL)
				}
			}
			// TFC shares keys, so the keys used for class restrictions aren't unique to the info_tfdetect entity.
			// We can't be sure that we're working with the keys for an info_tfdetect because "classname" could be the last key.
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
						bClassLimitDone = true // Lets end it all... it's pointless to parse any more now.
						iClassRestrictionValue = 0 // Mark all classes as valid
					}
					default: // Other class limit TODO: Handle this after all the keys are processed to avoid reading files that have already been read.
					{
						fm_DebugPrintLevel(3, "iClassRestrictionValue: %d iValue: %d (iClassRestrictionValue & iValue): %d", iClassRestrictionValue, iValue, iClassRestrictionValue & iValue)
						iClassRestrictionValue &= iValue
					}
				}
				bClassKeyParsed = true
			}
			else if (equal(sKey, "invincible_finished"))
			{
				RemoveFromBlockList("sound/items/protect.wav", RESOURCE_TYPE_SOUND)
 				RemoveFromBlockList("sound/items/protect2.wav", RESOURCE_TYPE_SOUND)
				RemoveFromBlockList("sound/items/protect3.wav", RESOURCE_TYPE_SOUND)
			}
			else if (equal(sKey, "invisible_finished"))
			{
				RemoveFromBlockList("sound/items/inv1.wav", RESOURCE_TYPE_SOUND)
 				RemoveFromBlockList("sound/items/inv2.wav", RESOURCE_TYPE_SOUND)
				RemoveFromBlockList("sound/items/inv3.wav", RESOURCE_TYPE_SOUND)
			}
			else if (equal(sKey, "super_damage_finished"))
			{
				RemoveFromBlockList("sound/items/damage.wav", RESOURCE_TYPE_SOUND)
 				RemoveFromBlockList("sound/items/damage2.wav", RESOURCE_TYPE_SOUND)
				RemoveFromBlockList("sound/items/damage3.wav", RESOURCE_TYPE_SOUND)
			}
			else if (equal(sKey, "radsuit_finished"))
			{
 				RemoveFromBlockList("sound/FVox/HEV_logon.wav", RESOURCE_TYPE_SOUND)
				RemoveFromBlockList("sound/FVox/hev_shutdown.wav", RESOURCE_TYPE_SOUND)
			}
			else if (equal(sKey, "replacement_model")) // item_tfgoal allows the player model to be replaced. Make sure we whitelist it
			{
				new sBuffer[128]; formatex(sBuffer, charsmax(sBuffer), "models/player/%s/%s.mdl", sValue, sValue)
				RemoveFromBlockList(sBuffer, RESOURCE_TYPE_MODEL)			
			}
			else
			{
				// Check the end of the value info to see if it matches a file extension. There's a chance for false positives here, but this is the easiest method.
				// Since sounds are often stored in the shared "message" key anyway. And models often appear in different keys. "mdl", "model", "gibmodel", etc
				new iType = GetResourceType(sValue)
				if (iType != -1)
				{
					fm_DebugPrintLevel(3, "Line %d of %s entdata is a resource: \"%s\"", iLine, sMap, sValue)
					remove_quotes(sValue)
					new sBuffer[128]; formatex(sBuffer, charsmax(sBuffer), "%s%s", iType == RESOURCE_TYPE_SOUND ? "sound/" : "", sValue)
					RemoveFromBlockList(sBuffer, iType)
				}
			}
		}
		else
		{
			fm_WarningLog("Error parsing line %d of %s entdata", iLine, sMap)
		}
	}

	if (!bDetectEntFound)
	{
		return 0
	}
	return 1
}

RemoveFromBlockList(sFile[], iType)
{
	if (fm_RemoveFromSortedList(g_ResourceBlockList[iType], sFile[iType == RESOURCE_TYPE_SOUND ? 6 : 0]))
	{
		fm_DebugPrintLevel(2, "Removed: \"%s\" from blocklist (%d)", sFile[iType == RESOURCE_TYPE_SOUND ? 6 : 0], iType)
		g_iResourceCount[iType]--
		return 1
	}
	return 0
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

	new iLine, sData[MAX_RESOURCE_LEN] // This is 64. But if this is too high we end up with a stack error due to the recurssion with @import. We should be OK with the current config

	while (!feof(iFileHandle))
	{
		iLine++
		fgets(iFileHandle, sData, charsmax(sData))
		trim(sData)
		//fm_DebugPrintLevel(1, "Line %d of \"%s\": \"%s\"", iLine, sFile, sData)

		if(!sData[0] || sData[0] == ';' || sData[0] == '#' || equal(sData, "//", 2)) 
		{
			continue
		}

		if (sData[0] == '@')
		{
			if (equali(sData[1], "import ", 7))
			{
				new iPos = contain(sData[8], ".") // BUGBUG: Asummes only a single . is ever contained (for the file ext)
				if (iPos == -1)
				{
					iPos = 0
				}

				// If the file to read is a weapon make and we're whitelisting, make sure we unblock the weapon deploy
				for (new i = 0; i < NUM_WEAPON_BLOCKS; i++)
				{
					if (equali(sData[8], g_sValidWeaponBlocks[i], iPos - 1))
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
					fm_DebugPrintLevel(2, "Adding: \"%s\" to blacklist (%d)", sData[iType == RESOURCE_TYPE_SOUND ? 6 : 0], iType)
					if (fm_InsertIntoSortedList(g_ResourceBlockList[iType], sData[iType == RESOURCE_TYPE_SOUND ? 6 : 0]))
					{
						fm_DebugPrintLevel(2, "Added: \"%s\" to blacklist (%d)", sData[iType == RESOURCE_TYPE_SOUND ? 6 : 0], iType)
						g_iResourceCount[iType]++
					}
				}
				else // Assume type whitelist
				{
					fm_DebugPrintLevel(2, "Removing: \"%s\" from blacklist (%d)", sData, iType)
					RemoveFromBlockList(sData, iType)
				}
			}
			else
			{
				fm_WarningLog("Error reading \"%s\" Line #%d. Not a file: \"%s\"", sFile, iLine, sData)
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
		return RESOURCE_TYPE_SOUND
	}
	else if (equali(sFile[iExt], "mdl") || equali(sFile[iExt], "spr"))
	{
		return RESOURCE_TYPE_MODEL
	}
	return RESOURCE_TYPE_GENERIC						
}

WritePrecaceLogFile(sFile[])
{
	new iFileHandle = fopen(sFile, "wt")
	if (!iFileHandle)
	{
		fm_WarningLog(FM_FOPEN_WARNING, sFile)	
		return 0
	}

	new sResource[MAX_RESOURCE_LEN]
	for (new i = 0; i < RESOURCE_TYPE_NUM; i++)
	{	
		for (new j = 0; j < g_iResourceCount[i]; j++)
		{
			ArrayGetString(g_ResourceBlockList[i], j, sResource, charsmax(sResource))
			fprintf(iFileHandle, "%s%s\n", i == RESOURCE_TYPE_SOUND ? "sound/" : "", sResource)
		}
	}
	fclose(iFileHandle)
	return 1
}

// The "sound/" directory at the start of the string is assumed by PrecacheSound and not included in the path
public Forward_PrecacheSound(sFile[])
{
	if (fm_BinarySearch(Array:g_ResourceBlockList[RESOURCE_TYPE_SOUND], sFile, 0, g_iResourceCount[RESOURCE_TYPE_SOUND] - 1) != -1)
	{
		fm_DebugPrintLevel(2, "Blocked precache for file: \"sound/%s\"", sFile)
		return FMRES_SUPERCEDE
	}

	fm_DebugPrintLevel(2, "Allowed precache for file: \"sound/%s\"", sFile)
	return FMRES_IGNORED
}

public Forward_PrecacheModel(sFile[])
{
	if (fm_BinarySearch(Array:g_ResourceBlockList[RESOURCE_TYPE_MODEL], sFile, 0, g_iResourceCount[RESOURCE_TYPE_MODEL] - 1) != -1)
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
	if (fm_BinarySearch(Array:g_ResourceBlockList[RESOURCE_TYPE_GENERIC], sFile, 0, g_iResourceCount[RESOURCE_TYPE_GENERIC] - 1, 0) != -1)
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
	fm_DebugPrintLevel(2, "Forward_EmitSound: \"sound/%s\"", sSound) 
	if (fm_BinarySearch(Array:g_ResourceBlockList[RESOURCE_TYPE_SOUND], sSound, 0, g_iResourceCount[RESOURCE_TYPE_SOUND] - 1, 0) != -1)
	{
		new sClassName[32]
		if (pev_valid(iEnt))
		{
			pev(iEnt, pev_classname, sClassName, charsmax(sClassName))
		}

		fm_WarningLog("Blocked EmitSound for classname: \"%s\" on map \"%s\" for file: \"sound/%s\"", sClassName, g_sCurrentMap, sSound)	
		return FMRES_SUPERCEDE
	}
	return FMRES_IGNORED
}

public Forward_EmitAmbientSound(iEnt, iChannel, sSound[])
{	
	fm_DebugPrintLevel(2, "Forward_EmitAmbientSound: \"sound/%s\"", sSound) 
	if (fm_BinarySearch(Array:g_ResourceBlockList[RESOURCE_TYPE_SOUND], sSound, 0, g_iResourceCount[RESOURCE_TYPE_SOUND] - 1, 0) != -1)
	{
		new sClassName[32]
		if (pev_valid(iEnt))
		{
			pev(iEnt, pev_classname, sClassName, charsmax(sClassName))
		}

		fm_WarningLog("Blocked EmitAmbientSound for classname: \"%s\" on map \"%s\" for file: \"sound/%s\"", sClassName, g_sCurrentMap, sSound)
		return FMRES_SUPERCEDE
	}
	return FMRES_IGNORED
}


/*public OrpheuHookReturn:Forward_LookupSoundIndex(const sSound[])
{
	if (fm_BinarySearch(Array:g_ResourceBlockList[RESOURCE_TYPE_SOUND], sSound, 0, g_iResourceCount[RESOURCE_TYPE_SOUND] - 1, 0) != -1)
	{
		fm_WarningLog("SV_LookupSoundIndex was called for blocked sound: %s", sSound)
	}
}*/

public Forward_SetModel(iEnt, sModel[])
{	
	fm_DebugPrintLevel(2, "Forward_SetModel: \"%s\"", sModel) 
	if (fm_BinarySearch(Array:g_ResourceBlockList[RESOURCE_TYPE_MODEL], sModel, 0, g_iResourceCount[RESOURCE_TYPE_MODEL] - 1, 0) != -1)
	{
		new sClassName[32]
		if (pev_valid(iEnt))
		{
			pev(iEnt, pev_classname, sClassName, charsmax(sClassName))
		}
		
		fm_WarningLog("Blocked SetModel for classname: \"%s\" on map \"%s\" for model file \"%s\"", sClassName, g_sCurrentMap, sModel)
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
	fm_DebugPrintLevel(1, "AllowWeaponDeploy: %s", sWeapon)

	new iIndex = GetWeaponBlockIndex(sWeapon)
	if (iIndex != -1 && g_iWeaponBlockHandles[iIndex])
	{
		DisableHamForward(g_iWeaponBlockHandles[iIndex])
		return 1
	}
	return 0
}

BlockWeaponDeploy(sWeapon[])
{
	fm_DebugPrintLevel(1, "BlockWeaponDeploy: %s", sWeapon)

	new iIndex = GetWeaponBlockIndex(sWeapon)
	if (iIndex != -1)
	{
		// Check if the weapon deploy hook has already been created. If not, create it. Else just ensure we didn't disable it.
		if (!g_iWeaponBlockHandles[iIndex])
		{
			g_iWeaponBlockHandles[iIndex] = RegisterHam(Ham_Item_CanDeploy, g_sValidWeaponBlocks[iIndex], "Forward_HamCanDeploy")
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
	fm_WarningLog("Blocked weapon deployment! Check precache files for %s", g_sCurrentMap)

	// Return 0 and SUPERCEDE so the weapon is not deployed
	SetHamReturnInteger(0)
	return HAM_SUPERCEDE
}

#if defined PRECACHE_TEST
public Forward_CreateEntity()
{
	static iEnt; iEnt = get_orig_retval()
	fm_DebugPrintLevel(1, "Forward_CreateEntity(%d)", iEnt)
}

public Forward_CreateNamedEntity_Post(iClassName)
{
	static iEnt, sClassName[32]
	iEnt = get_orig_retval()
	engfunc(EngFunc_SzFromIndex, iClassName, sClassName, charsmax(sClassName))
	fm_DebugPrintLevel(1, "Forward_CreateNamedEntity_Post(%d): Classname: \"%s\"", iEnt, sClassName)
}

public Forward_Spawn(iEnt)
{
	fm_DebugPrintLevel(1, "Forward_Spawn(%d)", iEnt)
}

public Forward_KeyValue(iEnt, Kvd)
{
	static sKey[32]; sKey[0] = 0;
	static sValue[128]; sValue[0] = 0;
	get_kvd(Kvd, KV_KeyName, sKey, charsmax(sKey))	
	get_kvd(Kvd, KV_Value, sValue, charsmax(sValue))
	fm_DebugPrintLevel(1, "Forward_KeyValue(%d, {Key: \"%s\" Value: \"%s\"})", iEnt, sKey, sValue)
}

public Forward_RemoveEntity(iEnt)
{
	fm_DebugPrintLevel(1, "Forward_RemoveEntity(%d)", iEnt)
}

public Forward_ModelIndex(sModel[])
{
	fm_DebugPrintLevel(2, "Forward_ModelIndex: \"%s\"", sModel) 
}
#endif