#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <reapi>
#include <xs>

#include <ze_core>

// Defines.
#define EXTRA_ITEM 1   // 1 = Show | 0 = Hide

// Macroses.
#define IsEntClient(%1) (%1 != 0 && 1<=(%1)<=MaxClients)
#define IsWeaponJanusIII(%1) (is_entity(%1) && get_entvar(%1,var_impulse)==WEAPON_UID)
#define SetWeaponFireDelay(%1,%2,%3) set_member(%1,m_Weapon_flNextPrimaryAttack,%2),set_member(%1,m_Weapon_flNextSecondaryAttack,%3)

// -> Zombie Escape: Item Info
#if EXTRA_ITEM == 1
	stock const ZE_ITEM_NAME[] = "Janus-3"
	stock const ZE_ITEM_COST = 25
	stock const ZE_ITEM_LIMIT = 0
#endif

// -> Weapon Info:
new const WEAPON_NAME[] = "weapon_janus3_lz"
new const WEAPON_REFERENCE[] = "weapon_ump45"
new const WEAPON_ANIMEXT[] = "mp5"
const WEAPON_UID = 6146225
const WEAPON_ID = CSW_UMP45
const WEAPON_MAXCLIP = 50
const WEAPON_DEFAULTAMMO = 100
const Float: WEAPON_RECOIL = 0.95
const Float: WEAPON_FIRERATE = 0.099
const Float: WEAPON_DAMAGE = 18.0
const Float: WEAPON_SFIRERATE = 0.08
const Float: WEAPON_SDAMAGE = 34.0
const Float: WEAPON_SPERIOD = 7.0

enum _:eFireSounds
{
	SOUND_JANUS_NORMAL = 0,
	SOUND_JANUS_ACTIVE
}

enum (+=1)
{
	STATE_JANUS_NORMAL = 0,
	STATE_JANUS_SIGNAL,
	STATE_JANUS_ACTIVE
}

// View Anims:
enum (+=1)
{
	ANIM_IDLE1 = 0,
	ANIM_RELOAD1,
	ANIM_DRAW1,
	ANIM_SHOOT1,
	ANIM_SHOOT1_SIGNAL,
	ANIM_CHANGE1,
	ANIM_IDLE2,
	ANIM_DRAW2,
	ANIM_SHOOT2_1,
	ANIM_SHOOT2_2,
	ANIM_SHOOT2_3,
	ANIM_SHOOT2_CHANGE,
	ANIM_SIGNAL,
	ANIM_RELOAD_SIGNAL,
	ANIM_DRAW_SIGNAL
}

const Float: ANIM_TIME_IDLE1 = 1.70
const Float: ANIM_TIME_RELOAD1 = 3.03
const Float: ANIM_TIME_DRAW1 = 1.03
const Float: ANIM_TIME_SHOOT1 = 1.03
const Float: ANIM_TIME_SHOOT1_SIGNAL = 1.03
const Float: ANIM_TIME_CHANGE1 = 1.70
const Float: ANIM_TIME_IDLE2 = 1.70
const Float: ANIM_TIME_DRAW2 = 1.03
const Float: ANIM_TIME_SHOOT2 = 1.03
const Float: ANIM_TIME_CHANGE2 = 2.03
const Float: ANIM_TIME_SIGNAL = 1.70
const Float: ANIM_TIME_RELOAD_SIGNAL = 3.03
const Float: ANIM_TIME_DRAW_SIGNAL = 1.70

// Weapon Models:
new g_v_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/CSO/v_janus3.mdl"
new g_p_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/CSO/p_janus3.mdl"
new g_w_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/CSO/w_janus3.mdl"

// Weapon Sounds:
new const g_szWeaponFireSound[eFireSounds][] =
{
	"weapons/janusmk5-12.wav",
	"weapons/janusmk5-2.wav"
}

// Weapon List:
new const g_szWeaponListRsc[][] =
{
	"sprites/640hudx0.spr",
	"sprites/weapon_janus3_lz.txt"
}

// Variables.
new g_iItemID,
	g_iPosition,
	g_hTraceLine,
	g_iWeaponList

// Array.
new g_iFired[MAX_PLAYERS+1],
	g_iActived[MAX_PLAYERS+1]

