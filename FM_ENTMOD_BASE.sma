#include "feckinmad/fm_global"
#include "feckinmad/entmod/fm_entmod_base"

#include <fakemeta>

#define MAX_ENTS 1365 // Note: This can actually be altered via the command line switch -num_edicts at runtime! 

new Array:g_EntInfo[MAX_ENTS]

new Array:g_BrushModels, Array:g_BrushOrigins
new g_iBrushModelCount, g_iBrushOriginCount

new g_pCvarEnabled, bool:g_bEnabled

public plugin_precache()
{
	g_pCvarEnabled = register_cvar("fm_entmod_enabled", "1")

	if (get_pcvar_num(g_pCvarEnabled))
	{
		g_BrushModels = ArrayCreate(1)
		g_BrushOrigins = ArrayCreate(1)

		register_forward(FM_KeyValue, "Forward_KeyValue")
		register_forward(FM_RemoveEntity, "Forward_RemoveEntity")

		g_bEnabled = true
	}
}

public plugin_init()
{
	fm_RegisterPlugin()
}

public plugin_end()
{
	for (new i = 0; i < MAX_ENTS; i++)
	{
		if (g_EntInfo[i] != Invalid_Array)
		{
			ArrayDestroy(g_EntInfo[i])
		}
	}
}

public Forward_KeyValue(iEnt, Kvd)
{
	static Buffer[eKeyValue_t]

	get_kvd(Kvd, KV_KeyName, Buffer[m_sKey], MAX_KEY_LEN - 1)
	get_kvd(Kvd, KV_Value, Buffer[m_sValue], MAX_VALUE_LEN - 1)

	PushEntKeyValue(iEnt, Buffer)

	if (equal(Buffer[m_sKey], "model") && Buffer[m_sValue][0] == '*')
	{
		ArrayPushCell(g_BrushModels, str_to_num(Buffer[m_sValue][1]))
		g_iBrushModelCount++
	}

	if (equal(Buffer[m_sKey], "origin"))
	{
		ArrayPushCell(g_BrushOrigins, iEnt)
		g_iBrushOriginCount++
	}
}

PushEntKeyValue(iEnt, KeyValue[eKeyValue_t])
{
	if (g_EntInfo[iEnt] == Invalid_Array)
	{
		g_EntInfo[iEnt] = ArrayCreate(eKeyValue_t, 1)
	}
	ArrayPushArray(g_EntInfo[iEnt], KeyValue)
}

public Forward_RemoveEntity(iEnt)
{
	if (g_EntInfo[iEnt] != Invalid_Array)
	{
		ArrayDestroy(g_EntInfo[iEnt])
	}
}

GetEntKeyValue(iEnt, const sKey[], sValue[] = "", iLen = 0)
{
	if (g_EntInfo[iEnt] != Invalid_Array)
	{
		static Buffer[eKeyValue_t]
		for (new i = 0, iSize = ArraySize(g_EntInfo[iEnt]); i < iSize; i++)
		{
			ArrayGetArray(g_EntInfo[iEnt], i, Buffer)
			
			if (equal(Buffer[m_sKey], sKey))
			{
				if (iLen > 0) copy(sValue, iLen, Buffer[m_sValue])
				return i
			}
		}
	}
	return -1
}

public plugin_natives()
{
	register_native("fm_IsEntModEnabled", "Native_IsEntModEnabled")

	register_native("fm_GetCachedEntKey", "Native_GetEntKey")
	register_native("fm_GetCachedEntKeyIndex", "Native_GetEntKeyIndex")
	register_native("fm_PushCachedEntKey", "Native_PushEntKey")
	register_native("fm_SetCachedEntKey", "Native_SetEntKey")
	register_native("fm_RemoveCachedEntKey", "Native_RemoveEntKey")	

	register_native("fm_RemoveCachedEntKeyIndex", "Native_RemoveEntKeyIndex")
	register_native("fm_DestroyCachedEntKeys", "Native_DestroyEntKeys")
	register_native("fm_CachedEntKeyCount", "Native_SizeEntKeys")

	// The rest of these functions are in the fm_entmod_base.inc
	// The float one has to be here to be able to set the parameter byref
	register_native("fm_GetCachedEntKeyFloat", "Native_GetEntKeyFloat")

	register_native("fm_IsValidBrushModel", "Native_IsValidBrushModel")
	register_native("fm_EntityHasOriginBrush", "Native_EntityHasOriginBrush")

	register_library("fm_entmod_base")
}

