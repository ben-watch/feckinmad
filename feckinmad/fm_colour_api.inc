#if defined _fm_colour_included
  #endinput
#endif
#define _fm_colour_included


#pragma reqlib fm_colour_api

#define MAX_COLOURS 128
#define MAX_COLOUR_NAME_LEN 12

native fm_GetColourCount()
native fm_GetColourIndex(sName[])
native fm_GetColourNameByIndex(iIndex, sName[MAX_COLOUR_NAME_LEN])
native fm_GetColoursByIndex(iIndex, iColourValues[3])