public plugin_precache()
{
#if EXTRA_ITEM == 1
	if (!ini_read_string(ZE_ET_FILENAME, ZE_ITEM_NAME, "VIEW_MODEL", g_v_szWeaponModel, charsmax(g_v_szWeaponModel)))
		ini_write_string(ZE_ET_FILENAME, ZE_ITEM_NAME, "VIEW_MODEL", g_v_szWeaponModel)
	if (!ini_read_string(ZE_ET_FILENAME, ZE_ITEM_NAME, "WEAPON_MODEL", g_p_szWeaponModel, charsmax(g_p_szWeaponModel)))
		ini_write_string(ZE_ET_FILENAME, ZE_ITEM_NAME, "WEAPON_MODEL", g_p_szWeaponModel)
	if (!ini_read_string(ZE_ET_FILENAME, ZE_ITEM_NAME, "WORLD_MODEL", g_w_szWeaponModel, charsmax(g_w_szWeaponModel)))
		ini_write_string(ZE_ET_FILENAME, ZE_ITEM_NAME, "WORLD_MODEL", g_w_szWeaponModel)
#endif

	// Pre-load Models.
	precache_model(g_v_szWeaponModel)
	precache_model(g_p_szWeaponModel)
	precache_model(g_w_szWeaponModel)

	new const szWeaponSounds[][] =
	{
		"sound/weapons/janus3_draw.wav",
		"sound/weapons/janus3_boltpull1.wav",
		"sound/weapons/janus3_boltpull2.wav",
		"sound/weapons/janus3_change1.wav",
		"sound/weapons/janus3_change2.wav",
		"sound/weapons/janus3_clipin.wav",
		"sound/weapons/janus3_clipout.wav"
	}

	new i

	// Pre-load Sounds.
	for (i = 0; i < sizeof(g_szWeaponFireSound); i++)
		precache_sound(g_szWeaponFireSound[i])

	// Pre-load More.
	for (i = 0; i < sizeof(g_szWeaponListRsc); i++)
		precache_generic(g_szWeaponListRsc[i])

	// Pre-load model sounds.
	for (i = 0; i < sizeof(szWeaponSounds); i++)
		precache_generic(szWeaponSounds[i])
}

public plugin_init()
{
	// Load Plug-In.
	register_plugin("[ZE] Extra Item: Janus-3", "1.2", "z0h1r-LK")

	// Hook Chains.
	RegisterHookChain(RG_CWeaponBox_SetModel, "fw_WeaponBox_SetModel_Pre")
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "fw_Weapon_DefaultDeploy_Pre")
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultReload, "fw_Weapon_DefaultReload_Pre")

	// Hams.
	RegisterHam(Ham_Spawn, WEAPON_REFERENCE, "fw_Weapon_Spawn_Post", 1)
	//RegisterHam(Ham_Think, WEAPON_REFERENCE, "fw_Weapon_Think_Pre")
	RegisterHam(Ham_Weapon_WeaponIdle, WEAPON_REFERENCE, "fw_Weapon_WeaponIdle_Pre")
	RegisterHam(Ham_Weapon_PrimaryAttack, WEAPON_REFERENCE, "fw_Weapon_PrimaryAttack_Pre")
	RegisterHam(Ham_Weapon_SecondaryAttack, WEAPON_REFERENCE, "fw_Weapon_SecondaryAttack_Pre")
	RegisterHam(Ham_Item_AddToPlayer, WEAPON_REFERENCE, "fw_Weapon_AddToPlayer_Post", 1)
	RegisterHam(Ham_RemovePlayerItem, WEAPON_REFERENCE, "fw_Weapon_RemoveItem_Post", 1)

	// FakeMeta.
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent_Pre")
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)

	// Commands.
	register_clcmd(WEAPON_NAME, "cmd_SelectWeapon")

#if EXTRA_ITEM == 1
	// Extra Item.
	g_iItemID = ze_item_register(ZE_ITEM_NAME, ZE_ITEM_COST, ZE_ITEM_LIMIT)
#endif

	// Set Values.
	g_iWeaponList = get_user_msgid("WeaponList")
	g_iPosition = rg_get_global_iteminfo(CSW_UMP45, ItemInfo_iPosition)
}

public client_disconnected(id, bool:drop, message[], maxlen)
{
	if (is_user_hltv(id))
		return;

	g_iFired[id] = 0
	g_iActived[id] = 0
}

