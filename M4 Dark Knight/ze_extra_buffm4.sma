#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <engine>
#include <reapi>
#include <xs>
#include <ze_core>

/**
 * This will allows you to enable or disable it in Extra Item (1 = Enabled | 0 = Disabled).
 */
#define ZE_EXTRA_ITEM   1

// Macroses.
#define is_Weap_BuffM4(%1) (is_entity(%1) && get_entvar(%1, var_impulse) == WEAPON_UID)

// CWeapon: Item Info
#define WEAPON_CLASSNAME   "weapon_buffm4_lz"
#define WEAPON_REFERENCE   "weapon_m4a1"
#define WEAPON_ANIMEXT     "rifle"
#define WEAPON_ID          CSW_M4A1
#define WEAPON_UID         120952926
#define WEAPON_MAXCLIP     50
#define WEAPON_MAXAMMO     90
#define WEAPON_DAMAGE      35
#define WEAPON_FIRERATE    0.099
#define WEAPON_ACCURACY    0.9
#define WEAPON_RECOIL      0.84
#define WEAPON_SP_FOV      85
#define WEAPON_SP_DAMAGE   110
#define WEAPON_SP_FIRERATE 0.3
#define WEAPON_SP_TIME     0.1  // don't care.

#define MFLASH_CLASSNAME   "buffm4_mflash"
#define MFLASH_REFERENCE   "info_target"
#define MFLASH_SPRSCALE    0.08
#define MFLASH_ED_CRITIC   100  // Hardcoded.
#define MFLASH_STATUS      1

#define BEAM_CLASSNAME     "buffm4_trace"
#define BEAM_REFERENCE     "beam"
#define BEAM_ED_CRITIC     100

// Zombie Escape: Item Info
#define ZE_ITEM_NAME       "M4 Dark Knight"
#define ZE_ITEM_COST       45
#define ZE_ITEM_LIMIT      0

// Animations.
enum (+=1)
{
	ANIM_IDLE = 0,
	ANIM_RELOAD,
	ANIM_DRAW,
	ANIM_SHOOT1,
	ANIM_SHOOT2,
	ANIM_SHOOT3
}

enum (+=1)
{
	WPN_STATE_NORMAL = 0,
	WPN_STATE_SPECIAL
}

enum _:FIRE_SOUNDS
{
	Sound_FireNormal = 0,
	Sound_FireSpecial
}

#define ANIMT_IDLE   1.70
#define ANIMT_RELOAD 1.93
#define ANIMT_SHOOT  1.55
#define ANIMT_DRAW   1.03

// Weapon Resources:
new g_v_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/CSO/v_buffm4.mdl"
new g_p_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/CSO/p_buffm4.mdl"
new g_w_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/CSO/w_buffm4.mdl"

new const g_szFireSound[FIRE_SOUNDS][] = { "weapons/CSO/m4a1buff-1.wav", "weapons/CSO/m4a1buff-2.wav" }

#if MFLASH_STATUS == 1
new const g_szMuzzleFlashSprite[] = "sprites/CSO/ef_buffm4_mflash.spr"
#endif

// Variables.
new g_iSetFOV,
	g_iBeamSpr,
	g_hTraceLine,
	g_iWeaponList,
	g_iShotsFired

#if ZE_EXTRA_ITEM == 1
new g_iItemId
#endif

#if MFLASH_STATUS == 1
new Float:g_maxSprFrames
#endif

// Array.
new g_bLeftHand[MAX_PLAYERS+1]

