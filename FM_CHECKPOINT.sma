#include "feckinmad/fm_global"
#include "feckinmad/fm_admin_access"
#include "feckinmad/fm_precache"
#include "feckinmad/fm_time"
#include "feckinmad/fm_mapfunc"
#include "feckinmad/fm_speedrun_api"

#include <fakemeta> 
#include <hamsandwich>

#define MAX_LAST_CHECKS 8
#define MAX_STATUSTEXT_LENGTH 128 // hud.h

new const Float:g_fLoadDelay = 1.0
new const Float:g_fSaveDelayMuliplier = 1.0
new const Float:g_fHUDRefreshRate = 0.11

new const g_sCheckMapsFile[] = "fm_checkpoint_maps.ini"
new const g_sCheckHelpFile[] = "help/fm_checkpointing.txt"
new const g_sCheckHelpTitle[] = "Checkpoint Help"

new const g_sTextDisabled[] = "* Checkpointing is currently disabled"
new const g_sTextDead[] = "* You cannot use that checkpoint command while dead"
new const g_sTextSpectate[] = "* You cannot use that checkpoint command while in spectate"
new const g_sTextEnable[] = "enabled"
new const g_sTextDisable[] = "disabled"

new bool:g_bCheckAllow
new bool:g_bSpeedRunPluginExists
new const g_sSpeedRunErrorMessage[] = "* You can't load a checkpoint whilst speedrunning. Type /stop to cancel your speedurun"

new g_sCheckHelpPath[128]

new Float:g_fPlayerCheckOrigin[MAX_PLAYERS+ 1][MAX_LAST_CHECKS][3]
new Float:g_fPlayerCheckAim[MAX_PLAYERS+ 1][MAX_LAST_CHECKS][3]
new g_iPlayerLastCheckPos[MAX_PLAYERS + 1]

new g_iPlayerSaveCount[MAX_PLAYERS + 1]
new g_iPlayerLoadCount[MAX_PLAYERS + 1]

new Float:g_fPlayerNextLoad[MAX_PLAYERS + 1]
new Float:g_fPlayerNextSave[MAX_PLAYERS + 1]

new g_iEnt, g_iMaxPlayers, g_MsgStatusText, g_MsgScreenFade
new HamHook:g_iDamageHandle
new Array:g_aPlayerCheckBackup

enum ePlayerCheckPointBackup_t
{
	m_sPlayerAuthid[MAX_AUTHID_LEN],

	Float:m_fPlayerCheckOriginX[MAX_LAST_CHECKS],
	Float:m_fPlayerCheckOriginY[MAX_LAST_CHECKS],
	Float:m_fPlayerCheckOriginZ[MAX_LAST_CHECKS],

	Float:m_fPlayerCheckAimX[MAX_LAST_CHECKS],
	Float:m_fPlayerCheckAimY[MAX_LAST_CHECKS],
	Float:m_fPlayerCheckAimZ[MAX_LAST_CHECKS],

	m_iPlayerSaveCount,
	m_iPlayerLoadCount,

	Float:m_fPlayerNextLoad,
	Float:m_fPlayerNextSave
}

enum
{
	SOUND_LOAD,
	SOUND_SAVE,
	SOUND_ERROR,
	SOUND_LOADREADY,
	SOUND_SAVEREADY,
	SOUND_STATS,
	SOUND_COUNT
}

new const g_sCheckSound[SOUND_COUNT][] = 
{
	"fm/load.wav",
	"fm/save.wav",
	"fm/error.wav",
	"fm/ready.wav",
	"fm/ready2.wav",
	"fm/stats.wav"
}

public plugin_init() 
{
	fm_RegisterPlugin()

	g_MsgScreenFade = get_user_msgid("ScreenFade")
	g_MsgStatusText = get_user_msgid("StatusText")
	g_iMaxPlayers = get_maxplayers()

	register_clcmd("say", "Handle_Say")
	register_clcmd("say_team", "Handle_Say")

	g_aPlayerCheckBackup = ArrayCreate(ePlayerCheckPointBackup_t)

	if (LibraryExists(g_sAdminAccessLibName, LibType_Library))
	{
		register_concmd("admin_checkpoint", "Admin_Checkpoint", ADMIN_HIGHER)
	}

	if (LibraryExists(g_sSpeedRunAPILibName, LibType_Library))
	{
		g_bSpeedRunPluginExists = true
	}
}