public Native_IsValidBrushModel()
{
	new iModel = get_param(1)
	for (new i = 0; i < g_iBrushModelCount; i++)
	{
		if (ArrayGetCell(g_BrushModels, i) == iModel)
		{
			return 1
		}
	}
	return 0
}

public Native_EntityHasOriginBrush()
{
	new iEnt = get_param(1)
	for (new i = 0; i < g_iBrushOriginCount; i++)
	{
		if (ArrayGetCell(g_BrushOrigins, i) == iEnt)
		{
			return 1
		}
	}
	return 0
}

public Native_IsEntModEnabled()
{
	return g_bEnabled
}

// native fm_GetEntKey(iEnt, sKey[], sValue[] = "", iLen = 0)
public Native_GetEntKey(iPlugin, iParams)
{
	static sKey[MAX_KEY_LEN], sValue[MAX_VALUE_LEN]

	new iEnt = get_param(1)
	get_string(2, sKey, charsmax(sKey))
	new iIndex, iLen = get_param(4)

	if (iLen > 0)
	{
		iIndex = GetEntKeyValue(iEnt, sKey, sValue, iLen)
		set_string(3, sValue, iLen)
	}
	else 
		iIndex = GetEntKeyValue(iEnt, sKey)

	return iIndex
}

// native fm_GetEntKey(iEnt, sKey[], fValue)
public Native_GetEntKeyFloat(iPlugin, iParams)
{
	static sKey[MAX_KEY_LEN], sValue[MAX_VALUE_LEN]

	new iEnt = get_param(1)
	get_string(2, sKey, charsmax(sKey))

	new iIndex = GetEntKeyValue(iEnt, sKey, sValue, charsmax(sValue))
	set_float_byref(3, str_to_float(sValue))

	return iIndex
}


// native fm_GetEntKeyIndex(iEnt, iIndex, sKey[], iKeyLen, sValue[], iValueLen)
public Native_GetEntKeyIndex(iPlugin, iParams)
{
	new iEnt = get_param(1)
	if (g_EntInfo[iEnt] == Invalid_Array)
		return 0

	new iIndex = get_param(2)
	static Buffer[eKeyValue_t]; ArrayGetArray(g_EntInfo[iEnt], iIndex, Buffer)

	set_string(3, Buffer[m_sKey], get_param(4))
	set_string(5, Buffer[m_sValue], get_param(6))

	return 1
}

// native fm_PushEntKey(iEnt, sKey[], sValue[])
public Native_PushEntKey(iPlugin, iParams) 
{
	new iEnt = get_param(1)

	static Buffer[eKeyValue_t]
	get_string(2, Buffer[m_sKey], MAX_KEY_LEN - 1)
	get_string(3, Buffer[m_sValue], MAX_VALUE_LEN - 1)
	PushEntKeyValue(iEnt, Buffer)

	return 1
}

// native fm_SetEntKey(iEnt, sKey[], sValue[]) 
public Native_SetEntKey(iPlugin, iParams)
{
	new iEnt = get_param(1)

	static Buffer[eKeyValue_t]
	get_string(2, Buffer[m_sKey], MAX_KEY_LEN - 1)
	get_string(3, Buffer[m_sValue], MAX_VALUE_LEN - 1)
	
	new iIndex = GetEntKeyValue(iEnt, Buffer[m_sKey])
	if (iIndex != -1)	
		ArraySetArray(g_EntInfo[iEnt], iIndex, Buffer)
	else
		PushEntKeyValue(iEnt, Buffer)
	return 1
}

public Native_RemoveEntKey(iPlugin, iParams)
{
	new iEnt = get_param(1)
	static sKey[MAX_KEY_LEN]; get_string(2, sKey, charsmax(sKey))

	new iIndex = GetEntKeyValue(iEnt, sKey)
	if (iIndex != -1)
	{	
		ArrayDeleteItem(g_EntInfo[iEnt], iIndex)
		return 1
	}
	return 0
}

public Native_RemoveEntKeyIndex(iPlugin, iParams)
{
	new iEnt = get_param(1)

	if (g_EntInfo[iEnt] == Invalid_Array)
		return 0

	ArrayDeleteItem(g_EntInfo[iEnt], get_param(2))
	return 1
}

public Native_DestroyEntKeys(iPlugin, iParams)
{
	new iEnt = get_param(1)

	if (g_EntInfo[iEnt] == Invalid_Array)
		return 0

	ArrayDestroy(g_EntInfo[iEnt])
	return 1
}

public Native_SizeEntKeys(iPlugin, iParams)
{
	new iEnt = get_param(1)

	if (g_EntInfo[iEnt] == Invalid_Array)
		return 0

	return ArraySize(g_EntInfo[iEnt])
}