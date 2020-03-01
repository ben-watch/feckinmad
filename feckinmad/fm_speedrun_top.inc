#if defined _fm_speedrun_top_included
  #endinput
#endif
#define _fm_speedrun_top_included

#pragma reqlib "fm_speedrun_top"

enum eSpeedTop_t
{
	m_iTopPlayerIdent,
	m_sTopPlayerAuthid[MAX_AUTHID_LEN],
	m_sTopPlayerName[MAX_NAME_LEN],
	m_iTopTime
}


native fm_ReloadSpeedRunData() // Reloads the rank data from the database
native fm_GetSpeedRunRankByIdent(iIdent, Buffer[eSpeedTop_t]) // Get the speedrun data by player ident
native fm_GetSpeedRunRankByTime(iTime) // Gets the rank of the current player if they were to finish with the specified time
native fm_GetSpeedRunTotal() // Get total speedruns
native fm_GetSpeedRunTimeByRank(iRank) // Get the finish time of a speedrun at a specified rank
