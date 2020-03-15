#if defined _fm_entmod_base_included
  #endinput
#endif
#define _fm_entmod_base_included

#pragma reqlib "fm_entmod_base"

// From bspfile.h
#define	MAX_KEY_LEN 32
 
#define	MAX_VALUE_LEN 1024 

enum eKeyValue_t
{
	m_sKey[MAX_KEY_LEN],
	m_sValue[MAX_VALUE_LEN]
}

native fm_IsEntModEnabled()
native fm_GetCachedEntKey(iEnt, const sKey[], sValue[] = "", iLen = 0)
native fm_GetCachedEntKeyFloat(iEnt, const sKey[], fValue)
native fm_PushCachedEntKey(iEnt, const sKey[], sValue[])
native fm_SetCachedEntKey(iEnt, const sKey[], sValue[])
native fm_RemoveCachedEntKey(iEnt, const sKey[])
native fm_RemoveCachedEntKeyIndex(iEnt, iIndex)
native fm_DestroyCachedEntKeys(iEnt)
native fm_CachedEntKeyCount(iEnt)
native fm_GetCachedEntKeyIndex(iEnt, iIndex, sKey[], iKeyLen, sValue[], iValueLen)
native fm_IsValidBrushModel(iBrushModel)
native fm_EntityHasOriginBrush(iEnt)

stock fm_PushCachedEntKeyInt(iEnt, const sKey[], iValue)
{
	static sValue[MAX_VALUE_LEN]; num_to_str(iValue, sValue, charsmax(sValue))
	fm_PushCachedEntKey(iEnt, sKey, sValue)
	return 1
}

stock fm_PushCachedEntKeyVector(iEnt, const sKey[], Float:fValue[3])
{
	static sValue[MAX_VALUE_LEN]; formatex(sValue, charsmax(sValue), "%0.4f %0.4f %0.4f", fValue[0], fValue[1], fValue[2]) // formatex(sValue, charsmax(sValue), "%d %d %d", floatround(fValue[0]), floatround(fValue[1]), floatround(fValue[2]))
	fm_PushCachedEntKey(iEnt, sKey, sValue) 
	return 1
}

stock fm_PushCachedEntKeyFloat(iEnt, const sKey[], Float:fValue)
{
	static sValue[MAX_VALUE_LEN];
	formatex(sValue, charsmax(sValue), "%0.4f", fValue) //num_to_str(floatround(fValue), sValue, charsmax(sValue))
	fm_PushCachedEntKey(iEnt, sKey, sValue) 
	return 1
}

stock fm_SetCachedEntKeyInt(iEnt, const sKey[], iValue)
{
	static sValue[MAX_VALUE_LEN]; num_to_str(iValue, sValue, charsmax(sValue))
	fm_SetCachedEntKey(iEnt, sKey, sValue)
	return 1
}

stock fm_SetCachedEntKeyVector(iEnt, const sKey[], Float:fValue[3])
{
	static sValue[MAX_VALUE_LEN]; 
	formatex(sValue, charsmax(sValue), "%0.4f %0.4f %0.4f", fValue[0], fValue[1], fValue[2])	//formatex(sValue, charsmax(sValue), "%d %d %d", floatround(fValue[0]), floatround(fValue[1]), floatround(fValue[2]))
	fm_SetCachedEntKey(iEnt, sKey, sValue) 
	return 1
}

stock fm_SetCachedEntKeyFloat(iEnt, const sKey[], Float:fValue)
{
	static sValue[MAX_VALUE_LEN]; num_to_str(floatround(fValue), sValue, charsmax(sValue))
	fm_SetCachedEntKey(iEnt, sKey, sValue) 
	return 1
}

stock fm_GetCachedEntKeyVector(iEnt, const sKey[], Float:fValue[3])
{
	static sValue[MAX_VALUE_LEN], sBuffer[16]
	new iIndex = fm_GetCachedEntKey(iEnt, sKey, sValue, charsmax(sValue))
	if (iIndex != -1)
	{
		for (new i = 0; i < 3; i++)
		{
			argbreak(sValue, sBuffer, charsmax(sBuffer), sValue, charsmax(sValue))
			if (sBuffer[0])
				fValue[i] = floatstr(sBuffer)	
		}
		return iIndex
	}
	return -1
}