public plugin_natives()
{
	set_module_filter("Module_Filter")
	set_native_filter("Native_Filter")
}

public Module_Filter(sModule[])
{
	if (equal(sModule, g_sAdminAccessLibName) || equal(sModule, g_sSpeedRunAPILibName))
	{
		return PLUGIN_HANDLED
	}
	return PLUGIN_CONTINUE
}

public Native_Filter(sName[], iIndex, iTrap)
{
	if (!iTrap)
	{
		return PLUGIN_HANDLED
	}
	return PLUGIN_CONTINUE
}

public Handle_Say(id)
{
	new sArgs[32]; read_args(sArgs, charsmax(sArgs))
	remove_quotes(sArgs)
	
	if (equali(sArgs, "/s"))
	{
		CheckSave(id)
		return PLUGIN_HANDLED
	}


	if (equali(sArgs, "/l"))
	{
		CheckLoad(id)
		return PLUGIN_HANDLED
	}

	if (equali(sArgs, "check ", 6))
	{
		if (equali(sArgs[6], "save"))
		{
			CheckSave(id) 
		}
		else if (equali(sArgs[6], "load"))
		{
			CheckLoad(id) 
		}
		else if (equali(sArgs[6], "last"))
		{
			CheckLast(id) 
		}
		else if (equali(sArgs[6], "stats"))
		{
			CheckStats(id) 
		}
		else if (equali(sArgs[6], "reset"))
		{
			ResetPlayerCheckData(id)
			dllfunc(DLLFunc_ClientKill, id)
		}
		else if (equali(sArgs[6], "help") || equali(sArgs, "saveme") || equali(sArgs, "posme"))
		{
			show_motd(id, g_sCheckHelpPath, g_sCheckHelpTitle)
		}
		else
		{
			return PLUGIN_CONTINUE
		}
		return PLUGIN_HANDLED		
	}

	return PLUGIN_CONTINUE
}

public plugin_precache()
{	
	fm_BuildAMXFilePath(g_sCheckHelpFile, g_sCheckHelpPath, charsmax(g_sCheckHelpPath), "amxx_configsdir")

	new sFile[128]; fm_BuildAMXFilePath(g_sCheckMapsFile, sFile, charsmax(sFile), "amxx_configsdir")
	new sCurrentMap[MAX_MAP_LEN]; get_mapname(sCurrentMap, charsmax(sCurrentMap))

	if (fm_IsMapNameInFile(sCurrentMap, sFile) == 1)
	{	
		InitCheckpointing()

		for (new i = 0; i < SOUND_COUNT; i++)
		{
			fm_SafePrecacheSound(g_sCheckSound[i])
		}		
	}
}

InitCheckpointing()
{
	g_bCheckAllow = true
	CreateCheckEnt()

	if (!g_iDamageHandle)
	{
		g_iDamageHandle = RegisterHam(Ham_TakeDamage, "player", "PlayerTakeDamage")
	}
	else
	{
		EnableHamForward(g_iDamageHandle)
	}
}

ShutDownCheckpointing()
{
	g_bCheckAllow = false
	RemoveCheckEnt()

	if (g_iDamageHandle)
	{
		DisableHamForward(g_iDamageHandle)
		g_iDamageHandle = HamHook:0
	}
}

// Block all fall damage to players
public PlayerTakeDamage(id, iInflictor, iAttacker, Float:fDamage, iDamageBits)
{
	if ((iDamageBits & DMG_FALL) && !iInflictor) // Still allow trigger_hurts with fall damage bit set!
	{
		return HAM_SUPERCEDE
	}
	return HAM_IGNORED
}	

public client_connect(id)
{
	ResetPlayerCheckData(id)
}

public client_authorized(id)
{
	LoadPlayerCheckData(id)
}

public client_disconnected(id)
{
	SavePlayerCheckData(id)
	ResetPlayerCheckData(id)
}

