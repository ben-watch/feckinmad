#include "feckinmad/fm_global"
#include "feckinmad/fm_admin_access"
#include "feckinmad/fm_player_get"

#include <fakemeta>

new Float:g_fPlayerNextSpray[MAX_PLAYERS + 1]

public plugin_init() 
{
	fm_RegisterPlugin()
	register_concmd("admin_spray", "Admin_Spray", ADMIN_MEMBER, "<target>")
}

public Admin_Spray(id, iLevel, iCommand)
{
	if (!fm_CommandAccess(id, iLevel, false) || !fm_CommandUsage(id, iCommand, 2))
		return PLUGIN_HANDLED
		
	new sArgs[MAX_NAME_LEN]; read_args(sArgs, charsmax(sArgs))
	new iPlayer = fm_CommandGetPlayer(id, sArgs)
	if (!iPlayer)
		return PLUGIN_HANDLED
	
	new Float:fGameTime = get_gametime()
	if(g_fPlayerNextSpray[id] > fGameTime)
	{
		console_print(id, "You cannot spray again so soon")
		return PLUGIN_HANDLED
	}

	new Float:fPlayerOrigin[3]; pev(id, pev_origin, fPlayerOrigin)
	new Float:fPlayerViewOff[3]; pev(id, pev_view_ofs, fPlayerViewOff)
	new Float:fAngles[3]; pev(id, pev_v_angle, fAngles)

	engfunc(EngFunc_MakeVectors, fAngles)
	global_get(glb_v_forward, fAngles) // We no longer need angles so use it to hold the vector

	for (new i = 0; i < 3; i++)
	{
		fPlayerOrigin[i] += fPlayerViewOff[i]
		fAngles[i] = fPlayerOrigin[i] + (fAngles[i] * 4096.0) // Scale up normalised vector
	}
		
	engfunc(EngFunc_TraceLine, fPlayerOrigin, fAngles, IGNORE_MONSTERS, id, 0)

	new Float:fFraction; get_tr2(0, TR_flFraction, fFraction);
	if (fFraction == 1.0)
		return PLUGIN_HANDLED

	new iEnt = get_tr2(0, TR_pHit)
	if (iEnt == -1)
		iEnt = 0

	new Float:fEndPos[3]; get_tr2(0, TR_vecEndPos, fEndPos);

	// Display to the admin only
	message_begin(MSG_ONE, SVC_TEMPENTITY, {0 ,0, 0}, id) //message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_PLAYERDECAL)
	write_byte(iPlayer)
	write_coord(floatround(fEndPos[0]))
	write_coord(floatround(fEndPos[1]))
	write_coord(floatround(fEndPos[2]))
	write_short(iEnt)
	write_byte(0) // Index
	message_end()

	g_fPlayerNextSpray[id] = fGameTime + 0.5

	return PLUGIN_HANDLED
}

/*

class CSprayCan : public CBaseEntity
{
public:
	void	Spawn ( entvars_t *pevOwner );
	void	Think( void );

	virtual int	ObjectCaps( void ) { return FCAP_DONT_SAVE; }
};

void CSprayCan::Spawn ( entvars_t *pevOwner )
{
	pev->origin = pevOwner->origin + Vector ( 0 , 0 , 32 );
	pev->angles = pevOwner->v_angle;
	pev->owner = ENT(pevOwner);
	pev->frame = 0;

	pev->nextthink = gpGlobals->time + 0.1;
	EMIT_SOUND(ENT(pev), CHAN_VOICE, "player/sprayer.wav", 1, ATTN_NORM);
}

void CSprayCan::Think( void )
{
	TraceResult	tr;	
	int playernum;
	int nFrames;
	CBasePlayer *pPlayer;
	
	pPlayer = (CBasePlayer *)GET_PRIVATE(pev->owner);

	if (pPlayer)
		nFrames = pPlayer->GetCustomDecalFrames();
	else
		nFrames = -1;

	playernum = ENTINDEX(pev->owner);
	
	// ALERT(at_console, "Spray by player %i, %i of %i\n", playernum, (int)(pev->frame + 1), nFrames);

	UTIL_MakeVectors(pev->angles);
	UTIL_TraceLine ( pev->origin, pev->origin + gpGlobals->v_forward * 128, ignore_monsters, pev->owner, & tr);

	// No customization present.
	if (nFrames == -1)
	{
		UTIL_DecalTrace( &tr, DECAL_LAMBDA6 );
		UTIL_Remove( this );
	}
	else
	{
		UTIL_PlayerDecalTrace( &tr, playernum, pev->frame, TRUE );
		// Just painted last custom frame.
		if ( pev->frame++ >= (nFrames - 1))
			UTIL_Remove( this );
	}

	pev->nextthink = gpGlobals->time + 0.1;
}

void UTIL_PlayerDecalTrace( TraceResult *pTrace, int playernum, int decalNumber, BOOL bIsCustom )
{
	int index;
	
	if (!bIsCustom)
	{
		if ( decalNumber < 0 )
			return;

		index = gDecals[ decalNumber ].index;
		if ( index < 0 )
			return;
	}
	else
		index = decalNumber;

	if (pTrace->flFraction == 1.0)
		return;

	MESSAGE_BEGIN( MSG_BROADCAST, SVC_TEMPENTITY );
		WRITE_BYTE( TE_PLAYERDECAL );
		WRITE_BYTE ( playernum );
		WRITE_COORD( pTrace->vecEndPos.x );
		WRITE_COORD( pTrace->vecEndPos.y );
		WRITE_COORD( pTrace->vecEndPos.z );
		WRITE_SHORT( (short)ENTINDEX(pTrace->pHit) );
		WRITE_BYTE( index );
	MESSAGE_END();
}


*/