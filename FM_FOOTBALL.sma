#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include "feckinmad/fm_global"

// Classnames of our custom ents used by mappers
#define BALL_CREATE_CLASSNAME "fm_football_create"
#define BALL_DELETE_CLASSNAME "fm_football_delete"
#define BALL_SPAWN_CLASSNAME "fm_football_spawn"
#define BALL_GOAL_CLASSNAME "fm_football_goal"
#define BALL_TRIGGER_CLASSNAME "fm_football_trigger"

// Real entities that replace our custom entities above
#define BALL_POINT_ENTITY "info_target"
#define BALL_BRUSH_ENTITY "trigger_multiple"

// Pevs for storing ball info in fm_football_create
// Store these in the create entity rather than globally so the mapper can make as many as they wish
#define BALL_PEV_BOUNCE_SOUND pev_noise
#define BALL_PEV_KICK_SOUND pev_noise1
#define BALL_PEV_KICK_SCALE pev_fuser1
#define BALL_PEV_DAMAGE_SCALE pev_fuser2

#define TRIGGER_PEV_WAIT_TIME pev_fuser1 // How long before a trigger can retrigger
#define TRIGGER_START_OFF (1<<0) // Whether the trigger is active on map start
#define TRIGGER_DELAY_ONCE -1 // Trigger setting if the player wants the trigger to only trigger once

#define BALL_KICK_DISTANCE 75.0 // How far away from the ball a player has to be to kick it
#define BALL_KICK_DELAY 0.25 // Delay a players between ability to kick the ball

#define BALL_BLAST_STUCK_DELAY 0.3
#define BALL_BLAST_STUCK_DISTANCE 32.0 // If it's not moved more than this, invoke ball blast
#define BALL_BLAST_DISTANCE 180.0
#define BALL_BLAST_MULTIPLIER 250 // Velocity to throw players away * number of stucks

#define BALL_TRAIL_SPRITE "sprites/fm/smoke.spr"
#define NUM_KICKS_TO_TRACK 3 
#define CONC_BLAST_DAMAGE 40.0
#define GOAL_ASSIST_DELAY 5.0
#define MAX_TEAMS 4

// Colour of each team. Used for ball trail and coloured hudmessages
new const g_iTeamColours[MAX_TEAMS + 1][3] =
{
	{ 255, 255, 255 }, // White
	{ 50, 50, 255 }, // Blue
	{ 255, 50, 50 }, // Red
	{ 255, 255, 50 }, // Yellow
	{ 50, 255, 50 } // Green
}

new g_iBallEnt // Entity IDs of the ball
new g_iKeyValueForward, g_iTrailSprite, g_iMaxPlayers 

new Float:g_fNextKick[MAX_PLAYERS] // Gametime a player can next kick
new g_bWeaponStripped[MAX_PLAYERS] // Whether a player has had their weapons stripped. If this is false +attack will not kick the ball. +kick will
new bool:g_bKicking[MAX_PLAYERS] // Whether the player is pressing +kick

new Float:g_fLastStuckTime // Gametime the ball was last considered stuck
new g_iLastStuckCount // Number of times the ball has been considered stuck

// Current ball settings, loaded from fm_football_create when it is triggered
new Float:g_fKickScale
new Float:g_fDamageScale
new g_sBallBounceSound[64]
new g_sBallKickSound[64]

// Info stored for displaying stats on goal
new g_iLastKick[NUM_KICKS_TO_TRACK] // Player IDs of the recent kicks for use with assists
new Float:g_fLastKickTime[NUM_KICKS_TO_TRACK] // Gametime thhe kicks stored above occured
new g_iLastToucher // Player ID of the last touched for displaying deflections on goals

public plugin_precache()
{
	//fm_protect()
	
	// Register keyvalue foward so I can catch the entity properties when they are set
	// This will call Forward_KeyValue each time a keyvalue is set. e.g. "team_no" "4"
	g_iKeyValueForward = register_forward(FM_KeyValue, "Forward_KeyValue")
	g_iTrailSprite = engfunc(EngFunc_PrecacheModel, BALL_TRAIL_SPRITE)
}