LoadPlayerCheckData(id)
{
	new Buffer[ePlayerCheckPointBackup_t]
	new sAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAuthid, charsmax(sAuthid))

	for (new i = 0; i < ArraySize(g_aPlayerCheckBackup); i++)
	{
		ArrayGetArray(g_aPlayerCheckBackup, i, Buffer)
		if (!equal(Buffer[m_sPlayerAuthid], sAuthid))
		{
			continue
		}
		
		for (new j = 0;j < MAX_LAST_CHECKS; j++)
		{
			g_fPlayerCheckOrigin[id][j][0] = Buffer[m_fPlayerCheckOriginX][j]
			g_fPlayerCheckOrigin[id][j][1] = Buffer[m_fPlayerCheckOriginY][j]
			g_fPlayerCheckOrigin[id][j][2] = Buffer[m_fPlayerCheckOriginZ][j]
		
			g_fPlayerCheckAim[id][j][0] = Buffer[m_fPlayerCheckAimX][j]
			g_fPlayerCheckAim[id][j][1] = Buffer[m_fPlayerCheckAimY][j]
			g_fPlayerCheckAim[id][j][2] = Buffer[m_fPlayerCheckAimZ][j]
		}

		g_iPlayerSaveCount[id] = Buffer[m_iPlayerSaveCount] 
		g_iPlayerLoadCount[id] = Buffer[m_iPlayerLoadCount]
		g_fPlayerNextLoad[id] = Buffer[m_fPlayerNextLoad] 
		g_fPlayerNextSave[id] = Buffer[m_fPlayerNextSave]
		
		ArrayDeleteItem(g_aPlayerCheckBackup, i)

		break		
	}
}

SavePlayerCheckData(id)
{
	new Buffer[ePlayerCheckPointBackup_t]
	get_user_authid(id, Buffer[m_sPlayerAuthid], MAX_AUTHID_LEN - 1)

	for (new i = 0;i < MAX_LAST_CHECKS; i++)
	{
		Buffer[m_fPlayerCheckOriginX][i] = _:g_fPlayerCheckOrigin[id][i][0]
		Buffer[m_fPlayerCheckOriginY][i] = _:g_fPlayerCheckOrigin[id][i][1]
		Buffer[m_fPlayerCheckOriginZ][i] = _:g_fPlayerCheckOrigin[id][i][2]
		
		Buffer[m_fPlayerCheckAimX][i] = _:g_fPlayerCheckAim[id][i][0]
		Buffer[m_fPlayerCheckAimY][i] = _:g_fPlayerCheckAim[id][i][1]
		Buffer[m_fPlayerCheckAimZ][i] = _:g_fPlayerCheckAim[id][i][2]
	}

	Buffer[m_iPlayerSaveCount] = g_iPlayerSaveCount[id]
	Buffer[m_iPlayerLoadCount] = g_iPlayerLoadCount[id]
	Buffer[m_fPlayerNextLoad] = _:g_fPlayerNextLoad[id]
	Buffer[m_fPlayerNextSave] = _:g_fPlayerNextSave[id]

	ArrayPushArray(g_aPlayerCheckBackup, Buffer)
}

ResetPlayerCheckData(id)
{
	for (new i = 0; i < MAX_LAST_CHECKS - 1; i++)
	{
		for (new j = 0; j < 3; j++)
		{
			g_fPlayerCheckOrigin[id][i][j] = 0.0
			g_fPlayerCheckAim[id][i][j] = 0.0
		}
	}

	g_iPlayerLastCheckPos[id] = 0

	g_iPlayerSaveCount[id] = 0
	g_iPlayerLoadCount[id] = 0

	g_fPlayerNextLoad[id] = 0.0
	g_fPlayerNextSave[id] = 0.0
}

CreateCheckEnt()
{
	g_iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target")) 
	if (!g_iEnt)
	{
		fm_WarningLog(FM_ENT_WARNING)
	}
	else
	{
		register_forward(FM_Think, "Forward_Think")
		set_pev(g_iEnt, pev_nextthink, get_gametime() + g_fHUDRefreshRate)
	}		
}

