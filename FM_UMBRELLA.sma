#include "feckinmad/fm_global"
#include "feckinmad/fm_donator_api"

#include <fakemeta>
#include <hamsandwich>

#define PC_CIVILIAN 11
#define WEAPON_AXE 5
#define TOGGLE_DELAY 1.0
#define DONATION_AMOUNT 5

new const g_sClassLimitKeys[][] =
{
	"maxammo_shells",
	"maxammo_nails",
	"maxammo_rockets",
	"maxammo_cells"
}

new const g_sGoldPlayerModel[] = "models/fm/p_goldumbrella.mdl"
new const g_sGoldViewModel[] = "models/fm/v_goldumbrella2.mdl"
new const g_sNormalPlayerModel[] = "models/p_umbrella.mdl"
new const g_sNormalViewModel[] = "models/fm/v_umbrella.mdl"


new bool:g_bPlayerShowGolden[MAX_PLAYERS + 1] = { true, ... } // Whether the player wants to show it
new bool:g_bPlayerUmbrellaDeployed[MAX_PLAYERS + 1] = { false, ... }

new Float:g_fPlayerNextChange[MAX_PLAYERS + 1] // Store next toggle time to prevent spam
new bool:g_bEnabled, g_iKeyValueForward

new g_pCvarAlwaysEnable

public plugin_precache()
{
	g_pCvarAlwaysEnable = register_cvar("fm_umbrella_selective", "0")

	if (get_pcvar_num(g_pCvarAlwaysEnable) == 1)
		g_iKeyValueForward = register_forward(FM_KeyValue, "Forward_KeyValue")
	else
		PrecacheModels()

	return PLUGIN_CONTINUE
}

public Forward_KeyValue(iEnt, Kvd)
{
	if (!pev_valid(iEnt)) 
		return FMRES_IGNORED

	static sBuffer[32]; get_kvd(Kvd, KV_ClassName, sBuffer, charsmax(sBuffer))
	static bool:bDetect

	if (!equal(sBuffer, "info_tfdetect"))
	{
		// Unregister the forward since we are no longer recieving keys from the info_tfdetect ent
		if (bDetect) 
			UnregisterKeyValueForward()
		return FMRES_IGNORED
	}
		
	bDetect = true
	get_kvd(Kvd, KV_KeyName, sBuffer, charsmax(sBuffer))
	for (new i = 0; i < sizeof g_sClassLimitKeys; i++)
	{	
		if (!equal(sBuffer, g_sClassLimitKeys[i]))
			return FMRES_IGNORED

		get_kvd(Kvd, KV_Value,  sBuffer, charsmax(sBuffer))
		if (str_to_num(sBuffer) != -1)
			return FMRES_IGNORED

		PrecacheModels()

		UnregisterKeyValueForward()
	}

	return FMRES_IGNORED
}

PrecacheModels()
{
	g_bEnabled = true

	engfunc(EngFunc_PrecacheModel, g_sGoldPlayerModel)
	engfunc(EngFunc_PrecacheModel, g_sGoldViewModel)
	engfunc(EngFunc_PrecacheModel, g_sNormalPlayerModel)
	engfunc(EngFunc_PrecacheModel, g_sNormalViewModel)
}

public plugin_init() 
{
	fm_RegisterPlugin()

	if (g_iKeyValueForward)
		UnregisterKeyValueForward()

	if (g_bEnabled)
	{
		RegisterHam(Ham_Use, "player_weaponstrip", "Handle_WeaponStripUse") // Targetting spawns
		register_event("CurWeapon", "Event_Weapon", "be", "1=1") // Register CurWeapon event for alive players
		register_concmd("fm_togglegold", "Toggle_Umbrella") // Allow players to turn off/on their golden umbrella if they wish
	}	
}

// Note: This is spammed to shit on some maps where the weaponstrip is targeted from touching a trigger
public Handle_WeaponStripUse(iEnt, iCaller, iActivator, iType, Float:fValue)
{
	if (1 <= iCaller <= MAX_PLAYERS)
		g_bPlayerUmbrellaDeployed[iCaller] = false
}

