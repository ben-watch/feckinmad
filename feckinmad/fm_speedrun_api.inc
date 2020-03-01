#if defined _fm_speedrun_api_included
  #endinput
#endif
#define _fm_speedrun_api_included

#pragma reqlib "fm_speedrun_api"

#define SPEED_TIME_IN_SECOND 100
#define SPEED_TIME_IN_MINUTE 6000

enum
{
	STATUS_SPEEDRUN_LOADING,
	STATUS_SPEEDRUN_DISABLED,
	STATUS_SPEEDRUN_ENABLED
}

native fm_GetSpeedRunStatus(id)
native fm_ReadyToSpeedRun() 
native fm_IsUserSpeedRunning(id)
native fm_GetUserSpeedRunTime(id)
native fm_StartSpeedRunning(id)
native fm_StopSpeedRunning(id, iAborted)

stock fm_FormatSpeedRunTime(iTime, sTime[], iLen)
{
	new iHuns = iTime % 100
	new iSecs = iTime / 100
	new iMins = iSecs / 60
	iSecs %= 60

	formatex(sTime, iLen, "%02d:%02d:%02d", iMins, iSecs, iHuns)
}

stock fm_SpeedRunTimeToText(iTime, sTime[], iLen, iShort = 0)
{	
	new iPos
		
	if (iTime < 0)
	{
		iTime *= -1
		iPos = formatex(sTime, iLen, "minus")
	}

	new iSecondCount = iTime / SPEED_TIME_IN_SECOND
	iTime -= (iSecondCount * SPEED_TIME_IN_SECOND)
	
	new iMinuteCount = iTime / SPEED_TIME_IN_MINUTE
        iTime -= (iMinuteCount * SPEED_TIME_IN_MINUTE)

        if (iMinuteCount > 0)
		iPos += formatex(sTime[iPos], iLen - iPos, "%s%d%s", iPos ? " " : "", iMinuteCount, iShort ? "m" : (iMinuteCount == 1) ? " min" : " mins")

        if (iSecondCount > 0)
		iPos += formatex(sTime[iPos], iLen - iPos, "%s%d%s", iPos ? " " : "", iSecondCount, iShort ? "s" : (iSecondCount == 1) ? " sec" : " secs")

        if (iTime > 0 || (!iMinuteCount && !iSecondCount))
		iPos += formatex(sTime[iPos], iLen - iPos, "%s%d%s", iPos ? " " : "", iTime, iShort ? "ms" : (iTime == 1) ? " ms" : " milliseconds")
	
	return 1
}