public Forward_KeyValue(iEnt, Kvd)
{
	static sKey[32], sValue[32]
	get_kvd(Kvd, KV_KeyName, sKey, charsmax(sKey))

	// Keep track of the entity between calls
	static iCustomEnt, sCustomName[32] 

	// Setting the "classname" keyvalue happens twice. The first time is before any other values are set and the entity isn't valid
	// To ensure our custom entity names are created by the engine I have to give it any entity name it recognises
	// The second time the "classname" keyvalue is set it is valid and overwrites the first classname, but this is usually set after all the other keys
	// We could block these the second time by checking if the entity is valid, but if I want to use Ham_Use with them they have to be recognised entities anyway

	if (equal(sKey, "classname"))
	{
		get_kvd(Kvd, KV_Value, sValue, charsmax(sValue))
		if (equal(sValue, BALL_GOAL_CLASSNAME) || equal(sValue, BALL_SPAWN_CLASSNAME) || equal(sValue, BALL_CREATE_CLASSNAME) || equal(sValue, BALL_DELETE_CLASSNAME))
		{
			set_kvd(Kvd, KV_Value, BALL_POINT_ENTITY) // Make it a valid entity

			if (pev_valid(iEnt))
				set_pev(iEnt, pev_netname, sCustomName) // Store the name of the custom entity incase we need to tell it apart later
			else
			{
				iCustomEnt = iEnt // Store the entity id so we know whether to do shit when Forward_KeyValue is next called
				copy(sCustomName, charsmax(sCustomName), sValue) // Store the custom entity name so we know what entity this is
			}
		}
		else if (equal(sValue, BALL_TRIGGER_CLASSNAME))
		{
			set_kvd(Kvd, KV_Value, BALL_BRUSH_ENTITY)

			// Repeated code...
			if (pev_valid(iEnt))
				set_pev(iEnt, pev_netname, sCustomName) 
			else
			{
				iCustomEnt = iEnt 
				copy(sCustomName, charsmax(sCustomName), sValue) 
			}
		}
	}
	else if (iCustomEnt == iEnt && pev_valid(iEnt))
	{
		get_kvd(Kvd, KV_Value, sValue, charsmax(sValue))
		
		if (equal(sCustomName, BALL_CREATE_CLASSNAME))
		{
			if (equal(sKey, "ballmodel"))
			{
				set_pev(iEnt, pev_model, sValue) // This doesnt actually set the model of the create entity, I'm just storing it in the entity
				engfunc(EngFunc_PrecacheModel, sValue)
			}
			else if (equal(sKey, "bouncesound"))
			{
				set_pev(iEnt, BALL_PEV_BOUNCE_SOUND, sValue) 
				engfunc(EngFunc_PrecacheSound, sValue)
			}
			else if (equal(sKey, "kicksound"))
			{
				set_pev(iEnt, BALL_PEV_KICK_SOUND, sValue) 
				engfunc(EngFunc_PrecacheSound, sValue)
			}
			else if (equal(sKey, "kickscale"))
				set_pev(iEnt, BALL_PEV_KICK_SCALE, str_to_float(sValue))
			
			else if (equal(sKey, "damagescale"))
				set_pev(iEnt, BALL_PEV_DAMAGE_SCALE, str_to_float(sValue))
		}
		else if (equal(sCustomName, BALL_SPAWN_CLASSNAME))
		{
			if (equal(sKey, "speed")) // Velocity scale the ball is thrown when it is spawned here
				set_pev(iEnt, pev_fuser1, str_to_float(sValue))
		}
		else if (equal(sCustomName, BALL_GOAL_CLASSNAME))
		{
			if (equal(sKey, "team_no")) // Bitfield of teams this goal belongs to
				set_pev(iEnt, pev_team, str_to_num(sValue))
		}
		else if (equal(sCustomName, BALL_TRIGGER_CLASSNAME))
		{
			if (equal(sKey, "team_no")) // Bitfield of teams that can trigger this by kicking the ball into it
				set_pev(iEnt, pev_team, str_to_num(sValue))

			if (equal(sKey, "wait")) // Delay before it can be retriggered. 
				set_pev(iEnt, TRIGGER_PEV_WAIT_TIME, str_to_float(sValue))

			if (equal(sKey, "spawnflags")) // Whether the trigger starts off
				if (str_to_num(sValue) & TRIGGER_START_OFF)
					set_pev(iEnt, pev_solid, SOLID_NOT) 		
		}
	}
}

