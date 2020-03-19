stock fm_IsMapValid(sMap[])
{
	if (sMap[0] == '/' || sMap[0] == '<')
		return 0
	
	return is_map_valid(sMap)
}

stock fm_IsMapNameInFile(const sMap[], const sFile[], bool:bLogError = true)
{
	new iFileHandle = fopen(sFile, "rt")
	if (!iFileHandle)
	{
		if (bLogError)
		{
			fm_WarningLog(FM_FOPEN_WARNING, sFile)
		}
		return 0	
	}

	new sData[MAX_MAP_LEN], bool:bReturn = false
	while (!feof(iFileHandle))
	{
		fgets(iFileHandle, sData, charsmax(sData))
		trim(sData)
					
		if (!fm_Comment(sData) && (equal(sData, "*") || equali(sMap, sData)))
		{
			bReturn = true
			break
		}
	}
	fclose(iFileHandle)
	return bReturn
}

stock fm_GetProperMapName(sMapName[MAX_MAP_LEN])
{
	new sFile[64], iLen

	new iDirHandle = open_dir("maps/", sFile, charsmax(sFile))
	if (!iDirHandle)
	{
		fm_WarningLog("Unable to open maps directory")
		return 0
	}
		
	do {
		iLen = strlen(sFile) - 4
		if (iLen < 0)
		{
			continue 		
		}
	
		if(!equal(sFile[iLen], ".bsp"))
		{
			continue
		}

		sFile[iLen] = 0

		if (equali(sFile, sMapName))
		{
			copy(sMapName, MAX_MAP_LEN - 1, sFile)
			close_dir(iDirHandle)
			return 1
		}		

	} while (next_file(iDirHandle, sFile, charsmax(sFile)))

	close_dir(iDirHandle)
	return 0
}