public cmd_SelectWeapon(const id, level, cid)
{
	engclient_cmd(id, WEAPON_REFERENCE)
	return PLUGIN_HANDLED;
}

#if EXTRA_ITEM == 1
public ze_select_item_pre(id, iItem, bool:bIgnoreCost, bool:bInMenu)
{
	if (iItem != g_iItemID)
		return ZE_ITEM_AVAILABLE;

	if (ze_is_user_zombie(id))
		return ZE_ITEM_DONT_SHOW;

	return ZE_ITEM_AVAILABLE;
}

public ze_select_item_post(id, iItem, bool:bIgnoreCost)
{
	if (iItem != g_iItemID)
		return;

	give_JanusIII(id)
}
#endif

public fw_PlaybackEvent_Pre( ) <FireBullets: Enabled>
	return FMRES_SUPERCEDE;

public fw_PlaybackEvent_Pre( ) <FireBullets: Disabled>
	return FMRES_IGNORED;

public fw_PlaybackEvent_Pre( ) < >
	return FMRES_IGNORED;

public fw_UpdateClientData_Post(const id, sendweapons, cd_handle)
{
	if (!is_user_alive(id))
		return FMRES_IGNORED;

	if (IsWeaponJanusIII(get_member(id, m_pActiveItem)))
	{
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001)
		return FMRES_HANDLED;
	}

	return FMRES_IGNORED;
}

public give_JanusIII(const id)
{
	new iWpnEnt
	if ((iWpnEnt = rg_give_custom_item(id, WEAPON_REFERENCE, GT_DROP_AND_REPLACE, WEAPON_UID)) == NULLENT)
	{
		log_error(AMX_ERR_NOTFOUND, "[Zombie Escape] Invalid Weapon Index (-1)")
	}
	else
	{
		if (get_member(id, m_pActiveItem) == iWpnEnt)
			rg_weapon_deploy(iWpnEnt, g_v_szWeaponModel, g_p_szWeaponModel, ANIM_DRAW1, WEAPON_ANIMEXT)

		rg_set_user_bpammo(id, WeaponIdType:WEAPON_ID, WEAPON_DEFAULTAMMO)
	}
}

public fw_WeaponBox_SetModel_Pre(const iEnt, const szModel[])
{
	if (!is_entity(iEnt))
		return;

	if (IsWeaponJanusIII(get_member(iEnt, m_WeaponBox_rgpPlayerItems, PRIMARY_WEAPON_SLOT)))
		SetHookChainArg(2, ATYPE_STRING, g_w_szWeaponModel)
}

public fw_Weapon_DefaultDeploy_Pre(const iWpnEnt, const szViewModel[], const szWeaponModel[], iAnim, const szAnimExt[], skiplocal)
{
	if (!IsWeaponJanusIII(iWpnEnt))
		return;

	if (g_v_szWeaponModel[0])
		SetHookChainArg(2, ATYPE_STRING, g_v_szWeaponModel)

	if (g_p_szWeaponModel[0])
		SetHookChainArg(3, ATYPE_STRING, g_p_szWeaponModel)

	switch (get_member(iWpnEnt, m_Weapon_iWeaponState))
	{
		case STATE_JANUS_NORMAL:
			SetHookChainArg(4, ATYPE_INTEGER, ANIM_DRAW1)
		case STATE_JANUS_SIGNAL:
			SetHookChainArg(4, ATYPE_INTEGER, ANIM_DRAW_SIGNAL)
		case STATE_JANUS_ACTIVE:
			SetHookChainArg(4, ATYPE_INTEGER, ANIM_DRAW2)
	}

	SetHookChainArg(5, ATYPE_STRING, WEAPON_ANIMEXT)
}

