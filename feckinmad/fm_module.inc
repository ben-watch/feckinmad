#if defined _fm_module_included
  #endinput
#endif
#define _fm_module_included

#if AMXX_VERSION_NUM >= 175
 #pragma reqclass fm
 #if !defined AMXMODX_NOAUTOLOAD
  #pragma defclasslib fm fm
 #endif
#else
 #pragma library fm
#endif

#define CAMERA_FIRSTPERSON	0
#define CAMERA_THIRDPERSON	1

native set_view(iIndex, ViewType);