public plugin_precache()
{
	// Read Weapon Models from INI file.
	if (!ini_read_string(ZE_FILENAME, "Weapon Models", "V_BUFFM4", g_v_szWeaponModel, charsmax(g_v_szWeaponModel)))
		ini_write_string(ZE_FILENAME, "Weapon Models", "V_BUFFM4", g_v_szWeaponModel)
	if (!ini_read_string(ZE_FILENAME, "Weapon Models", "P_BUFFM4", g_p_szWeaponModel, charsmax(g_p_szWeaponModel)))
		ini_write_string(ZE_FILENAME, "Weapon Models", "P_BUFFM4", g_p_szWeaponModel)
	if (!ini_read_string(ZE_FILENAME, "Weapon Models", "W_BUFFM4", g_w_szWeaponModel, charsmax(g_w_szWeaponModel)))
		ini_write_string(ZE_FILENAME, "Weapon Models", "W_BUFFM4", g_w_szWeaponModel)

	new const szBeamSprite[] = "sprites/laserbeam.spr"

	// Pre-load the Models.
	precache_model(g_v_szWeaponModel)
	precache_model(g_p_szWeaponModel)
	precache_model(g_w_szWeaponModel)

	g_iBeamSpr = precache_model(szBeamSprite)

#if MFLASH_STATUS == 1
	g_maxSprFrames = float(engfunc(EngFunc_ModelFrames, precache_model(g_szMuzzleFlashSprite)))
#endif

	// Pre-load the Sounds.
	for (new i = 0; i < sizeof(g_szFireSound); i++)
		precache_sound(g_szFireSound[i])

	new const szWeaponResources[][] =
	{
		/* sounds */
		"sound/weapons/CSO/m4a1buff_clipin1.wav",
		"sound/weapons/CSO/m4a1buff_clipin2.wav",
		"sound/weapons/CSO/m4a1buff_clipout.wav",
		"sound/weapons/CSO/m4a1buff_idle.wav",

		/* weaponlist */
		"sprites/weapon_buffm4_lz.txt",
		"sprites/640hudc5.spr",
		"sprites/640hudc6.spr"
	}

	for (new i = 0; i < sizeof(szWeaponResources); i++)
		precache_generic(szWeaponResources[i])
}

public plugin_init()
{
	// Load Plug-In.
	register_plugin("[ZE] Extra Item: M4 Dark Knight", "1.0", "z0h1r-LK")

	// Hook Chains.
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "fw_Weapon_DefaultDeploy_Pre")
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultReload, "fw_Weapon_DefaultReload_Pre")
	RegisterHookChain(RG_CBasePlayer_RemovePlayerItem, "fw_RemovePlayerItem_Post", 1)
	RegisterHookChain(RG_CWeaponBox_SetModel, "fw_WeaponBox_SetModel_Pre")

	// Hams.
	RegisterHam(Ham_Spawn, WEAPON_REFERENCE, "fw_Weapon_Spawn_Post", 1)
	RegisterHam(Ham_Weapon_WeaponIdle, WEAPON_REFERENCE, "fw_Weapon_WeaponIdle_Pre")
	RegisterHam(Ham_Weapon_PrimaryAttack, WEAPON_REFERENCE, "fw_Weapon_PrimaryAttack_Pre")
	RegisterHam(Ham_Weapon_SecondaryAttack, WEAPON_REFERENCE, "fw_Weapon_SecondaryAttack_Pre")
	RegisterHam(Ham_Item_AttachToPlayer, WEAPON_REFERENCE, "fw_Weapon_AttachToPlayer_Post", 1)
	RegisterHam(Ham_Item_Holster, WEAPON_REFERENCE, "fw_Weapon_Holster_Post", 1)

	// FakeMeta.
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent_Pre")
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)

	// Commands.
	register_clcmd(WEAPON_CLASSNAME, "cmd_SelectWeapon")

	// Zombie Escape: Extra Item.
#if ZE_EXTRA_ITEM == 1
	g_iItemId = ze_item_register(ZE_ITEM_NAME, ZE_ITEM_COST, ZE_ITEM_LIMIT)
#endif

	// Set Values.
	g_iSetFOV = get_user_msgid("SetFOV")
	g_iWeaponList = get_user_msgid("WeaponList")
}

public cmd_SelectWeapon(const id, level, cid)
{
	engclient_cmd(id, WEAPON_REFERENCE)
	return PLUGIN_HANDLED
}

public client_disconnected(id, bool:drop, message[], maxlen)
{
	if (is_user_hltv(id))
		return

	g_bLeftHand[id] = 0
}

#if ZE_EXTRA_ITEM == 1
public ze_select_item_pre(id, iItem, bool:bIgnoreCost, bool:bInMenu)
{
	if (iItem != g_iItemId)
		return ZE_ITEM_AVAILABLE

	if (ze_is_user_zombie(id))
		return ZE_ITEM_DONT_SHOW

	return ZE_ITEM_AVAILABLE
}