RemoveCheckEnt()
{
	if (g_iEnt)
	{
		engfunc(EngFunc_RemoveEntity, g_iEnt)
		g_iEnt = 0
	}
}
public Forward_Think(iEnt)
{
	if (iEnt != g_iEnt)
	{
		return FMRES_IGNORED
	}

	static Float:fGameTime; fGameTime = get_gametime()
	
	for (new i = 1; i <= g_iMaxPlayers; i++)
	{
		if(!is_user_connected(i))
		{
			continue
		}

		if (g_fPlayerNextSave[i] != 0.0 && fGameTime > g_fPlayerNextSave[i])
		{
			fm_PlaySound(i, g_sCheckSound[SOUND_SAVEREADY])
			g_fPlayerNextSave[i] = 0.0
		}
		
		if (g_fPlayerNextLoad[i] != 0.0 && fGameTime > g_fPlayerNextLoad[i])
		{
			fm_PlaySound(i, g_sCheckSound[SOUND_LOADREADY])
			g_fPlayerNextLoad[i] = 0.0
		}

		if (g_iPlayerSaveCount[i] > 0)
		{
			CheckHUDMessage(i, fGameTime)
		}
		else
		{
			SetStatusText(i, "Type \"check help\" in chat for information on using checkpoints")
		}
	}

	set_pev(iEnt, pev_nextthink, fGameTime + g_fHUDRefreshRate)
	return FMRES_IGNORED
}

SetStatusText(id, sHUDMessage[])
{
	message_begin(MSG_ONE, g_MsgStatusText, {0,0,0}, id) 
	write_byte(1)
	write_string(sHUDMessage)
	message_end()
}


UpdateCheckHUD(id)
{
	if (g_bCheckAllow)
	{
		new Float:fGameTime = get_gametime()
		CheckHUDMessage(id, fGameTime)
	}
	else
	{
		SetStatusText(id, "")
	}
}

CheckHUDMessage(id, Float:fGameTime)
{
	static sHUDMessage[MAX_STATUSTEXT_LENGTH], Float:fSaveTime, Float:fLoadTime

	fSaveTime = g_fPlayerNextSave[id] - fGameTime
	fLoadTime = g_fPlayerNextLoad[id] - fGameTime
		
	formatex(sHUDMessage, charsmax(sHUDMessage),  "Checkpoints: Saves (%d) (%0.3f) - Loads (%d) (%0.3f)", g_iPlayerSaveCount[id], fSaveTime > 0.0 ? fSaveTime : 0.0, g_iPlayerLoadCount[id], fLoadTime > 0.0 ? fLoadTime : 0.0)
	SetStatusText(id, sHUDMessage)	
}


CheckStats(id) 
{
	if (!g_bCheckAllow) 
	{
		client_print(id, print_chat, g_sTextDisabled)
		fm_PlaySound(id, g_sCheckSound[SOUND_ERROR])
	}
	else
	{
		new sName[MAX_NAME_LEN]; get_user_name(id, sName, charsmax(sName))
		client_print(0, print_chat, "* %s has used %d checkpoint save(s) and %d checkpoint load(s)", sName, g_iPlayerSaveCount[id], g_iPlayerLoadCount[id])
		fm_PlaySound(id, g_sCheckSound[SOUND_STATS])
	}
}

CheckCommand(id)
{
	if (!g_bCheckAllow) 
	{
		client_print(id, print_chat, g_sTextDisabled)
		fm_PlaySound(id, g_sCheckSound[SOUND_ERROR])
		return 0
	}

	if (!pev(id, pev_team)) 
	{
		client_print(id, print_chat, g_sTextSpectate)
		fm_PlaySound(id, g_sCheckSound[SOUND_ERROR])
		return 0
	}

	if (!is_user_alive(id)) 
	{
		client_print(id, print_chat, g_sTextDead)
		fm_PlaySound(id, g_sCheckSound[SOUND_ERROR])
		return 0
	}
	return 1
}