public Event_Weapon(id)
{	
	if (read_data(2) == WEAPON_AXE && pev(id, pev_playerclass) == PC_CIVILIAN)
	{	
		fm_DebugPrintLevel(1, "Event_Weapon(%d)", id)
		g_bPlayerUmbrellaDeployed[id] = true

		if (CheckPlayerDonation(id) && g_bPlayerShowGolden[id])
			SetWeaponModel(id, g_sGoldViewModel, g_sGoldPlayerModel)
		else
			SetWeaponModel(id, g_sNormalViewModel, g_sNormalPlayerModel)
	}
	else 
		g_bPlayerUmbrellaDeployed[id] = false
}

public Toggle_Umbrella(id)
{
	fm_DebugPrintLevel(1, "Toggle_Umbrella")
	
	if (!CheckPlayerDonation(id))
		console_print(id, "* You don't have a golden umbrella")
	else if (g_fPlayerNextChange[id] > get_gametime())
		console_print(id, "* You can't toggle your umbrella that quickly")
	else
	{	
		g_bPlayerShowGolden[id] = g_bPlayerShowGolden[id] ? false : true
		
		// If they have it out right now we need to change it
		if (pev(id, pev_playerclass) == PC_CIVILIAN && is_user_alive(id) && g_bPlayerUmbrellaDeployed[id])  
			SetWeaponModel(id, g_bPlayerShowGolden[id] ? g_sGoldViewModel : g_sNormalViewModel, g_bPlayerShowGolden[id] ? g_sGoldPlayerModel : g_sNormalPlayerModel)

		console_print(id, "* Your golden umbrella will now be %s", g_bPlayerShowGolden[id] ? "visible" : "hidden")
		g_fPlayerNextChange[id]  = get_gametime() + TOGGLE_DELAY
	}
	return PLUGIN_HANDLED
}

SetWeaponModel(id, const sViewModel[], const sPlayerModel[])
{
	set_pev(id, pev_weaponmodel2, sPlayerModel)
	set_pev(id, pev_viewmodel2, sViewModel)
}

UnregisterKeyValueForward()
{
	unregister_forward(FM_KeyValue, g_iKeyValueForward)
	g_iKeyValueForward = 0
}

CheckPlayerDonation(id)
	return fm_GetPlayerDonation(id) >= DONATION_AMOUNT ? true : false

public client_disconnect(id)
{
	g_bPlayerShowGolden[id] = true
	g_fPlayerNextChange[id] = 0.0
	g_bPlayerUmbrellaDeployed[id] = false
}

public fm_ScreenMessage(sBuffer[], iSize)
{
	new iMaxPlayers = get_maxplayers()
	new iGoldUsers[MAX_PLAYERS + 1], iGoldUsersCount = 0

	for (new i = 1; i <= iMaxPlayers; i++)
	{
		if (g_bPlayerUmbrellaDeployed[i] && g_bPlayerShowGolden[i])
		{
			iGoldUsers[iGoldUsersCount] = i
			iGoldUsersCount++
		}
	}
	
	if (iGoldUsersCount <= 0)
	{
		formatex(sBuffer, iSize, "Donate £5 and recieve a golden umbrella. (Brand new without tags)")
	}
	else
	{
		new id = iGoldUsers[random(iGoldUsersCount)]
		new sName[MAX_NAME_LEN]; get_user_name(id, sName, charsmax(sName))

		switch(random(3))
		{
			case 0: formatex(sBuffer, iSize, "Hey %s, what do you use to keep that umbrella so shiny?", sName)
			case 1: formatex(sBuffer, iSize, "Hold onto that golden umbrella %s, this is a rough neighbourhood", sName)
			default:
			{
				formatex(sBuffer, iSize, "Wow %s, that sure is a nice golden umbrella", sName)
			}
	
		}
		
	}
}