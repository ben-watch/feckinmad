#if defined _fm_ban_included
  #endinput
#endif
#define _fm_ban_included

#include "feckinmad/fm_time" //fm_SecondsToText

#define MAX_REASON_LEN 128
#define MAX_BAN_LEN_MINS 60 * 24 * 28 // 1 month
#define INITIAL_BAN_IDENT 1

enum 
{
	BANTYPE_NONE,
	BANTYPE_PERMANENT,
	BANTYPE_MAP,
	BANTYPE_TIMED,
	BANTYPE_COUNT
}

enum eBanInfo_t
{
	m_iBanIdent, // Unique identifier for each ban
	m_sBanName[MAX_NAME_LEN],
	m_iBanType, // Whther the ban is map based, permanent or timed
	m_sBanAuthid[MAX_AUTHID_LEN], // Steamid
	m_iBanTime, // Timestamp the ban was added
	m_iBanLength, // If ban type is timed, this is the length in seconds
	m_iBanAdmin, // Admin ident that banned
	m_sBanReason[MAX_REASON_LEN], // Reason for ban
}

stock const g_sTextBanType[BANTYPE_COUNT][] = 
{
	"None",
	"Permanent",
	"Rest of Map",
	"Timed"
}

stock const g_sTextBanLength[BANTYPE_COUNT][] = 
{
	"",
	"permanently",
	"until mapchange",
	"temporarily"
}

stock fm_PrintBanInfo(id, BanInfo[eBanInfo_t])
{
	new AdminInfo[eAdmin_t]; fm_GetAdminInfoByIdent(BanInfo[m_iBanAdmin], AdminInfo)
	console_print(id, "#%d %s<%s> by Admin: #%d %s", BanInfo[m_iBanIdent], BanInfo[m_sBanName], BanInfo[m_sBanAuthid], BanInfo[m_iBanAdmin], AdminInfo[m_sAdminName])

	new sType[128]; fm_FormatBanType(BanInfo, sType, charsmax(sType))
	console_print(id, "%s Reason: %s", sType, BanInfo[m_sBanReason])
}


stock fm_FormatBanType(BanInfo[eBanInfo_t], sString[], iLen)
{
	new iType = BanInfo[m_iBanType]
	switch(iType)
	{
		case BANTYPE_PERMANENT, BANTYPE_MAP: copy(sString, iLen, g_sTextBanType[iType])
		case BANTYPE_TIMED:
		{
			new iRemaining = fm_GetBanTimeRemaining(BanInfo)
			if (iRemaining > 0)
			{
				new sTime[64]; fm_SecondsToText((BanInfo[m_iBanTime] + BanInfo[m_iBanLength]) - get_systime(), sTime, charsmax(sTime), 1)
				formatex(sString, iLen, "Remaining: %s", sTime)
			}
			else
			{
				fm_WarningLog("Error")
			}
		}
		default: fm_WarningLog("Error")
	}	
}


stock fm_FormatBanLength(BanInfo[eBanInfo_t], sString[], iLen)
{
	new iType = BanInfo[m_iBanType]
	switch(iType)
	{
		case BANTYPE_PERMANENT, BANTYPE_MAP: copy(sString, iLen, g_sTextBanLength[iType])
		case BANTYPE_TIMED:
		{
			new iRemaining = fm_GetBanTimeRemaining(BanInfo)
			if (iRemaining > 0)
			{
				new sTime[64]; fm_SecondsToText((BanInfo[m_iBanTime] + BanInfo[m_iBanLength]) - get_systime(), sTime, charsmax(sTime), 1)
				formatex(sString, iLen, "for %s", sTime)
			}
			else
			{
				fm_WarningLog("Error")
			}
		}
		default: fm_WarningLog("Error")
	}	
}



stock fm_GetBanTimeRemaining(BanInfo[eBanInfo_t])
{
	if (BanInfo[m_iBanType] == BANTYPE_TIMED && BanInfo[m_iBanLength] > 0)
		return BanInfo[m_iBanTime] + BanInfo[m_iBanLength] - get_systime()
	else
		fm_WarningLog("test")
	return 0
}

stock Array:fm_CreateBanList()
	return ArrayCreate(eBanInfo_t)

