#if defined _fm_admin_api_included
  #endinput
#endif
#define _fm_admin_api_included

#pragma reqlib "fm_admin_api"

stock const g_sAdminAPILibName[] = "fm_admin_api"

enum eAdmin_t
{
	m_iAdminIdent,
	m_iAdminActive,
	m_sAdminAuthid[MAX_AUTHID_LEN],
	m_iAdminAccess,
	m_sAdminName[MAX_NAME_LEN],
	m_sAdminPassword[32]
}

native fm_AddAdminInfo(Buffer[eAdmin_t])
native fm_GetAdminInfoByIndex(iIndex, Buffer[eAdmin_t])
native fm_GetAdminInfoByIdent(iIdent, Buffer[eAdmin_t])

native fm_GetAdminCount()
native fm_ClearAdminInfo()
native fm_InfoAdminUpdated()

#define ADMIN_ALL			0	/* Everyone */
#define ADMIN_LEVEL_BASIC		(1<<0)	/* flag "a" */
#define ADMIN_LEVEL_ENHANCED		(1<<1)	/* flag "b" */
#define ADMIN_KICK			(1<<2)	/* flag "c" */
#define ADMIN_BAN			(1<<3)	/* flag "d" */
#define ADMIN_SLAY			(1<<4)	/* flag "e" */
#define ADMIN_MAP			(1<<5)	/* flag "f" */
#define ADMIN_CVAR			(1<<6)	/* flag "g" */
#define ADMIN_LEVEL_CFG			(1<<7)	/* flag "h" */

#define ADMIN_CHAT			(1<<8)	/* flag "i" */
#define ADMIN_VOTE			(1<<9)	/* flag "j" */
#define ADMIN_PASSWORD			(1<<10)	/* flag "k" */
#define ADMIN_RCON			(1<<11)	/* flag "l" */
#define ADMIN_LEVEL_A			(1<<12)	/* flag "m" */
#define ADMIN_LEVEL_B			(1<<13)	/* flag "n" */
#define ADMIN_LEVEL_C			(1<<14)	/* flag "o" */
#define ADMIN_LEVEL_D			(1<<15)	/* flag "p" */
#define ADMIN_LEVEL_E			(1<<16)	/* flag "q" */
#define ADMIN_LEVEL_F			(1<<17)	/* flag "r" */
#define ADMIN_LEVEL_G			(1<<18)	/* flag "s" */
#define ADMIN_LEVEL_H			(1<<19)	/* flag "t" */
#define ADMIN_MENU			(1<<20)	/* flag "u" */
#define ADMIN_ADMIN			(1<<24)	/* flag "y" */
#define ADMIN_USER			(1<<25)	/* flag "z" */