public fw_Weapon_DefaultReload_Pre(const iWpnEnt, iClipSize, iAnim, Float:flDelay)
{
	if (!IsWeaponJanusIII(iWpnEnt))
		return HC_CONTINUE;

	switch (get_member(iWpnEnt, m_Weapon_iWeaponState))
	{
		case STATE_JANUS_ACTIVE:
		{
			SetHookChainReturn(ATYPE_INTEGER, HC_SUPERCEDE)
			return HC_SUPERCEDE;
		}
		case STATE_JANUS_NORMAL:
		{
			SetHookChainArg(3, ATYPE_INTEGER, ANIM_RELOAD1)
			SetHookChainArg(4, ATYPE_FLOAT, ANIM_TIME_RELOAD1)
		}
		case STATE_JANUS_SIGNAL:
		{
			SetHookChainArg(3, ATYPE_INTEGER, ANIM_RELOAD_SIGNAL)
			SetHookChainArg(4, ATYPE_FLOAT, ANIM_TIME_RELOAD_SIGNAL)
		}
	}

	SetHookChainArg(2, ATYPE_INTEGER, WEAPON_MAXCLIP)
	return HC_CONTINUE;
}

public fw_Weapon_Spawn_Post(const iWpnEnt)
{
	if (!IsWeaponJanusIII(iWpnEnt))
		return;

	set_member(iWpnEnt, m_Weapon_iClip, WEAPON_MAXCLIP)
	set_member(iWpnEnt, m_Weapon_iDefaultAmmo, WEAPON_DEFAULTAMMO)
	set_member(iWpnEnt, m_Weapon_flBaseDamage, WEAPON_DAMAGE)
	set_member(iWpnEnt, m_Weapon_bHasSecondaryAttack, true)

	rg_set_iteminfo(iWpnEnt, ItemInfo_iMaxClip, WEAPON_MAXCLIP)
	rg_set_iteminfo(iWpnEnt, ItemInfo_iMaxAmmo1, WEAPON_DEFAULTAMMO)
}

public fw_Janus3Think_Pre(const iWpnEnt)
{
	static Float: flRefTime; flRefTime = get_gametime()

	if (get_entvar(iWpnEnt, var_fuser4) <= flRefTime)
	{
		new const clientIndex = get_member(iWpnEnt, m_pPlayer)
		if (clientIndex != NULLENT)
		{
			rg_weapon_send_animation(clientIndex, ANIM_SHOOT2_CHANGE)
			set_member(iWpnEnt, m_Weapon_flTimeWeaponIdle, ANIM_TIME_CHANGE2)
			set_member(iWpnEnt, m_Weapon_flNextPrimaryAttack, ANIM_TIME_CHANGE2)
			set_member(iWpnEnt, m_Weapon_flNextSecondaryAttack, ANIM_TIME_CHANGE2)
			g_iActived[clientIndex] = 0
		}

		set_entvar(iWpnEnt, var_iuser4, 0)
		set_member(iWpnEnt, m_Weapon_iWeaponState, STATE_JANUS_NORMAL)
		set_member(iWpnEnt, m_Weapon_flBaseDamage, WEAPON_DAMAGE)

		SetThink(iWpnEnt, "")
		return;
	}

	set_entvar(iWpnEnt, var_nextthink, flRefTime + 0.2)
}

public fw_Weapon_WeaponIdle_Pre(const iWpnEnt)
{
	if (!IsWeaponJanusIII(iWpnEnt))
		return HAM_IGNORED;

	if (get_member(iWpnEnt, m_Weapon_flTimeWeaponIdle) > 0.0)
		return HAM_SUPERCEDE;

	switch (get_member(iWpnEnt, m_Weapon_iWeaponState))
	{
		case STATE_JANUS_NORMAL:
		{
			rg_weapon_send_animation(iWpnEnt, ANIM_IDLE1)
			set_member(iWpnEnt, m_Weapon_flTimeWeaponIdle, ANIM_TIME_IDLE1)
		}
		case STATE_JANUS_SIGNAL:
		{
			rg_weapon_send_animation(iWpnEnt, ANIM_SIGNAL)
			set_member(iWpnEnt, m_Weapon_flTimeWeaponIdle, ANIM_TIME_SIGNAL)
		}
		case STATE_JANUS_ACTIVE:
		{
			rg_weapon_send_animation(iWpnEnt, ANIM_IDLE2)
			set_member(iWpnEnt, m_Weapon_flTimeWeaponIdle, ANIM_TIME_IDLE2)
		}
	}

	return HAM_SUPERCEDE;
}