stock fm_GetBanInfoByAuth(Array:BanList, sAuthid[], BanInfo[eBanInfo_t])
{	
	fm_DebugPrintLevel(1, "fm_GetBanInfoByAuth(%d, \"%s\", BanInfo)", BanList, sAuthid)

	new Buffer[eBanInfo_t]
	for (new i = 0, iCount = ArraySize(BanList); i < iCount; i++)
	{
		ArrayGetArray(BanList, i, Buffer)
		if (equal(sAuthid, Buffer[m_sBanAuthid]))
		{
			fm_CopyBanInfo(BanInfo, Buffer)
			return i
		}
	}
	return -1
}


stock fm_GetBanInfoByIdent(Array:BanList, iIdent, BanInfo[eBanInfo_t])
{	
	fm_DebugPrintLevel(1, "fm_GetBanInfoByIdent(%d, %d, BanInfo)", BanList, iIdent)

	new Buffer[eBanInfo_t]
	for (new i = 0, iCount = ArraySize(BanList); i < iCount; i++)
	{
		ArrayGetArray(BanList, i, Buffer)
		if (iIdent == Buffer[m_iBanIdent])
		{
			fm_CopyBanInfo(BanInfo, Buffer)
			return i
		}
	}
	return -1
}

stock fm_GetBanInfoByIndex(Array:BanList, iIndex, BanInfo[eBanInfo_t])
	ArrayGetArray(BanList, iIndex, BanInfo)

stock fm_GetBanIndexByIdent(Array:BanList, iIdent)
{
	fm_DebugPrintLevel(1, "fm_GetBanIndexByIdent(%d, %d)", BanList, iIdent)

	new Buffer[eBanInfo_t]
	for (new i = 0, iCount = ArraySize(BanList); i < iCount; i++)
	{
		ArrayGetArray(BanList, i, Buffer)
		if (iIdent == Buffer[m_iBanIdent])
			return i
	}
	return -1
}

stock fm_RemoveBanByIdent(Array:BanList, iIdent)
{
	fm_DebugPrintLevel(1, "fm_RemoveBanByIdent(%d, %d)", BanList, iIdent)

	new Buffer[eBanInfo_t]
	for (new i = 0, iCount = ArraySize(BanList); i < iCount; i++)
	{
		ArrayGetArray(BanList, i, Buffer)
		if (iIdent == Buffer[m_iBanIdent])
		{
			ArrayDeleteItem(BanList, i)
			return 1
		}
	}
	return 0

}	

stock fm_RemoveBanByIndex(Array:BanList, iIndex)
{
	fm_DebugPrintLevel(1, "fm_RemoveBanByIndex(%d, %d)", BanList, iIndex) 
	ArrayDeleteItem(BanList, iIndex)
}

stock fm_ReadBanFile(Array:BanList, const sFile[]) 
{
	fm_DebugPrintLevel(1, "fm_ReadBanFile(%d, \"%s\")", BanList, sFile)

	new iCurrentIdent = 1

	new iFileHandle = fopen(sFile, "rb")
	if (!iFileHandle)
	{
		if (!fm_WriteBanFile(BanList, sFile, iCurrentIdent))
			return 0
	}
	else
	{
		fread(iFileHandle, iCurrentIdent, BLOCK_INT)

		fseek(iFileHandle, 0, SEEK_END)
		new iCount = (ftell(iFileHandle) - BLOCK_INT) / (_:eBanInfo_t * BLOCK_INT)
		fseek(iFileHandle, BLOCK_INT, SEEK_SET)
	
		new BanInfo[eBanInfo_t]
		for (new i = 0; i < iCount; i++)
		{
			if (fread_blocks(iFileHandle, BanInfo, eBanInfo_t, BLOCK_INT) != _:eBanInfo_t)
			{
				fm_WarningLog("Error reading bans from file: \"%s\"", sFile)
				break
			}
		
			fm_AddBanByStruct(BanList, BanInfo)
		}
		fclose(iFileHandle)
	}

	return iCurrentIdent
}

stock fm_PruneTimedBans(Array:BanList)
{
	fm_DebugPrintLevel(1, "fm_PruneBans(%d)", BanList) 

	new iSysTime = get_systime()
	new iCount = ArraySize(BanList)
	new Buffer[eBanInfo_t], iRemoved
	new i

	while (i < iCount)
	{
		ArrayGetArray(BanList, i, Buffer)

		if (Buffer[m_iBanType] == BANTYPE_TIMED && (Buffer[m_iBanTime] + Buffer[m_iBanLength] - iSysTime) <= 0)
		{
			fm_RemoveBanByIndex(BanList, i)
			iRemoved++
			iCount--
		}
		else
			i++
	}

	return iRemoved	
}

