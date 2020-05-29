#include "feckinmad/fm_global"
#include "feckinmad/fm_playermodel_api"

#include <fakemeta>

new g_iPlayerCameraEnt[MAX_PLAYERS + 1] // Entity ID of their camera

public fm_PlayerModelMenuEnter(id)
{
	CreateCamera(id)
}

public fm_PlayerModelMenuExit(id, sMenuSelection[MENU_TYPE_COUNT])
{
	ResetView(id)
}

CreateCamera(id)
{
	DestroyCamera(id)

	new iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	if (!iEnt) 
	{
		fm_WarningLog(FM_ENT_WARNING)
		return PLUGIN_HANDLED
	}

	g_iPlayerCameraEnt[id] = iEnt

        engfunc(EngFunc_SetModel, iEnt, "models/backpack.mdl") // Must have a model or setview doesn't work.
        set_pev(iEnt, pev_rendermode, kRenderTransTexture)
        set_pev(iEnt, pev_renderamt, 0.0)
       
	new Float:fOrigin[3]; pev(id, pev_origin, fOrigin)
	new Float:fAngle[3]; pev(id, pev_v_angle, fAngle) 
	
	fAngle[0] = 0.0
	fAngle[2] = 0.0

	new Float:fVBack[3]; angle_vector(fAngle, ANGLEVECTOR_FORWARD, fVBack)

        fOrigin[0] += (fVBack[0] * 64.0)
        fOrigin[1] += (fVBack[1] * 64.0)
        fOrigin[2] += (fVBack[2] * 64.0)

        engfunc(EngFunc_SetOrigin, iEnt, fOrigin)

	// Reverse angle
	if (fAngle[1] < 0.0)
	{
		fAngle[1] += 180.0
	}
	else
	{
		fAngle[1] -=180.0
	}

	set_pev(iEnt, pev_angles, fAngle)
	engfunc(EngFunc_SetView, id, iEnt)

	return PLUGIN_HANDLED
}

DestroyCamera(id)
{
	if (g_iPlayerCameraEnt[id])
	{
		engfunc(EngFunc_RemoveEntity, g_iPlayerCameraEnt[id])
		g_iPlayerCameraEnt[id] = 0
	}
}

public ResetView(id)
{
	engfunc(EngFunc_SetView, id, id)
	DestroyCamera(id)
}

public client_disconnected(id)
{
	DestroyCamera(id)
}