public plugin_init()
{		
	fm_RegisterPlugin()
	unregister_forward(FM_KeyValue, g_iKeyValueForward)

	register_forward(FM_PlayerPreThink,"Forward_PreThink") 
	register_forward(FM_Touch, "Forward_Touch") 
	register_forward(FM_Think, "Forward_TriggerThink")

	RegisterHam(Ham_TakeDamage, "info_target", "Handle_TakeDamage") // Movement of ball on damage
	RegisterHam(Ham_TFC_TakeConcussionBlast, "info_target", "Handle_TakeConcussionBlast")
	
	RegisterHam(Ham_Use, "player_weaponstrip", "Handle_WeaponStripUse") // Targetting spawns
	RegisterHam(Ham_Use, "info_target", "Handle_InfoUse") // Targetting spawns
	RegisterHam(Ham_Use, "trigger_multiple", "Handle_TriggerUse") // Targetting spawns
	
	g_iMaxPlayers = get_maxplayers()
	
	register_clcmd("+kick", "Handle_PlayerKickPress")
	register_clcmd("-kick", "Handle_PlayerKickRelease")
}


public Handle_PlayerKickPress(id)
	g_bKicking[id] = true

public Handle_PlayerKickRelease(id)
	g_bKicking[id] = false

public Handle_TakeConcussionBlast(iBall, iConc)
	Handle_TakeDamage(iBall, iConc, pev(iConc, pev_owner), CONC_BLAST_DAMAGE, 0)

public Handle_WeaponStripUse(iEnt, iCaller, iActivator, iType, Float:fValue)
	g_bWeaponStripped[iCaller] = true

public Handle_TriggerUse(iEnt, iCaller, iActivator, iType, Float:fValue)
{
	static sName[32]; pev(iEnt, pev_netname, sName, charsmax(sName))
	if (equal(sName, BALL_TRIGGER_CLASSNAME)) // Toggle the trigger on and off by targetting it
	{
		if (pev(iEnt, pev_solid) == SOLID_NOT)
			set_pev(iEnt, pev_solid, SOLID_TRIGGER)
		else
			set_pev(iEnt, pev_solid, SOLID_NOT)
	}		
}
	
public Handle_InfoUse(iEnt, iCaller, iActivator, iType, Float:fValue)
{
	static sName[32]; pev(iEnt, pev_netname, sName, charsmax(sName))
	
	if (equal(sName, BALL_CREATE_CLASSNAME))
		CreateBall(iEnt)
		
	else if (equal(sName, BALL_GOAL_CLASSNAME))
		GoalScored(iEnt, iCaller)
		
	else if (equal(sName, BALL_DELETE_CLASSNAME))
		DeleteBall()
		
	else if (equal(sName, BALL_SPAWN_CLASSNAME))
		ResetBall(iEnt)		
}

