stock fm_InsertIntoSortedList(Array:aList, sString[], iCaseSensitive = 0)
{
	static sBuffer[1024]
	for (new i = 0, iCount = ArraySize(aList); i < iCount; i++)
	{
		ArrayGetString(aList, i, sBuffer, charsmax(sBuffer))
		new iRet = strcmp(sString, sBuffer, iCaseSensitive)

		if (!iRet) return 0 // Already exists

		if (iRet < 0)
		{
			ArrayInsertStringBefore(aList, i, sString)
			return 1
		}
	}
	ArrayPushString(aList, sString)
	return 1
}

stock fm_RemoveFromSortedList(Array:aList, sString[])
{
	new iIndex = fm_BinarySearch(aList, sString, 0, ArraySize(aList))
	if (iIndex != -1)
	{
		ArrayDeleteItem(aList, iIndex)
		return 1
	}
	return 0
}

stock fm_BinarySearch(Array:aList, sString[], iLow, iHigh, iCaseSensitive = 0)
{
	static sBuffer[1024]

	if (iHigh < iLow)
	{
		return -1 // Not found
	}

	new iMid = iLow + ((iHigh - iLow) / 2)
	ArrayGetString(aList, iMid, sBuffer, charsmax(sBuffer))
	
	new iRet = strcmp(sBuffer, sString, iCaseSensitive)

	if (iRet > 0)
	{
		return fm_BinarySearch(aList, sString, iLow, iMid - 1, iCaseSensitive)
	}
	else if (iRet < 0)
	{
		return fm_BinarySearch(aList, sString, iMid + 1, iHigh, iCaseSensitive)
	}

	return iMid // Found
}
