#if defined _fm_entmod_move_included
  #endinput
#endif
#define _fm_entmod_move_included

#pragma reqlib "fm_entmod_move"

native fm_GetPlayerMoveEnt(id)
native fm_SetPlayerMoveEnt(id, iEnt, iRed, iGreen, iBlue)
native fm_StopPlayerMoveEnt(id)