CheckSave(id) 
{
	if (!CheckCommand(id))
	{
		return PLUGIN_HANDLED
	}

	new Float:fGameTime = get_gametime()
	if (g_fPlayerNextSave[id] > fGameTime)
	{
		new sTime[64]; fm_SecondsToText(floatround(g_fPlayerNextSave[id] - fGameTime, floatround_ceil), sTime, charsmax(sTime))
		client_print(id, print_chat, "* You must wait another %s before saving", sTime)
		fm_PlaySound(id, g_sCheckSound[SOUND_ERROR])

		return PLUGIN_HANDLED
	}

	for (new i = MAX_LAST_CHECKS - 1; i > 0; i--)
	{
		for (new j = 0; j < 3; j++)
		{
			g_fPlayerCheckOrigin[id][i][j] = g_fPlayerCheckOrigin[id][i - 1][j]
			g_fPlayerCheckAim[id][i][j] = g_fPlayerCheckAim[id][i - 1][j]
		}
	}

	if (g_iPlayerLastCheckPos[id] > 0)
	{
		g_iPlayerLastCheckPos[id]--
	}

	pev(id, pev_origin,  g_fPlayerCheckOrigin[id][0])
	pev(id, pev_v_angle, g_fPlayerCheckAim[id][0])	
	
	//CheckEcho(id)

	new iFlags = pev(id, pev_flags)
	if ((iFlags & FL_DUCKING) && (iFlags & FL_ONGROUND))
	{
		g_fPlayerCheckOrigin[id][0][2] += 40.0
	}

	g_iPlayerSaveCount[id]++
	g_fPlayerNextSave[id] = fGameTime + g_iPlayerSaveCount[id] * g_fSaveDelayMuliplier

	UpdateCheckHUD(id)
	
	client_print(id, print_center, "Saved checkpoint")
	fm_PlaySound(id, g_sCheckSound[SOUND_SAVE])

	return PLUGIN_HANDLED
}

CheckLoad(id) 
{
	if (!CheckCommand(id))
	{
		return PLUGIN_HANDLED
	}

	if (g_bSpeedRunPluginExists && fm_IsUserSpeedRunning(id))
	{
		client_print(id, print_chat, g_sSpeedRunErrorMessage)
		fm_PlaySound(id, g_sCheckSound[SOUND_ERROR])
		return PLUGIN_HANDLED	
	}

	if (!g_iPlayerSaveCount[id])
	{
		client_print(id, print_chat, "* You have not saved a checkpoint yet")
		fm_PlaySound(id, g_sCheckSound[SOUND_ERROR])
		return PLUGIN_HANDLED
	}

	new Float:fGameTime = get_gametime()
	if (g_fPlayerNextLoad[id] > fGameTime)
	{
		new sTime[64]; fm_SecondsToText(floatround(g_fPlayerNextLoad[id] - fGameTime, floatround_ceil), sTime, charsmax(sTime))
		client_print(id, print_chat, "* You must wait another %s before loading", sTime)
		fm_PlaySound(id, g_sCheckSound[SOUND_ERROR])

		return PLUGIN_HANDLED
	}

	//CheckEcho(id)
	CheckTeleport(id)

	return PLUGIN_CONTINUE
}

CheckLast(id)
{
	if (!CheckCommand(id))
	{
		return PLUGIN_HANDLED
	}

	if (g_bSpeedRunPluginExists && fm_IsUserSpeedRunning(id))
	{
		client_print(id, print_chat, g_sSpeedRunErrorMessage)
		fm_PlaySound(id, g_sCheckSound[SOUND_ERROR])
		return PLUGIN_HANDLED	
	}

	if (g_iPlayerLastCheckPos[id] >= MAX_LAST_CHECKS - 1)
	{
		client_print(id, print_chat, "* You cannot go back any futher. Only your last %d checkpoints are saved", MAX_LAST_CHECKS)
		fm_PlaySound(id, g_sCheckSound[SOUND_ERROR])

		return PLUGIN_HANDLED
	}
	
	if (g_fPlayerCheckOrigin[id][g_iPlayerLastCheckPos[id] + 1][0] == 0.0 && g_fPlayerCheckOrigin[id][g_iPlayerLastCheckPos[id] + 1][1] == 0.0 && g_fPlayerCheckOrigin[id][g_iPlayerLastCheckPos[id] + 1][2] == 0.0)
	{
		client_print(id, print_chat, "* You have not saved any more checkpoints")
		fm_PlaySound(id, g_sCheckSound[SOUND_ERROR])

		return PLUGIN_HANDLED
	}

	new Float:fGameTime = get_gametime()
	if (g_fPlayerNextLoad[id] > fGameTime)
	{
		new sTime[64]; fm_SecondsToText(floatround(g_fPlayerNextLoad[id] - fGameTime, floatround_ceil), sTime, charsmax(sTime))
		client_print(id, print_chat, "* You must wait another %s before loading", sTime)
		fm_PlaySound(id, g_sCheckSound[SOUND_ERROR])

		return PLUGIN_HANDLED
	}

	for (new i = 0; i < MAX_LAST_CHECKS - 1; i++)
	{
		for (new j = 0; j < 3; j++)
		{
			g_fPlayerCheckOrigin[id][i][j] = g_fPlayerCheckOrigin[id][i + 1][j]
			g_fPlayerCheckAim[id][i][j] = g_fPlayerCheckAim[id][i + 1][j]
		}
	}

	g_iPlayerLastCheckPos[id]++

	//CheckEcho(id)
	CheckTeleport(id)
	return PLUGIN_HANDLED
}