stock fm_WriteBanFile(Array:BanList, const sFile[], iCurrentIdent) 
{
	fm_DebugPrintLevel(1, "fm_WriteBanFile(%d, \"%s\", %d)", BanList, sFile, iCurrentIdent) 

	new iFileHandle = fopen(sFile, "wb")
	if (!iFileHandle)
	{
		fm_WarningLog(FM_FOPEN_WARNING, sFile)
		return 0
	}

	fwrite(iFileHandle, iCurrentIdent, BLOCK_INT)

	new iCount = ArraySize(BanList)
	new Buffer[eBanInfo_t]

	for (new i = 0; i < iCount; i++)
	{
		ArrayGetArray(BanList, i, Buffer)
		
		if (fm_GetBanType(Buffer) != BANTYPE_MAP)
		{
			fwrite_blocks(iFileHandle, Buffer, eBanInfo_t, BLOCK_INT)
		}
	}

	fclose(iFileHandle)
	return 1
}

stock fm_HasTimedBanExpired(BanInfo[eBanInfo_t])
{
	if (fm_GetBanType(BanInfo) == BANTYPE_TIMED && fm_GetBanTimeRemaining(BanInfo) <= 0)
	{
		return 1
	}
	return 0
}

stock fm_ClearBanInfo(BanInfo[eBanInfo_t])
{
	fm_DebugPrintLevel(1, "fm_ClearBanInfo([m_iBanIdent]: %d)", BanInfo[m_iBanIdent]) 

	BanInfo[m_iBanIdent] = 0
	BanInfo[m_sBanName][0] = 0
	BanInfo[m_iBanType] = BANTYPE_NONE
	BanInfo[m_sBanAuthid][0] = 0
	BanInfo[m_iBanTime] = 0
	BanInfo[m_iBanLength] = 0
	BanInfo[m_iBanAdmin] = 0
	BanInfo[m_sBanReason][0] = 0
}

stock fm_CopyBanInfo(Destination[eBanInfo_t], Source[eBanInfo_t])
{

	Destination[m_iBanIdent] = Source[m_iBanIdent]
	copy(Destination[m_sBanName], MAX_NAME_LEN - 1, Source[m_sBanName])
	Destination[m_iBanType] = Source[m_iBanType]
	copy(Destination[m_sBanAuthid], MAX_AUTHID_LEN - 1, Source[m_sBanAuthid])
	Destination[m_iBanTime] = Source[m_iBanTime]
	Destination[m_iBanLength] = Source[m_iBanLength]
	Destination[m_iBanAdmin] = Source[m_iBanAdmin]
	copy(Destination[m_sBanReason], MAX_REASON_LEN - 1, Source[m_sBanReason]) 
}

//stock fm_DebugPrintBanInfo(BanInfo[eBanInfo_t])
//{
//}

stock fm_AddBanByStruct(Array:BanList, BanInfo[eBanInfo_t])
	ArrayPushArray(BanList, BanInfo)

stock fm_GetBanIdent(BanInfo[eBanInfo_t])
	return BanInfo[m_iBanIdent]

stock fm_GetBanType(Buffer[eBanInfo_t])
	return Buffer[m_iBanType]

stock fm_SetBanType(Buffer[eBanInfo_t], iType)
{
	if (iType < 0 || iType >= BANTYPE_COUNT)
	{
		fm_WarningLog("Attempted to set invalid ban type (%d)", iType)
		return 0
	}

	Buffer[m_iBanType] = iType
	return 1
}

stock fm_GetBanAuthid(Buffer[eBanInfo_t], sAuthid[], iLen)
	copy(sAuthid, iLen, Buffer[m_sBanAuthid])

stock fm_GetBanTime(Buffer[eBanInfo_t])
	return Buffer[m_iBanTime]

stock fm_GetBanLength(Buffer[eBanInfo_t])
	return Buffer[m_iBanLength]

stock fm_GetBanAdmin(Buffer[eBanInfo_t])
	return Buffer[m_iBanAdmin]
