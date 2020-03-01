#include "feckinmad/fm_global"
#include "feckinmad/fm_admin_api"

new const g_sAdminFile[] = "fm_admins_cache.dat"

public plugin_init()
{
	fm_RegisterPlugin()

	new sFile[128]; fm_BuildAMXFilePath(g_sAdminFile, sFile, charsmax(sFile), FM_AMXX_LOCAL_DATA)
	new iFileHandle = fopen(sFile, "rb")
	if (!iFileHandle) 
	{
		fm_WarningLog(FM_FOPEN_WARNING, sFile)
		return PLUGIN_CONTINUE
	}

	new iLastUpdate; fread(iFileHandle, iLastUpdate, BLOCK_INT)

	fseek(iFileHandle, 0, SEEK_END)
	new iCount = (ftell(iFileHandle) - BLOCK_INT) / (_:eAdmin_t * BLOCK_INT)
	fseek(iFileHandle, BLOCK_INT, SEEK_SET)

	new Buffer[eAdmin_t]
	for (new i = 0; i < iCount; i++)
	{
		if (fread_blocks(iFileHandle, Buffer, eAdmin_t, BLOCK_INT) != _:eAdmin_t)
		{
			fm_WarningLog("Failed whilst reading admin cache file (%d)", ftell(iFileHandle))
			break
		}
		fm_AddAdminInfo(Buffer)
	}

	fclose(iFileHandle)

	log_amx("Read %d admins from \"%s\"", iCount, sFile)
	return PLUGIN_CONTINUE
}

// Forward from FM_ADMIN_API.amxx when a plugin calls the fm_AdminInfoUpdated() native 
public fm_AdminInfoUpdated()
{
	fm_DebugPrintLevel(1, "fm_Forward_AdminInfoUpdated()")

	new sFile[128]; fm_BuildAMXFilePath(g_sAdminFile, sFile, charsmax(sFile), FM_AMXX_LOCAL_DATA)
	new iFileHandle = fopen(sFile, "wb")
	if (!iFileHandle)
	{
		fm_WarningLog(FM_FOPEN_WARNING, sFile)
		return 0
	}

	fwrite(iFileHandle, get_systime(), BLOCK_INT)

	new Buffer[eAdmin_t], iCount = fm_GetAdminCount()
	for (new i = 0; i < iCount; i++)
	{
		fm_GetAdminInfoByIndex(i, Buffer)
		fwrite_blocks(iFileHandle, Buffer, eAdmin_t, BLOCK_INT)
	}
	fclose(iFileHandle)
	log_amx("Wrote %d admins to \"%s\"", iCount, sFile)
	return 1
}

/*
		(BLOCK_SHORT + BLOCK_CHAR + (MAX_AUTHID_LEN * BLOCK_CHAR) + BLOCK_INT + (MAX_NAME_LEN * BLOCK_CHAR))

		fread(iFileHandle, Buffer[m_iAdminIdent], BLOCK_SHORT)
		fread(iFileHandle, Buffer[m_iAdminActive], BLOCK_CHAR)
		fread_blocks(iFileHandle, Buffer[m_sAdminAuthid], MAX_AUTHID_LEN, BLOCK_CHAR)
		fread_blocks(iFileHandle, Buffer[m_sAdminAuthid], MAX_AUTHID_LEN, BLOCK_CHAR)
		fread(iFileHandle, Buffer[m_iAdminAccess], BLOCK_INT)

		fwrite(iFileHandle, Buffer[m_iAdminIdent], BLOCK_SHORT)
		fwrite(iFileHandle, Buffer[m_iAdminActive], BLOCK_CHAR)
		fwrite_blocks(iFileHandle, Buffer[m_sAdminAuthid], MAX_AUTHID_LEN, BLOCK_CHAR)
		fwrite(iFileHandle, Buffer[m_iAdminAccess], BLOCK_INT)
		fwrite_blocks(iFileHandle, Buffer[m_sAdminName], MAX_NAME_LEN, BLOCK_CHAR)

*/