/*
CheckEcho(id)
{
	for (new i = 0; i < MAX_LAST_CHECKS; i++)
	{
		console_print(id, "#%d: %0.2f, %0.2f, %0.2f", i, g_fPlayerCheckOrigin[id][i][0], g_fPlayerCheckOrigin[id][i][1], g_fPlayerCheckOrigin[id][i][2])
	}
	console_print(id, "g_iPlayerLastCheckPos[id]: %d\n\n", g_iPlayerLastCheckPos[id])
}*/

CheckTeleport(id)
{
	TeleportEffect(id)	
	TeleportScreenFade(id)

	// Reset velocity because of falldamage and possible exploits		
	set_pev(id, pev_velocity, Float:{ 0.0, 0.0, 0.0 })

	engfunc(EngFunc_SetOrigin, id, g_fPlayerCheckOrigin[id][0])

	set_pev(id, pev_angles, g_fPlayerCheckAim[id][0])
	set_pev(id, pev_fixangle, 1)
	
	client_print(id, print_center, "Loaded checkpoint")
	fm_PlaySound(id, g_sCheckSound[SOUND_LOAD])
	
	g_fPlayerNextLoad[id] = get_gametime() + g_fLoadDelay
	g_iPlayerLoadCount[id]++
		
	//CheckpointStuck(id)
	UpdateCheckHUD(id)
}


TeleportScreenFade(id)
{
	message_begin(MSG_ONE, g_MsgScreenFade, { 0, 0, 0}, id) 
	write_short (1<<10) // Fade duration 
	write_short(1<<10) // Fade hold time 
	write_short(SF_FADE_IN) // Fade type 
	write_byte(255) // Fade red 
	write_byte(255) // Fade green 
	write_byte(255) // Fade blue 
	write_byte(255) // Fade alpha 
	message_end()  
}

TeleportEffect(id)
{
	new iOrigin[3]; get_user_origin(id, iOrigin)

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY) 
	write_byte(11) // Teleport Effect
	write_coord(iOrigin[0])
	write_coord(iOrigin[1])
	write_coord(iOrigin[2])
	message_end()
}
	
public Admin_Checkpoint(id, iLevel, iCommand) 
{
	if (!fm_CommandAccess(id, iLevel, true))
	{
		return PLUGIN_HANDLED
	}

	if (!g_bCheckAllow)
	{
		InitCheckpointing()
	}
	else 
	{
		ShutDownCheckpointing()
	}

	for (new i = 1; i <= g_iMaxPlayers; i++)
	{
		if(is_user_connected(i))
		{
			UpdateCheckHUD(i)
		}
	}

	new sAdminName[MAX_NAME_LEN]; get_user_name(id, sAdminName, charsmax(sAdminName))
	new sAdminAuthid[MAX_AUTHID_LEN]; get_user_authid(id, sAdminAuthid, charsmax(sAdminAuthid))
	new sAdminRealName[MAX_NAME_LEN]; fm_GetUserRealname(id, sAdminRealName, charsmax(sAdminRealName))

	client_print(0, print_chat, "* ADMIN #%d %s: %s checkpointing", fm_GetUserIdent(id), sAdminRealName, g_bCheckAllow ? g_sTextEnable : g_sTextDisable)
	console_print(id, "You have %s checkpointing", g_bCheckAllow ? g_sTextEnable : g_sTextDisable)
	log_amx("\"%s<%s>(%s)\" admin_checkpoint %s", sAdminName, sAdminAuthid, sAdminRealName, g_bCheckAllow ? g_sTextEnable : g_sTextDisable)

	return PLUGIN_HANDLED
}

