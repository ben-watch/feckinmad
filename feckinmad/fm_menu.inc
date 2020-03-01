#if defined _fm_menu_included
  #endinput
#endif
#define _fm_menu_included

#define MAX_MENU_STRING 512
#define ALL_MENU_KEYS (1<<0|1<<1|1<<2|1<<3|1<<4|1<<5|1<<6|1<<7|1<<8|1<<9) 

#define fm_GetMenuPageMax(%1,%2) (%1 / %2 + ((%1 % %2) ? 1 : 0 ))
#define fm_GetMenuKeyNum(%1) ((%1 == 9) ? 0 : %1 + 1)

stock const FM_MENU_SELECT_SOUND[] = "fm/menuselect.wav"