public ze_select_item_post(id, iItem, bool:bIgnoreCost)
{
	if (iItem != g_iItemId)
		return

	give_M4DarkKnight(id)
}
#endif

public give_M4DarkKnight(const iPlayer)
{
	if (rg_give_custom_item(iPlayer, WEAPON_REFERENCE, GT_DROP_AND_REPLACE, WEAPON_UID) == NULLENT)
	{
		log_error(AMX_ERR_GENERAL, "[ZE] Invalid Weapon Index (-1)")
		return
	}

	rg_set_user_bpammo(iPlayer, WeaponIdType:WEAPON_ID, WEAPON_MAXAMMO)
}

public fw_PlaybackEvent_Pre() < /* no statement */ >
	return FMRES_IGNORED

public fw_PlaybackEvent_Pre() <FireBullets: Disabled>
	return FMRES_IGNORED

public fw_PlaybackEvent_Pre() <FireBullets: Enabled>
	return FMRES_SUPERCEDE

public fw_UpdateClientData_Post(const id, sendweapons, cd_handle)
{
	if (get_cd(cd_handle, CD_DeadFlag) != DEAD_NO)
		return FMRES_IGNORED

	if (is_Weap_BuffM4(get_member(id, m_pActiveItem)))
	{
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001)
		return FMRES_HANDLED
	}

	return FMRES_IGNORED
}

public fw_Weapon_Spawn_Post(const iWpnEnt)
{
	if (!is_Weap_BuffM4(iWpnEnt))
		return

	set_member(iWpnEnt, m_Weapon_iClip, WEAPON_MAXCLIP)
	set_member(iWpnEnt, m_Weapon_flBaseDamage, WEAPON_DAMAGE)
	set_member(iWpnEnt, m_Weapon_iDefaultAmmo, WEAPON_MAXAMMO)
	set_member(iWpnEnt, m_Weapon_flAccuracy, WEAPON_ACCURACY)

	rg_set_iteminfo(iWpnEnt, ItemInfo_iMaxClip, WEAPON_MAXCLIP)
	rg_set_iteminfo(iWpnEnt, ItemInfo_iMaxAmmo1, WEAPON_MAXAMMO)
}

public fw_Weapon_AttachToPlayer_Post(const iWpnEnt, const iPlayer)
{
	if (!is_Weap_BuffM4(iWpnEnt))
		return

	send_WeaponList_msg(iPlayer, 1)
}

public fw_RemovePlayerItem_Post(const iPlayer, const iWpnEnt)
{
	if (!is_Weap_BuffM4(iWpnEnt))
		return

	send_WeaponList_msg(iPlayer)
	ResetSpecialAbility(iWpnEnt, iPlayer)
}

public fw_Weapon_DefaultDeploy_Pre(const iWpnEnt)
{
	if (!is_Weap_BuffM4(iWpnEnt))
		return

	if (g_v_szWeaponModel[0])
		SetHookChainArg(2, ATYPE_STRING, g_v_szWeaponModel)

	if (g_p_szWeaponModel[0])
		SetHookChainArg(3, ATYPE_STRING, g_p_szWeaponModel)

	SetHookChainArg(4, ATYPE_INTEGER, ANIM_DRAW)
	SetHookChainArg(5, ATYPE_STRING, WEAPON_ANIMEXT)

	rp_weapon_set_nextattack(iWpnEnt, ANIMT_DRAW, ANIMT_DRAW, ANIMT_DRAW)
	query_client_cvar(get_member(iWpnEnt, m_pPlayer), "cl_righthand", "clcvar_RightHand")
}

public fw_Weapon_Holster_Post(const iWpnEnt)
{
	if (!is_Weap_BuffM4(iWpnEnt))
		return

	ResetSpecialAbility(iWpnEnt)
}

public clcvar_RightHand(const id, const szCvar[], const szValue[])
{
	g_bLeftHand[id] = (str_to_num(szValue) == 0)
}

public fw_Weapon_DefaultReload_Pre(const iWpnEnt, iClip, iAnim, Float:flDelay)
{
	if (!is_Weap_BuffM4(iWpnEnt))
		return

	SetHookChainArg(2, ATYPE_INTEGER, WEAPON_MAXCLIP)
	SetHookChainArg(3, ATYPE_INTEGER, ANIM_RELOAD)
	SetHookChainArg(4, ATYPE_FLOAT, ANIMT_RELOAD)
}

