native fm_StartMapVote(iFill)
native fm_GetMapVoteStatus()

new const g_sTextNextMap[] = "* Players have voted for \"%s\" as the next map and it will be loaded shortly"
new const g_sTextInProgress[] = "Map voting is currently in progress"

enum {
	VOTING_INACTIVE, // Nothing is happening
	VOTING_STARTING, // Vote is starting up. Countdown etc
	VOTING_SELECT, // Vote has started. Players are selecting the map
	VOTING_CHANGING // Players have selected to change the map
}