public Handle_TakeDamage(iEnt, iInflictor, iAttacker, Float:fDamage, iDmgType)
{	
	if (iEnt != g_iBallEnt || g_fDamageScale < 1.0) 
		return FMRES_IGNORED	
	
	// If the attacker is a player
	if (iAttacker > 0 && iAttacker <= g_iMaxPlayers)
	{
		// We use the location of the inflicter to work out the velocity
		// The damage could be caused by a gren, rocket, etc
		if (!iInflictor) return HAM_SUPERCEDE
	
		new Float:fInflicterOrigin[3]; pev(iInflictor, pev_origin, fInflicterOrigin)
		new Float:fBallOrigin[3]; pev(iEnt, pev_origin, fBallOrigin)

		// Get displacement vector between inflictor entity and ball
		new Float:fVelocity[3]
		for (new i = 0; i < 3; i++)
			fVelocity[i] = fBallOrigin[i] - fInflicterOrigin[i]
		
		// Normalise vector
		new Float:fLength = (vector_length(fVelocity))
		for (new i = 0; i < 3; i++)
			fVelocity[i] = fVelocity[i] / fLength
	
		// Scale vector based on map setting
		for (new i = 0; i < 3; i++)
			fVelocity[i] = fVelocity[i] * fDamage * g_fDamageScale

		// Add to current velocity
		new Float:fCurVelocity[3]
		pev(iEnt, pev_velocity, fCurVelocity)
		for (new i = 0; i < 3; i++)
			fCurVelocity[i] += fVelocity[i]

		set_pev(iEnt, pev_velocity, fVelocity)
		
		AddKick(iAttacker) // Store player kick	
		
		if (g_sBallKickSound[0])
			emit_sound(iEnt, CHAN_ITEM, g_sBallKickSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		BallTrail(pev(iAttacker, pev_team))
	}
	
	// Block the damage so the ent isn't killed
	return HAM_SUPERCEDE
}


AddKick(id)
{	
	// Move everyone down one place in the array, losing the last player
	for (new i = NUM_KICKS_TO_TRACK - 1; i > 0 ;i--)
	{
		g_iLastKick[i] = g_iLastKick[i - 1]
		g_fLastKickTime[i] = g_fLastKickTime[i - 1]
	}
	
	// Store the latest kick at the top
	g_iLastKick[0] = id
	g_fLastKickTime[0] = get_gametime()
	
	g_iLastToucher = 0
	
	return PLUGIN_CONTINUE
}

RemoveKick(id)
{
	for (new i = 0; i < NUM_KICKS_TO_TRACK; i++)
	{
		// Check if our player made this kick
		if (g_iLastKick[0] != id)
			continue

		// Remove it and bring everyone up
		for (new j = i; j < NUM_KICKS_TO_TRACK - 1; j++)
		{
			g_iLastKick[j] = g_iLastKick[j + 1] 
			g_fLastKickTime[j] = g_fLastKickTime[j + 1]	
		}			
	}
}

ResetKicks()
{
	for (new i = 0; i < NUM_KICKS_TO_TRACK; i++)
	{
		g_iLastKick[i] = 0
		g_fLastKickTime[i] = 0.0	
	}
}

BallTrail(iTeam = 0)
{
	// Remove existing trail
	RemoveTrail()

	// Add new with colour based on team
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(22)
	write_short(g_iBallEnt)
	write_short(g_iTrailSprite)
	write_byte(10) // Length
	write_byte(20) // Width
	write_byte(g_iTeamColours[iTeam][0]) // R
	write_byte(g_iTeamColours[iTeam][1]) // G
	write_byte(g_iTeamColours[iTeam][2]) // B
	write_byte(255) // A
	message_end()
}

RemoveTrail()
{
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(99)
	write_short(g_iBallEnt)
	message_end()
}


public client_disconnected(id)
{
	RemoveKick(id) // Remove kicks this player has made

	if (g_iLastToucher == id) // Remove if the player is the last to touch the ball
		g_iLastToucher = 0

	g_fNextKick[id] = 0.0
	g_bWeaponStripped[id] = false
}

CreateBall(iEnt)
{
	// Ball Already exists
	if (g_iBallEnt)
		return PLUGIN_CONTINUE
	
	// Check there is a ball model stored in the create entity
	new sModel[64]; pev(iEnt, pev_model, sModel, charsmax(sModel))
	if (!sModel[0])
		return PLUGIN_CONTINUE

	// Get the target spawn that this entity should point to
	new sBuffer[32]; pev(iEnt, pev_target, sBuffer, charsmax(sBuffer))
	if (!sBuffer[0])
		return PLUGIN_CONTINUE
	
	// Search for this target
	new iTarget = engfunc(EngFunc_FindEntityByString, 0, "targetname", sBuffer)
	if (!iTarget)
		return PLUGIN_CONTINUE
	
	// Check target is a ball spawn
	pev(iTarget, pev_netname, sBuffer, charsmax(sBuffer))
	if (!equal(sBuffer, BALL_SPAWN_CLASSNAME))
		return PLUGIN_CONTINUE
			
	// All checks done, looks like we are good to go
	g_iBallEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target")) 
	if (g_iBallEnt > 0)
	{
		engfunc(EngFunc_SetModel, g_iBallEnt, sModel) // Model must be set before the solid shit
		set_pev(g_iBallEnt, pev_movetype, MOVETYPE_BOUNCE)
		
		set_pev(g_iBallEnt, pev_solid, SOLID_BBOX)
		engfunc(EngFunc_SetSize, g_iBallEnt, { -16.0, -16.0, -16.0 } , { 16.0, 16.0, 16.0 } )
		
		g_fKickScale = float(pev(iEnt, BALL_PEV_KICK_SCALE)) // Load the kickscale from the create entity	 		
		g_fDamageScale = float(pev(iEnt, BALL_PEV_DAMAGE_SCALE))	 // Load the damagescale from the create entity
		if (g_fDamageScale >= 1.0)
		{
			set_pev(g_iBallEnt, pev_takedamage, 1.0)
			set_pev(g_iBallEnt, pev_health, 1.0)
		}
		
		pev(iEnt, BALL_PEV_BOUNCE_SOUND, g_sBallBounceSound, charsmax(g_sBallBounceSound))
		pev(iEnt, BALL_PEV_BOUNCE_SOUND, g_sBallKickSound, charsmax(g_sBallKickSound))
		
		ResetBall(iTarget)
	}
		
	return PLUGIN_CONTINUE
}


ResetBall(iEnt)
{	
	// Incase the mapper triggers a spawn before creating the ball or after deleting the ball
	if (!g_iBallEnt)
		return PLUGIN_CONTINUE

	RemoveTrail()	

	// Set ball origin based on targetted entity origin
	new Float:fOrigin[3]; pev(iEnt, pev_origin, fOrigin)
	engfunc(EngFunc_SetOrigin, g_iBallEnt, fOrigin)

	// Set ball velocity based on targetted entity "speed" and angle keyvalues
	new Float:fAngles[3], Float:fVelocity[3]

	pev(iEnt, pev_angles, fAngles)
	engfunc(EngFunc_MakeVectors, fAngles) // Convert angle to normalised vector
	global_get(glb_v_forward, fVelocity)
	
	// Scale vector up according to ent "speed" setting
	new Float:fSpeed = float(pev(iEnt, pev_fuser1)) // We saved the scale when the entity was created
	for (new i = 0; i < 3; i++) fVelocity[i] *= fSpeed
	set_pev(g_iBallEnt, pev_velocity, fVelocity)

	return PLUGIN_CONTINUE
}

DeleteBall()
{
	if (!g_iBallEnt)
		return PLUGIN_CONTINUE

	// Remove the entity
	engfunc(EngFunc_RemoveEntity, g_iBallEnt)
	
	// Reset shit
	g_iBallEnt = 0
	g_fDamageScale = 0.0
	g_fKickScale  = 0.0
	g_sBallBounceSound[0] = 0
	g_sBallKickSound[0] = 0
	ResetKicks()
	
	return PLUGIN_CONTINUE
}



public Forward_PreThink(id) 
{	
	if (!g_iBallEnt || g_fKickScale < 1.0 || !is_user_alive(id))
		return FMRES_IGNORED

	static Float:fGameTime
	static Float:fLastBallOrigin[3], Float:fBallOrigin[3], Float:fPlayerOrigin[3]
	static Float:fVelocity[3], Float:fLength
	
	if (g_bKicking[id] || (pev(id, pev_button) & IN_ATTACK && g_bWeaponStripped[id]))
	{	
		fGameTime = get_gametime() 
		
		// Throttle the players ability to kick
		if (g_fNextKick[id] > fGameTime) 
			return FMRES_IGNORED
		
		// Limit distance a player can be from the ball to kick it
		pev(id, pev_origin, fPlayerOrigin)
		pev(g_iBallEnt, pev_origin, fBallOrigin)
		if (get_distance_f(fBallOrigin, fPlayerOrigin) > BALL_KICK_DISTANCE)		
			return FMRES_IGNORED
		
		// Detect if the ball has moved much since its last kick
		// Players can sometimes crowd round the ball in the corner and block it!
		if (get_distance_f(fBallOrigin, fLastBallOrigin) < BALL_BLAST_STUCK_DISTANCE)
		{
			// If it wasn't long since the last kick its likely it has been jammed up
			if (g_fLastStuckTime + BALL_BLAST_STUCK_DELAY >= fGameTime) 
			{
				g_iLastStuckCount++
				
				// Blast everyone close to the ball away a bit
				for (new i = 1; i <= g_iMaxPlayers; i++)
				{
					// Get displacement vector between player and ball
					pev(i, pev_origin, fPlayerOrigin)
					for (new j = 0; j < 3; j++)
						fVelocity[j] = fPlayerOrigin[j]	- fBallOrigin[j]
					
					// Are they close enough to warrant throwing them away 
					if (get_distance_f(fBallOrigin, fPlayerOrigin) > BALL_BLAST_DISTANCE)
						continue
						
					// Normalise vector
					fLength = (vector_length(fVelocity))
					for (new j = 0; j < 3; j++)
						fVelocity[j] = fVelocity[j] / fLength	
					
					// Scale vector up based on how many kicks its recived while stuck
					for (new j = 0; j < 3; j++)
						fVelocity[j] *= float(g_iLastStuckCount * BALL_BLAST_MULTIPLIER)
		
					set_pev(i, pev_velocity, fVelocity)
				}						
			}
			else
				g_iLastStuckCount = 0
					
			g_fLastStuckTime = fGameTime
		}
		
		for (new i = 0; i < 3; i++)
			fLastBallOrigin[i] = fBallOrigin[i]
								
		// Convert view angle to normalised vector
		new Float:fAngles[3]; pev(id, pev_v_angle, fAngles)
		engfunc(EngFunc_MakeVectors, fAngles)
		new Float:fVelocity[3]; global_get(glb_v_forward, fVelocity)
	
		// Multiply it by magnitude
		for (new j = 0; j < 3; j++)
			fVelocity[j] *= g_fKickScale		
		set_pev(g_iBallEnt, pev_velocity, fVelocity)

		AddKick(id) // Store player kick
		
		g_fNextKick[id] = fGameTime + BALL_KICK_DELAY // Delay next kick
		BallTrail(pev(id, pev_team)) // Make ball trial the team colour of the player that kicked it
		
		// Play kick sound
		if (g_sBallKickSound[0])
			emit_sound(g_iBallEnt, CHAN_ITEM, g_sBallKickSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		
		
	}
	return FMRES_IGNORED
}


public Forward_Touch(iEnt, iBall)
{
	static sNetName[32]; pev(iEnt, pev_netname, sNetName, charsmax(sNetName))
	if (equal(sNetName,  BALL_TRIGGER_CLASSNAME))
	{
		if (iBall == g_iBallEnt)
		{				
			// If a player kicked it check if their team matches the triggers
			// If there is no player don't return because its possible the ball bounced into a trigger without being kicked
			if (g_iLastKick[0])
			{
				new iTeam = pev(iEnt, pev_team)				
				if (iTeam > 0 && !(iTeam & (1 << pev(g_iLastKick[0], pev_team) - 1)))
					return FMRES_IGNORED	
			}
			
			// Get the target of touched entity 
			new sTarget[32]; pev(iEnt, pev_target, sTarget, charsmax(sTarget))
			
			// If there is no target, reset the ball to the closest spawn
 			if (!sTarget[0]) 
			{
				new iClosestEnt = FindClosestBallSpawn()
				if (iClosestEnt) ResetBall(iClosestEnt)
				return FMRES_IGNORED		
			}
			
			new iTarget = engfunc(EngFunc_FindEntityByString, 0, "targetname", sTarget)
			while (iTarget > 0)
			{
				dllfunc(DLLFunc_Use, iTarget, g_iLastKick[0]) // The last person to kick the ball is passed as the AP
				
				// Get mapper specified wait time between triggering again
				new Float:fWait = float(pev(iEnt, TRIGGER_PEV_WAIT_TIME))
				
				// If there is a wait that needs counting down set the nextthink
				if (fWait > 0.0)
				{
					set_pev(iEnt, pev_nextthink, get_gametime() + fWait)
					set_pev(iEnt, pev_solid, SOLID_NOT)
				}
				else if (fWait < 0.0)
					engfunc(EngFunc_RemoveEntity, iEnt)	
					
				iTarget = engfunc(EngFunc_FindEntityByString, iTarget, "targetname", sTarget)
			}
			
		}
		else
			return FMRES_SUPERCEDE // Dont let any other entity apart from the ball trigger this
	}
	else if (iBall == g_iBallEnt) 
	{
		// Player touching the ball
		if (iEnt > 0 && iEnt <= g_iMaxPlayers)
		{
			g_iLastToucher = iEnt // Keep track of the player for deflection info
			
			// We want the ball to only slowdown if its bouncing on their head
			static Float:fBallOrigin[3]; pev(iBall, pev_origin, fBallOrigin)
			static Float:fPlayerOrigin[3]; pev(iEnt, pev_origin, fPlayerOrigin)			
			static Float:fViewOff[3]; pev(iEnt, pev_view_ofs, fViewOff)
			if (fBallOrigin[2] < fPlayerOrigin[2] + fViewOff[2])
				return FMRES_IGNORED
		}
		else if (pev_valid(iEnt)) // Don't slowdown if the entity touching is just a triggerr
		{
			new iSolid = pev(iEnt, pev_solid)
			if (iSolid == SOLID_TRIGGER || iSolid == SOLID_BBOX) // OR FUCKING NAILS FUCKSKCS
				return FMRES_IGNORED
		}
		BallBounce(iBall)
	}	
	return FMRES_IGNORED
}

public Forward_TriggerThink(iEnt)
{
	static sNetName[32]
	
	if (!pev_valid(iEnt))
		return FMRES_IGNORED
		
	pev(iEnt, pev_netname, sNetName, charsmax(sNetName))

	if (equal(sNetName, BALL_TRIGGER_CLASSNAME))
		set_pev(iEnt, pev_solid, SOLID_TRIGGER)

	set_pev(iEnt, pev_nextthink, 0.0)
		
	return FMRES_IGNORED
}
		
GoalScored(iGoal, id)
{	
	new sName[MAX_NAME_LEN]
	new iScorerTeam, iOwnGoal
	
	new iGoalTeam = pev(iGoal, pev_team)
	
	if (id) 
	{
		get_user_name(id, sName, charsmax(sName))
		iScorerTeam = pev(id, pev_team)
		iOwnGoal = iGoalTeam > 0 ? iGoalTeam & (1 << iScorerTeam - 1) : 0
	}
	
	new Float:fYPos = 0.5
	set_hudmessage(g_iTeamColours[iScorerTeam][0], g_iTeamColours[iScorerTeam][1], g_iTeamColours[iScorerTeam][2], -1.0, fYPos, 0, 1.0, 5.0, 0.5, 0.5, -1)
		
	//if (!iGoalTeam || !(iGoalTeam & iScorerTeam))]
	if (!iOwnGoal)
		show_hudmessage(0, "%s scored", sName)
	else
		show_hudmessage(0, "%s scored an own goal", sName)
	
	// Move the Y pos of the hudmessage down
	fYPos += 0.05 

	// Display any deflections
	if (g_iLastToucher > 0 && g_iLastToucher != g_iLastKick[0])
	{
		// It deflected off someone, get their name and team for the hudmessage
		get_user_name(g_iLastToucher, sName, charsmax(sName))
		new iTeam = pev(g_iLastToucher, pev_team)
	
		set_hudmessage(g_iTeamColours[iTeam][0], g_iTeamColours[iTeam][1], g_iTeamColours[iTeam][2], -1.0, fYPos, 0, 1.0, 5.0, 0.5, 0.5, -1)
		show_hudmessage(0, "Deflected off %s", sName)
		
		 // Move the Y pos of the hudmessage down if we displayed this message
		fYPos += 0.05 
	}

	// Display any assists if its not an own goal
	//if (!iGoalTeam || !(iGoalTeam & iScorerTeam))
	if (!iOwnGoal)
	{
		new Float:fGameTime = get_gametime()
		new sBuffer[128], iLen
		for (new i = 1; i < NUM_KICKS_TO_TRACK; i++)
		{
			// Ignore if same player
			if (g_iLastKick[i] == id)
				continue
	
			if (!g_iLastKick[i])
				break
	
			// If there team doesnt match break out now
			if (pev(g_iLastKick[i], pev_team) != iScorerTeam)
				break
	
			if (g_fLastKickTime[i] + GOAL_ASSIST_DELAY >= fGameTime)
			{
				get_user_name(g_iLastKick[i], sName, charsmax(sName))
				iLen += formatex(sBuffer, charsmax(sBuffer), "^n%s", sName)
			}
		}
		if (iLen > 0)
		{
			set_hudmessage(g_iTeamColours[iScorerTeam][0], g_iTeamColours[iScorerTeam][1], g_iTeamColours[iScorerTeam][2], -1.0, fYPos, 0, 1.0, 5.0, 0.5, 0.5, -1)
			show_hudmessage(0, "Assisted by: %s", sBuffer)
		}
	}
	ResetKicks()
	g_iLastToucher = 0
}

FindClosestBallSpawn()
{
	new iClosestEnt, iTargetEnt
	new Float:fClosestDistance, Float:fTargetDistance, Float:fSpawnOrigin[3]
	new Float:fBallOrigin[3]; pev(g_iBallEnt, pev_origin, fBallOrigin)

	while ((iTargetEnt = engfunc(EngFunc_FindEntityByString, iTargetEnt, "netname", BALL_SPAWN_CLASSNAME)) > 0)
	{
		pev(iTargetEnt, pev_origin, fSpawnOrigin) // Get the origin of this spawn
		fTargetDistance = get_distance_f(fSpawnOrigin, fBallOrigin) // Find out how far away from the ball it is
		
		if (fClosestDistance > fTargetDistance || !iClosestEnt)	// Compare against nearest ent so far
		{
			iClosestEnt = iTargetEnt
			fClosestDistance = fTargetDistance
		}
	}	
	return iClosestEnt
}


BallBounce(iBall)
{
	static Float:fBallVelocity[3]; pev(iBall, pev_velocity, fBallVelocity)	
	
	// Velocity slowdown math by hughy
	fBallVelocity[0] = 0.98 * fBallVelocity[0] / (1 + (fBallVelocity[2] < 0 ? -fBallVelocity[2]: fBallVelocity[2])  / 1000.0)
	fBallVelocity[1] = 0.98 * fBallVelocity[1] / (1 + (fBallVelocity[2] < 0 ? -fBallVelocity[2]: fBallVelocity[2])  / 1000.0)
	
	if (fBallVelocity[2] < 0.0) fBallVelocity[2] *= 0.6		
	set_pev(iBall, pev_velocity, fBallVelocity)	

	if (vector_length(fBallVelocity) > 300.0)
	{
		if (g_sBallBounceSound[0])
			emit_sound(iBall, CHAN_ITEM, g_sBallBounceSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		
		set_pev(iBall, pev_avelocity, fBallVelocity) // Not accurate but looks better than nothing	
	}
}

