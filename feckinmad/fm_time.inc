#if defined _fm_time_included
  #endinput
#endif
#define _fm_time_included

#define SECONDS_IN_MINUTE 60
#define SECONDS_IN_HOUR 3600
#define SECONDS_IN_DAY 86400
#define SECONDS_IN_WEEK 604800 

// Modified stock from time.inc
stock fm_SecondsToText(iSecs, sTime[], iLen, iShort = 0)
{	
	new iPos
		
	if (iSecs < 0)
	{
		iSecs *= -1
		iPos = formatex(sTime, iLen, " minus")
	}

	new iWeekCount = iSecs / SECONDS_IN_WEEK
        iSecs -= (iWeekCount * SECONDS_IN_WEEK)

	new iDayCount = iSecs / SECONDS_IN_DAY
        iSecs -= (iDayCount * SECONDS_IN_DAY)

	new iHourCount = iSecs / SECONDS_IN_HOUR
        iSecs -= (iHourCount * SECONDS_IN_HOUR)

	new iMinuteCount = iSecs / SECONDS_IN_MINUTE
        iSecs -= (iMinuteCount * SECONDS_IN_MINUTE)

        if (iWeekCount > 0)
		iPos += formatex(sTime[iPos], iLen - iPos, "%s%d%s", iPos ? " " : "", iWeekCount, iShort ? "w" : (iWeekCount == 1) ? " week" : " weeks")

        if (iDayCount > 0)
		iPos += formatex(sTime[iPos], iLen - iPos, "%s%d%s", iPos ? " " : "", iDayCount, iShort ? "d" : (iDayCount == 1) ? " day" : " days")    

        if (iHourCount > 0)
		iPos += formatex(sTime[iPos], iLen - iPos, "%s%d%s", iPos ? " " : "", iHourCount, iShort ? "h" : (iHourCount == 1) ? " hour" : " hours")

        if (iMinuteCount > 0)
		iPos += formatex(sTime[iPos], iLen - iPos, "%s%d%s", iPos ? " " : "", iMinuteCount, iShort ? "m" : (iMinuteCount == 1) ? " min" : " mins")

        if (iSecs > 0 || (!iWeekCount && !iDayCount && !iHourCount && !iMinuteCount))
		iPos += formatex(sTime[iPos], iLen - iPos, "%s%d%s", iPos ? " " : "", iSecs, iShort ? "s" : (iSecs == 1) ? " sec" : " secs")
	
	return 1
}