public fw_Weapon_PrimaryAttack_Pre(const iWpnEnt)
{
	if (!IsWeaponJanusIII(iWpnEnt))
		return HAM_IGNORED;

	static iClipSize; iClipSize = get_member(iWpnEnt, m_Weapon_iClip)
	if (iClipSize <= 0)
	{
		ExecuteHamB(Ham_Weapon_PlayEmptySound, iWpnEnt)
		set_member(iWpnEnt, m_Weapon_flNextPrimaryAttack, 0.2)
		return HAM_SUPERCEDE;
	}

	static clientIndex; clientIndex = get_member(iWpnEnt, m_pPlayer)

	state FireBullets: Enabled
	g_hTraceLine = register_forward(FM_TraceLine, "fw_TraceLine_Post", 1)
	ExecuteHam(Ham_Weapon_PrimaryAttack, iWpnEnt)
	unregister_forward(FM_TraceLine, g_hTraceLine, 1)
	state FireBullets: Disabled

	static iWpnState; iWpnState = get_member(iWpnEnt, m_Weapon_iWeaponState)
	switch (iWpnState)
	{
		case STATE_JANUS_NORMAL:
		{
			set_member(iWpnEnt, m_Weapon_flTimeWeaponIdle, ANIM_TIME_SHOOT1_SIGNAL)
			emit_sound(clientIndex, CHAN_WEAPON, g_szWeaponFireSound[SOUND_JANUS_NORMAL], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
			rg_weapon_send_animation(clientIndex, ANIM_SHOOT1)
		}
		case STATE_JANUS_SIGNAL:
		{
			set_member(iWpnEnt, m_Weapon_flTimeWeaponIdle, ANIM_TIME_SHOOT1_SIGNAL)
			emit_sound(clientIndex, CHAN_WEAPON, g_szWeaponFireSound[SOUND_JANUS_NORMAL], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
			rg_weapon_send_animation(clientIndex, ANIM_SHOOT1_SIGNAL)
		}
		case STATE_JANUS_ACTIVE:
		{
			set_member(iWpnEnt, m_Weapon_flTimeWeaponIdle, ANIM_TIME_SHOOT2)
			emit_sound(clientIndex, CHAN_WEAPON, g_szWeaponFireSound[SOUND_JANUS_ACTIVE], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
			rg_weapon_send_animation(clientIndex, random_num(ANIM_SHOOT2_1, ANIM_SHOOT2_3))
			set_member(iWpnEnt, m_Weapon_iClip, iClipSize)
		}
	}

	static Float: vRecoil[3]
	get_entvar(clientIndex, var_punchangle, vRecoil)
	xs_vec_mul_scalar(vRecoil, WEAPON_RECOIL, vRecoil)
	set_entvar(clientIndex, var_punchangle, vRecoil)

	switch (iWpnState)
	{
		case STATE_JANUS_NORMAL, STATE_JANUS_SIGNAL:
			SetWeaponFireDelay(iWpnEnt, WEAPON_FIRERATE, WEAPON_FIRERATE)
		case STATE_JANUS_ACTIVE:
			SetWeaponFireDelay(iWpnEnt, WEAPON_SFIRERATE, WEAPON_SFIRERATE)
	}

	return HAM_SUPERCEDE;
}

public fw_Weapon_SecondaryAttack_Pre(const iWpnEnt)
{
	if (!IsWeaponJanusIII(iWpnEnt))
		return HAM_IGNORED;

	static iWpnState; iWpnState = get_member(iWpnEnt, m_Weapon_iWeaponState)
	switch (iWpnState)
	{
		case STATE_JANUS_NORMAL, STATE_JANUS_ACTIVE:
		{
			set_member(iWpnEnt, m_Weapon_flNextSecondaryAttack, 0.2)
			return HAM_SUPERCEDE;
		}
		case STATE_JANUS_SIGNAL:
		{
			new const clientIndex = get_member(iWpnEnt, m_pPlayer)
			rg_weapon_send_animation(iWpnEnt, ANIM_CHANGE1)

			set_member(iWpnEnt, m_Weapon_iWeaponState, STATE_JANUS_ACTIVE)
			set_member(iWpnEnt, m_Weapon_flTimeWeaponIdle, ANIM_TIME_CHANGE1)
			set_member(iWpnEnt, m_Weapon_flBaseDamage, WEAPON_SDAMAGE)

			new const Float:flHlTime = get_gametime()
			SetThink(iWpnEnt, "fw_Janus3Think_Pre")
			set_entvar(iWpnEnt, var_fuser4, flHlTime + WEAPON_SPERIOD)
			set_entvar(iWpnEnt, var_nextthink, flHlTime + ANIM_TIME_CHANGE1)

			SetWeaponFireDelay(iWpnEnt, ANIM_TIME_CHANGE1, ANIM_TIME_CHANGE1)
			g_iActived[clientIndex] = 1
			g_iFired[clientIndex] = 0
		}
	}

	return HAM_SUPERCEDE;
}

public fw_TraceLine_Post(const Float:vStart[3], const Float:vEnd[3], iFlags, clientIndex, hTrace)
{
	if (iFlags & IGNORE_MONSTERS)
		return;

	static iHitEnt; iHitEnt = get_tr2(hTrace, TR_pHit)
	if (!g_iActived[clientIndex])
	{
		if (iHitEnt > 0)
		{
			if (IsEntClient(iHitEnt) && g_iFired[clientIndex] <= 50)
			{
				if (++g_iFired[clientIndex] >= 50)
				{
					static iWpnEnt; iWpnEnt = get_member(clientIndex, m_pActiveItem)
					if (IsWeaponJanusIII(iWpnEnt))
						set_member(iWpnEnt, m_Weapon_iWeaponState, STATE_JANUS_SIGNAL)

				}
			}
		}
	}

	if (iHitEnt > 0) if (get_entvar(iHitEnt, var_solid) != SOLID_BSP) return;

	static Float: vDecal[3]
	get_tr2(hTrace, TR_vecEndPos, vDecal)

	// Decal.
	message_begin_f(MSG_PVS, SVC_TEMPENTITY, vDecal)
	write_byte(TE_GUNSHOTDECAL) // TE id.
	write_coord_f(vDecal[0]) // Position X.
	write_coord_f(vDecal[1]) // Position Y.
	write_coord_f(vDecal[2]) // Position Z.
	write_short(iHitEnt > 0 ? iHitEnt : 0) // Entity Index.
	write_byte(random_num(41, 45)) // Decal Index.
	message_end()
}

public fw_Weapon_AddToPlayer_Post(const iWpnEnt, const clientIndex)
{
	if (!IsWeaponJanusIII(iWpnEnt))
		return;

	if (get_entvar(iWpnEnt, var_fuser4) <= get_gametime())
	{
		set_member(iWpnEnt, m_Weapon_flBaseDamage, WEAPON_SDAMAGE)
		set_member(iWpnEnt, m_Weapon_iWeaponState, STATE_JANUS_NORMAL)
	}

	WeaponList(clientIndex, 1)
	g_iFired[clientIndex] = get_entvar(iWpnEnt, var_iuser3)
	g_iActived[clientIndex] = get_entvar(iWpnEnt, var_iuser4)
	set_member(iWpnEnt, m_Weapon_iWeaponState, get_entvar(iWpnEnt, var_iuser2))
}

public fw_Weapon_RemoveItem_Post(const iWpnEnt, const clientIndex)
{
	if (!IsWeaponJanusIII(iWpnEnt))
		return;

	if (clientIndex != NULLENT)
	{
		set_entvar(iWpnEnt, var_iuser3, g_iFired[clientIndex])
		set_entvar(iWpnEnt, var_iuser4, g_iActived[clientIndex])

		g_iActived[clientIndex] = 0
		g_iFired[clientIndex] = 0
	}

	WeaponList(clientIndex, 0)
	set_entvar(iWpnEnt, var_iuser2, get_member(iWpnEnt, m_Weapon_iWeaponState))
	SetThink(iWpnEnt, "")
}

WeaponList(const id, const iMode = 0)
{
	message_begin(MSG_ONE, g_iWeaponList, .player = id)
	write_string(iMode ? WEAPON_NAME : WEAPON_REFERENCE) // Weapon Name.
	write_byte(6) // Primary Ammo ID.
	write_byte(WEAPON_DEFAULTAMMO) // Primary Ammo Max Amount.
	write_byte(NULLENT) // Secondary Ammo ID.
	write_byte(NULLENT) // Secondary Ammo Max Amount.
	write_byte(0) // SlotID.
	write_byte(g_iPosition) // Number in slot.
	write_byte(WEAPON_ID) // Weapon ID.
	write_byte(0) // Flags
	message_end()
}