public fw_WeaponBox_SetModel_Pre(const iEnt, const szModel[])
{
	if (is_nullent(iEnt))
		return

	if (is_Weap_BuffM4(get_member(iEnt, m_WeaponBox_rgpPlayerItems, PRIMARY_WEAPON_SLOT)))
		SetHookChainArg(2, ATYPE_STRING, g_w_szWeaponModel)
}

public fw_Weapon_WeaponIdle_Pre(const iWpnEnt)
{
	if (!is_Weap_BuffM4(iWpnEnt))
		return HAM_IGNORED

	if (get_member(iWpnEnt, m_Weapon_flTimeWeaponIdle) > 0.0)
		return HAM_SUPERCEDE

	rg_weapon_send_animation(iWpnEnt, ANIM_IDLE)
	set_member(iWpnEnt, m_Weapon_flTimeWeaponIdle, ANIMT_IDLE)
	return HAM_SUPERCEDE
}

public fw_Weapon_PrimaryAttack_Pre(const iWpnEnt)
{
	if (!is_Weap_BuffM4(iWpnEnt))
		return HAM_IGNORED

	if (get_member(iWpnEnt, m_Weapon_iClip) <= 0)
	{
		ExecuteHam(Ham_Weapon_PlayEmptySound, iWpnEnt)
		set_member(iWpnEnt, m_Weapon_flNextPrimaryAttack, 0.2)
		return HAM_SUPERCEDE
	}

	g_iShotsFired = 0

	static iPlayer; iPlayer = get_member(iWpnEnt, m_pPlayer)
	static iState; iState = get_member(iWpnEnt, m_Weapon_iWeaponState)

	switch (iState)
	{
		case WPN_STATE_NORMAL:
		{
			g_hTraceLine = register_forward(FM_TraceLine, "fw_TraceLine_Post", 1)
		}
		case WPN_STATE_SPECIAL:
		{
			g_hTraceLine = register_forward(FM_TraceLine, "fw_TraceLineSp_Post", 1)
		}
	}

	state FireBullets: Enabled
	ExecuteHam(Ham_Weapon_PrimaryAttack, iWpnEnt)
	unregister_forward(FM_TraceLine, g_hTraceLine, 1)
	state FireBullets: Disabled

#if MFLASH_STATUS == 1
	create_MuzzleFlash(iPlayer, 1)
#endif

	rg_weapon_send_animation(iPlayer, random_num(ANIM_SHOOT1, ANIM_SHOOT3))

	// Recoil.
	static Float:vRecoil[3]
	get_entvar(iPlayer, var_punchangle, vRecoil)
	xs_vec_mul_scalar(vRecoil, WEAPON_RECOIL, vRecoil)
	set_entvar(iPlayer, var_punchangle, vRecoil)

	switch (iState)
	{
		case WPN_STATE_NORMAL:
		{
			emit_sound(iPlayer, CHAN_WEAPON, g_szFireSound[Sound_FireNormal], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
			rp_weapon_set_nextattack(iWpnEnt, WEAPON_FIRERATE, WEAPON_FIRERATE, ANIMT_SHOOT)
		}
		case WPN_STATE_SPECIAL:
		{
			emit_sound(iPlayer, CHAN_WEAPON, g_szFireSound[Sound_FireSpecial], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
			rp_weapon_set_nextattack(iWpnEnt, WEAPON_SP_FIRERATE, WEAPON_SP_FIRERATE, ANIMT_SHOOT)
		}
	}

	return HAM_SUPERCEDE
}

#if MFLASH_STATUS == 1
public create_MuzzleFlash(const iAttacker, iAttachment)
{
	if (global_get(glb_maxEntities) - engfunc(EngFunc_NumberOfEntities) <= MFLASH_ED_CRITIC)
		return

	static iEnt
	if ((iEnt = rg_create_entity(MFLASH_REFERENCE)) == 0)
		return

	set_entvar(iEnt, var_classname, MFLASH_CLASSNAME)
	set_entvar(iEnt, var_movetype, MOVETYPE_FOLLOW)
	set_entvar(iEnt, var_aiment, iAttacker)
	set_entvar(iEnt, var_owner, iAttacker)
	set_entvar(iEnt, var_skin, iAttacker)
	set_entvar(iEnt, var_body, iAttachment)
	set_entvar(iEnt, var_scale, MFLASH_SPRSCALE)
	set_entvar(iEnt, var_rendermode, kRenderTransAdd)
	set_entvar(iEnt, var_renderamt, 255.0)

	engfunc(EngFunc_SetModel, iEnt, g_szMuzzleFlashSprite)

	SetThink(iEnt, "fw_MuzzFlash_Think")
	set_entvar(iEnt, var_nextthink, get_gametime() + 0.05)
}

public fw_Weapon_SecondaryAttack_Pre(const iWpnEnt)
{
	if (!is_Weap_BuffM4(iWpnEnt))
		return HAM_IGNORED

	static iPlayer; iPlayer = get_member(iWpnEnt, m_pPlayer)

	switch (get_member(iWpnEnt, m_Weapon_iWeaponState))
	{
		case WPN_STATE_NORMAL:
		{
			rp_set_user_fov(iPlayer, WEAPON_SP_FOV)
			set_member(iWpnEnt, m_Weapon_iWeaponState, WPN_STATE_SPECIAL)
			set_member(iWpnEnt, m_Weapon_flBaseDamage, WEAPON_DAMAGE)
		}
		case WPN_STATE_SPECIAL:
		{
			rp_set_user_fov(iPlayer)
			set_member(iWpnEnt, m_Weapon_iWeaponState, WPN_STATE_NORMAL)
			set_member(iWpnEnt, m_Weapon_flBaseDamage, WEAPON_SP_DAMAGE)
		}
	}

	set_member(iWpnEnt, m_Weapon_flNextPrimaryAttack, WEAPON_SP_TIME)
	set_member(iWpnEnt, m_Weapon_flNextSecondaryAttack, WEAPON_SP_TIME)
	return HAM_SUPERCEDE
}

public fw_MuzzFlash_Think(const iEnt)
{
	if (is_nullent(iEnt))
		return

	static Float:fFrame; fFrame = get_entvar(iEnt, var_frame)

	if (fFrame >= g_maxSprFrames)
	{
		SetThink(iEnt, "")
		rg_remove_entity(iEnt)
		return
	}

	fFrame++
	set_entvar(iEnt, var_frame, fFrame)
	set_entvar(iEnt, var_nextthink, get_gametime() + 0.05)
}
#endif

public fw_TraceLine_Post(const Float:vSrc[3], const Float:vEnd[3], iFlags, iAttacker, hTrace)
{
	if (iFlags & IGNORE_MONSTERS || g_iShotsFired >= 1)
		return FMRES_IGNORED

	static pHit; pHit = get_tr2(hTrace, TR_pHit)

	if (pHit > 0) if (get_entvar(pHit, var_solid) != SOLID_BSP) return FMRES_IGNORED

	static Float:vTarget[3]
	get_tr2(hTrace, TR_vecEndPos, vTarget)

	// Decal.
	message_begin_f(MSG_PVS, SVC_TEMPENTITY, vTarget)
	write_byte(TE_GUNSHOTDECAL) // TE id.
	write_coord_f(vTarget[0]) // Position X.
	write_coord_f(vTarget[1]) // Position Y.
	write_coord_f(vTarget[2]) // Position Z.
	write_short(pHit > 0 ? pHit : 0) // Entity ID.
	write_byte(random_num(41, 45)) // Decal Index.
	message_end()

	g_iShotsFired++
	return FMRES_IGNORED
}

public fw_TraceLineSp_Post(const Float:vSrc[3], const Float:vEnd[3], iFlags, iAttacker, hTrace)
{
	if (iFlags & IGNORE_MONSTERS || g_iShotsFired >= 1)
		return FMRES_IGNORED

	static pHit; pHit = get_tr2(hTrace, TR_pHit)

	static Float:vOrigin[3]
	ExecuteHam(Ham_Player_GetGunPosition, iAttacker, vOrigin)

	static Float:vTarget[3]
	get_tr2(hTrace, TR_vecEndPos, vTarget)

	static Float:vAngles[3]
	get_entvar(iAttacker, var_v_angle, vAngles)

	static Float:vForward[3], Float:vRight[3], Float:vUp[3]
	engfunc(EngFunc_AngleVectors, vAngles, vForward, vRight, vUp)

	xs_vec_add_scaled(vOrigin, vUp, -6.0, vOrigin)
	xs_vec_add_scaled(vOrigin, vRight, g_bLeftHand[iAttacker] ? -8.0 : 8.0, vOrigin)
	xs_vec_add_scaled(vOrigin, vForward, 45.0, vOrigin)

	// Beam.
	message_begin_f(MSG_PVS, SVC_TEMPENTITY, vOrigin)
	write_byte(TE_BEAMPOINTS) // TE id.
	write_coord_f(vOrigin[0]) // Start Position X.
	write_coord_f(vOrigin[1]) // Start Position Y.
	write_coord_f(vOrigin[2]) // Start Position Z.
	write_coord_f(vTarget[0]) // End Position X.
	write_coord_f(vTarget[1]) // End Position Y.
	write_coord_f(vTarget[2]) // End Position Z.
	write_short(g_iBeamSpr) // Sprite Index.
	write_byte(0) // Frame.
	write_byte(0) // Frame rate.
	write_byte(10) // Duration.
	write_byte(5) // Width.
	write_byte(0) // Noise Amplitude.
	write_byte(125) // Red.
	write_byte(125) // Green.
	write_byte(125) // Blue.
	write_byte(100) // Brightnes..
	write_byte(-20) // Scroll Speed.
	message_end()

	if (pHit > 0) if (get_entvar(pHit, var_solid) != SOLID_BSP) return FMRES_IGNORED

	// Decal.
	message_begin_f(MSG_PVS, SVC_TEMPENTITY, vTarget)
	write_byte(TE_GUNSHOTDECAL) // TE id.
	write_coord_f(vTarget[0]) // Position X.
	write_coord_f(vTarget[1]) // Position Y.
	write_coord_f(vTarget[2]) // Position Z.
	write_short(pHit > 0 ? pHit : 0) // Entity ID.
	write_byte(random_num(41, 45)) // Decal Index.
	message_end()

	g_iShotsFired++
	return FMRES_IGNORED
}


ResetSpecialAbility(const iWpnEnt, iPlayer = 0)
{
	if (get_member(iWpnEnt, m_Weapon_iWeaponState) == WPN_STATE_SPECIAL)
	{
		rp_set_user_fov(!iPlayer ? get_member(iWpnEnt, m_pPlayer) : iPlayer, WEAPON_SP_FOV)

		set_member(iWpnEnt, m_Weapon_iWeaponState, WPN_STATE_NORMAL)
		set_member(iWpnEnt, m_Weapon_flBaseDamage, WEAPON_DAMAGE)
	}
}

/**
 * --==| Function |==--
 */
rp_set_user_fov(const player, iDegree = DEFAULT_NO_ZOOM)
{
	set_member(player, m_iFOV, iDegree)

	message_begin(MSG_ONE, g_iSetFOV, _, player)
	write_byte(iDegree) // Degree.
	message_end()
}

rp_weapon_set_nextattack(const entity, Float:primaryAttack, Float:secondaryAttack, Float:timeWeaponIdle)
{
	set_member(entity, m_Weapon_flNextPrimaryAttack, primaryAttack)
	set_member(entity, m_Weapon_flNextSecondaryAttack, secondaryAttack)
	set_member(entity, m_Weapon_flTimeWeaponIdle, timeWeaponIdle)
}

send_WeaponList_msg(const iPlayer, iMode = 1)
{
	message_begin(MSG_ONE, g_iWeaponList, _, iPlayer)
	write_string(iMode ? WEAPON_CLASSNAME : WEAPON_REFERENCE) // Weapon Name.
	write_byte(4) // Primary Ammo ID.
	write_byte(WEAPON_MAXAMMO) // Primary Ammo Max Amount.
	write_byte(NULLENT) // Secondary Ammo ID.
	write_byte(NULLENT) // Secondary Ammo Max Amount.
	write_byte(0) // SlotID.
	write_byte(6) // Number in slot.
	write_byte(WEAPON_ID) // Weapon ID.
	write_byte(0) // Flags
	message_end()
}