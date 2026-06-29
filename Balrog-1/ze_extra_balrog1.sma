#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <engine>
#include <reapi>
#include <xs>
#include <ze_core>

// Defines
#define EXTRA_ITEM 1   // Disable weapon in Extra Item (1 = Enabled | 0 = Disabled).

// Macroses.
#define is_valid_client(%0) (1<=(%0)<=MaxClients)
#define IsWeaponBalrogI(%0) (is_entity(%0) && get_entvar(%0,var_impulse)==WEAPON_UID)

// Animations Time.
#define ANIM_TIME_IDLE     1.70
#define ANIM_TIME_SHOOT_A  1.03
#define ANIM_TIME_SHOOT_B  3.03
#define ANIM_TIME_RELOAD_A 2.57
#define ANIM_TIME_RELOAD_B 3.00
#define ANIM_TIME_DRAW     1.03
#define ANIM_TIME_CHANGE_A 2.03
#define ANIM_TIME_CHANGE_B 1.30

// Animations ID.
enum (+=1)
{
	ANIM_IDLE_A = 0,
	ANIM_IDLE_B,
	ANIM_SHOOT_A,
	ANIM_SHOOT_B,
	ANIM_RELOAD_A,
	ANIM_DRAW,
	ANIM_CHANGE_A,
	ANIM_CHANGE_B,
	ANIM_RELOAD_B
}

enum
{
	WEAPON_STATE_NORMAL = 0,
	WEAPON_STATE_SPECIAL
}

// Weapon Info:
new const WEAPON_NEW_NAME[] = "weapon_balrog1_lz"
new const WEAPON_REFERENCE[] = "weapon_deagle"
const WEAPON_ID = CSW_DEAGLE
const WEAPON_UID = 112762925
const WEAPON_MAXCLIP = 10
const WEAPON_DEFAMMO = 50
const Float: WEAPON_DAMAGE = 34.0
const Float: WEAPON_EXP_DAMAGE = 195.0
const Float: WEAPON_EXP_RADIUS = 200.0
const Float: WEAPON_EXP_RANGE = 4096.0
const Float: WEAPON_FIRERATE = 0.15

// Zombie Escape: Item Info
#if EXTRA_ITEM == 1
stock const ZE_ITEM_NAME[] = "Balrog-I"
stock const ZE_ITEM_COST = 15
stock const ZE_ITEM_LIMIT = 0
#endif

// Weapon Models.
new g_v_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/CSO/v_balrog1.mdl"
new g_p_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/CSO/p_balrog1.mdl"
new g_w_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/CSO/w_balrog1.mdl"

// Shoot A Sound.
new const g_szShootASound[] = "weapons/CSO/balrog1-1.wav"
new const g_szShootBSound[] = "weapons/CSO/balrog1-2.wav"

// Variables.
new g_iExploSpr,
	g_iWeaponList

#if EXTRA_ITEM == 1
new g_iItemID
#endif

public plugin_precache()
{
#if EXTRA_ITEM == 1
	// Read weapon models from INI file.
	if (!ini_read_string(ZE_FILENAME, ZE_ITEM_NAME, "VIEW_MODEL", g_v_szWeaponModel, charsmax(g_v_szWeaponModel)))
		ini_write_string(ZE_FILENAME, ZE_ITEM_NAME, "VIEW_MODEL", g_v_szWeaponModel)
	if (!ini_read_string(ZE_FILENAME, ZE_ITEM_NAME, "WEAPON_MODEL", g_p_szWeaponModel, charsmax(g_p_szWeaponModel)))
		ini_write_string(ZE_FILENAME, ZE_ITEM_NAME, "WEAPON_MODEL", g_p_szWeaponModel)
	if (!ini_read_string(ZE_FILENAME, ZE_ITEM_NAME, "WORLD_MODEL", g_w_szWeaponModel, charsmax(g_w_szWeaponModel)))
		ini_write_string(ZE_FILENAME, ZE_ITEM_NAME, "WORLD_MODEL", g_w_szWeaponModel)
#endif

	new const szExploSprite[] = "sprites/CSO/ef_balrog_explo.spr"

	new const szModelSounds[][] =
	{
		"sound/weapons/CSO/balrog1_changea.wav",
		"sound/weapons/CSO/balrog1_changeb.wav",
		"sound/weapons/CSO/balrog1_draw.wav",
		"sound/weapons/CSO/balrog1_reload.wav",
		"sound/weapons/CSO/balrog1_reloadb.wav"
	}

	new const szWeaponListFiles[][] =
	{
		"sprites/weapon_balrog1_lz.txt",
		"sprites/640hudz1.spr"
	}

	// Pre-load Models.
	precache_model(g_v_szWeaponModel)
	precache_model(g_p_szWeaponModel)
	precache_model(g_w_szWeaponModel)
	g_iExploSpr = precache_model(szExploSprite)

	// Pre-load Sounds.
	precache_sound(g_szShootASound)
	precache_sound(g_szShootBSound)

	// Pre-load more Files.
	new i
	for (i = 0; i < sizeof(szModelSounds); i++)
		precache_generic(szModelSounds[i])
	for (i = 0; i < sizeof(szWeaponListFiles); i++)
		precache_generic(szWeaponListFiles[i])
}

public plugin_init()
{
	// Load Plugin.
	register_plugin("[ZE] Extra Item: Balrog-I", "1.1", "z0h1r-LK")

	// Hook Chain.
	RegisterHookChain(RG_CWeaponBox_SetModel, "fw_WeaponBox_SetModel_Pre")
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "fw_Weapon_DefaultDeploy_Pre")
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultReload, "fw_Weapon_DefaultReload_Pre")

	// Hams.
	RegisterHam(Ham_Weapon_WeaponIdle, WEAPON_REFERENCE, "fw_Weapon_WeaponIdle_Pre")
	RegisterHam(Ham_Weapon_PrimaryAttack, WEAPON_REFERENCE, "fw_Weapon_PrimaryAttack_Pre")
	RegisterHam(Ham_Weapon_SecondaryAttack, WEAPON_REFERENCE, "fw_Weapon_SecondaryAttack_Pre")
	RegisterHam(Ham_Item_Holster, WEAPON_REFERENCE, "fw_Weapon_Hostler_Pre")
	RegisterHam(Ham_Item_AddToPlayer, WEAPON_REFERENCE, "fw_Weapon_AddToPlayer_Post", 1)
	RegisterHam(Ham_RemovePlayerItem, WEAPON_REFERENCE, "fw_Weapon_RemovePlayerItem_Post", 1)

	// FakeMeta.
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent")
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)

	// Command.
	register_clcmd(WEAPON_NEW_NAME, "cmd_SelectWeapon")

#if EXTRA_ITEM == 1
	// New Item.
	g_iItemID = ze_item_register(ZE_ITEM_NAME, ZE_ITEM_COST, ZE_ITEM_LIMIT)
#endif

	// Initial Value.
	g_iWeaponList = get_user_msgid("WeaponList")
}

public cmd_SelectWeapon(const clId)
{
	engclient_cmd(clId, WEAPON_REFERENCE)
	return PLUGIN_HANDLED;
}

#if EXTRA_ITEM == 1
public ze_select_item_pre(clId, iItem, bool:bIgnoreCost, bool:bInMenu)
{
	if (iItem != g_iItemID)
		return ZE_ITEM_AVAILABLE;

	if (ze_is_user_zombie(clId))
		return ZE_ITEM_DONT_SHOW;

	// Item allowed for Humans.
	return ZE_ITEM_AVAILABLE;
}

public ze_select_item_post(clId, iItem, bool:bIgnoreCost)
{
	if (iItem != g_iItemID)
		return

	give_BalrogPistol(clId)
}
#endif

public give_BalrogPistol(const clId)
{
	new iWpnEnt
	if ((iWpnEnt = rg_give_custom_item(clId, WEAPON_REFERENCE, GT_DROP_AND_REPLACE, WEAPON_UID)) == NULLENT)
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Weapon ID (-1)")
		return;
	}

	set_member(iWpnEnt, m_Weapon_iClip, WEAPON_MAXCLIP)
	rg_set_iteminfo(iWpnEnt, ItemInfo_iMaxAmmo1, WEAPON_DEFAMMO)
	rg_set_user_bpammo(clId, WeaponIdType:WEAPON_ID, WEAPON_DEFAMMO)
	msg_send_weaponlist(clId, 1)
}

public fw_PlaybackEvent() <FireBullets: Enabled>
	return FMRES_SUPERCEDE;
public fw_PlaybackEvent() <FireBullets: Disabled>
	return FMRES_IGNORED;
public fw_PlaybackEvent() < >
	return FMRES_IGNORED;

public fw_UpdateClientData_Post(const clId, SendWeapons, iHandle)
{
	if (!is_user_alive(clId))
		return FMRES_IGNORED;

	if (IsWeaponBalrogI(get_member(clId, m_pActiveItem)))
	{
		set_cd(iHandle, CD_flNextAttack, get_gametime() + 0.001)
		return FMRES_HANDLED;
	}

	return FMRES_IGNORED;
}

public fw_Weapon_WeaponIdle_Pre(const iWpnEnt)
{
	if (!IsWeaponBalrogI(iWpnEnt))
		return HAM_IGNORED;

	if (get_member(iWpnEnt, m_Weapon_flTimeWeaponIdle) > 0.0)
		return HAM_SUPERCEDE;

	if (get_member(iWpnEnt, m_Weapon_iWeaponState) == WEAPON_STATE_SPECIAL)
		rg_weapon_send_animation(iWpnEnt, ANIM_IDLE_B)
	else
		rg_weapon_send_animation(iWpnEnt, ANIM_IDLE_A)

	set_member(iWpnEnt, m_Weapon_flTimeWeaponIdle, ANIM_TIME_IDLE)
	return HAM_SUPERCEDE;
}

public fw_Weapon_PrimaryAttack_Pre(const iWpnEnt)
{
	if (!IsWeaponBalrogI(iWpnEnt))
		return HAM_IGNORED;

	static iClipSize; iClipSize = get_member(iWpnEnt, m_Weapon_iClip)
	if (iClipSize <= 0)
	{
		ExecuteHamB(Ham_Weapon_PlayEmptySound, iWpnEnt)
		set_member(iWpnEnt, m_Weapon_flNextPrimaryAttack, 0.2)
		return HAM_SUPERCEDE;
	}

	if (get_member(iWpnEnt, m_Weapon_iShotsFired) >= 1)
		return HAM_SUPERCEDE;

	static clientIndex; clientIndex = get_member(iWpnEnt, m_pPlayer)

	state FireBullets: Enabled
	static hFwHandle; hFwHandle = register_forward(FM_TraceLine, "fw_TraceLine_Post", 1)
	ExecuteHam(Ham_Weapon_PrimaryAttack, iWpnEnt)
	unregister_forward(FM_TraceLine, hFwHandle, 1)
	state FireBullets: Disabled

	if (get_member(iWpnEnt, m_Weapon_iWeaponState) == WEAPON_STATE_SPECIAL)
	{
		static Float:vStart[3]
		ExecuteHamB(Ham_Player_GetGunPosition, clientIndex, vStart)

		static Float:vTarget[3]
		get_entvar(clientIndex, var_v_angle, vTarget)
		angle_vector(vTarget, ANGLEVECTOR_FORWARD, vTarget)
		xs_vec_mul_scalar(vTarget, WEAPON_EXP_RANGE, vTarget)
		xs_vec_add(vStart, vTarget, vTarget)

		// Make TraceLine.
		engfunc(EngFunc_TraceLine, vStart, vTarget, DONT_IGNORE_MONSTERS, clientIndex, 0)
		get_tr2(0, TR_vecEndPos, vTarget)

		// Explosion FX.
		message_begin_f(MSG_PVS, SVC_TEMPENTITY, vTarget)
		write_byte(TE_EXPLOSION) // TE id.
		write_coord_f(vTarget[0]) // Position X.
		write_coord_f(vTarget[1]) // Position Y.
		write_coord_f(vTarget[2] + 32.0) // Position Z.
		write_short(g_iExploSpr) // Sprite Index
		write_byte(20) // Scale.
		write_byte(18) // Frame rate.
		write_byte(TE_EXPLFLAG_NONE) // Flags.
		message_end()

		rg_weapon_send_animation(clientIndex, ANIM_SHOOT_B)
		set_member(iWpnEnt, m_Weapon_iWeaponState, WEAPON_STATE_NORMAL)

		emit_sound(clientIndex, CHAN_WEAPON, g_szShootBSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		rg_weapon_set_nextattack(iWpnEnt, ANIM_TIME_SHOOT_B, ANIM_TIME_SHOOT_B, ANIM_TIME_SHOOT_B)

		// Do Explosion.
		MakeExplosion(vTarget, clientIndex)
	}
	else
	{
		emit_sound(clientIndex, CHAN_WEAPON, g_szShootASound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		rg_weapon_set_nextattack(iWpnEnt, WEAPON_FIRERATE, ANIM_TIME_SHOOT_A, ANIM_TIME_SHOOT_A)
		rg_weapon_send_animation(clientIndex, ANIM_SHOOT_A)
	}

	return HAM_SUPERCEDE;
}

public fw_Weapon_SecondaryAttack_Pre(const iWpnEnt)
{
	if (!IsWeaponBalrogI(iWpnEnt))
		return;

	if (get_member(iWpnEnt, m_Weapon_iWeaponState) == WEAPON_STATE_NORMAL)
	{
		rg_weapon_send_animation(iWpnEnt, ANIM_CHANGE_A)
		set_member(iWpnEnt, m_Weapon_iWeaponState, WEAPON_STATE_SPECIAL)
		rg_weapon_set_nextattack(iWpnEnt, ANIM_TIME_CHANGE_A, ANIM_TIME_CHANGE_A, ANIM_TIME_CHANGE_A)
	}
	else
	{
		rg_weapon_send_animation(iWpnEnt, ANIM_CHANGE_B)
		set_member(iWpnEnt, m_Weapon_iWeaponState, WEAPON_STATE_NORMAL)
		rg_weapon_set_nextattack(iWpnEnt, ANIM_TIME_CHANGE_B, ANIM_TIME_CHANGE_B, ANIM_TIME_CHANGE_B)
	}
}

public fw_Weapon_Hostler_Pre(const iWpnEnt)
{
	if (!IsWeaponBalrogI(iWpnEnt))
		return;

	set_member(iWpnEnt, m_Weapon_iWeaponState, WEAPON_STATE_NORMAL)
}

public fw_Weapon_DefaultDeploy_Pre(const iWpnEnt, const szViewModel[], const szWeaponModel[], iAnim, const szAnimExt[], skiplocal)
{
	if (!IsWeaponBalrogI(iWpnEnt))
		return;

	SetHookChainArg(2, ATYPE_STRING, g_v_szWeaponModel)
	SetHookChainArg(3, ATYPE_STRING, g_p_szWeaponModel)
	SetHookChainArg(4, ATYPE_INTEGER, ANIM_DRAW)
}

public fw_Weapon_DefaultReload_Pre(const iWpnEnt, iClipSize, iAnim, Float:fDelay)
{
	if (!IsWeaponBalrogI(iWpnEnt))
		return

	SetHookChainArg(2, ATYPE_INTEGER, WEAPON_MAXCLIP)
	if (get_member(iWpnEnt, m_Weapon_iWeaponState) == WEAPON_STATE_SPECIAL)
	{
		SetHookChainArg(3, ATYPE_INTEGER, ANIM_RELOAD_B)
		SetHookChainArg(4, ATYPE_FLOAT, ANIM_TIME_RELOAD_B)
	}
	else
	{
		SetHookChainArg(3, ATYPE_INTEGER, ANIM_RELOAD_A)
		SetHookChainArg(4, ATYPE_FLOAT, ANIM_TIME_RELOAD_A)
	}
}

public fw_WeaponBox_SetModel_Pre(const pEnt, const szModel[])
{
	if (is_nullent(pEnt))
		return;

	if (IsWeaponBalrogI(get_member(pEnt, m_WeaponBox_rgpPlayerItems, PISTOL_SLOT)))
		SetHookChainArg(2, ATYPE_STRING, g_w_szWeaponModel)
}

public fw_Weapon_AddToPlayer_Post(const iWpnEnt, const clientIndex)
{
	if (!IsWeaponBalrogI(iWpnEnt))
		return

	set_member(iWpnEnt, m_Weapon_flBaseDamage, WEAPON_DAMAGE)
	set_member(iWpnEnt, m_Weapon_iDefaultAmmo, WEAPON_DEFAMMO)
	set_member(iWpnEnt, m_Weapon_iWeaponState, WEAPON_STATE_NORMAL)
	set_member(iWpnEnt, m_Weapon_bHasSecondaryAttack, true)

	rg_set_iteminfo(iWpnEnt, ItemInfo_iMaxClip, WEAPON_MAXCLIP)
	msg_send_weaponlist(clientIndex, 1)
}

public fw_Weapon_RemovePlayerItem_Post(const iWpnEnt, const clientIndex)
{
	if (!IsWeaponBalrogI(iWpnEnt))
		return

	msg_send_weaponlist(clientIndex)
}

public fw_TraceLine_Post(const Float:vStart[3], const Float:vEnd[3], iFlags, iAttacker, hTrace)
{
	if (iFlags & IGNORE_MONSTERS)
		return;

	static iHitEnt; iHitEnt = get_tr2(hTrace, TR_pHit)
	if (iHitEnt > 0) if (get_entvar(iHitEnt, var_solid) != SOLID_BBOX) return;

	static Float:vTarget[3]
	get_tr2(hTrace, TR_vecEndPos, vTarget)

	message_begin_f(MSG_PVS, SVC_TEMPENTITY, vTarget)
	write_byte(TE_GUNSHOTDECAL) // TE id.
	write_coord_f(vTarget[0]) // Position X.
	write_coord_f(vTarget[1]) // Position Y.
	write_coord_f(vTarget[2]) // Position Z.
	write_short(iHitEnt > 0 ? iHitEnt : 0) // Entity Index.
	write_byte(random_num(41, 45)) // Decal Index.
	message_end()
}

public MakeExplosion(const Float:vStart[3], const iAttacker)
{
	new Float:vTarget[3], Float:flDamage, iVictim = NULLENT
	while ((iVictim = find_ent_in_sphere(iVictim, vStart, WEAPON_EXP_RADIUS)))
	{
		if (iVictim == iAttacker)
			continue;

		if (is_valid_client(iVictim) && is_user_alive(iVictim) && ze_is_user_zombie(iVictim))
		{
			get_entvar(iVictim, var_origin, vTarget)
			flDamage = WEAPON_EXP_DAMAGE * (1.0 - (vector_distance(vStart, vTarget) / WEAPON_EXP_RADIUS))

			if (flDamage < 1.0)
				continue;

			ExecuteHamB(Ham_TakeDamage, iVictim, iAttacker, iAttacker, flDamage, DMG_BURN)
		}
		else if (get_entvar(iVictim, var_takedamage) != DAMAGE_NO && get_entvar(iVictim, var_health) > 0.0)
		{
			ExecuteHamB(Ham_TakeDamage, iVictim, iAttacker, iAttacker, WEAPON_EXP_DAMAGE, DMG_GENERIC)
		}
	}
}

/**
 * ----[Function]----
 */
msg_send_weaponlist(const id, const iMode = 0)
{
	message_begin(MSG_ONE, g_iWeaponList, .player = id)
	write_string(iMode ? WEAPON_NEW_NAME : WEAPON_REFERENCE) // Weapon Name.
	write_byte(8) // Primary Ammo ID.
	write_byte(WEAPON_DEFAMMO) // Primary Ammo Max Amount
	write_byte(NULLENT) // Secondary Ammo ID
	write_byte(NULLENT) // Secondary Ammo Max Amount
	write_byte(1) // Slot ID
	write_byte(1) // Number in Slot
	write_byte(_:WEAPON_ID) // Weapon ID
	write_byte(0) // Flags
	message_end()
}

rg_weapon_set_nextattack(const iWpnEnt, Float:flPrimaryAttack, Float:flSecondaryAttack, Float:flTimeWeaponIdle)
{
	set_member(iWpnEnt, m_Weapon_flTimeWeaponIdle, flTimeWeaponIdle)
	set_member(iWpnEnt, m_Weapon_flNextPrimaryAttack, flPrimaryAttack)
	set_member(iWpnEnt, m_Weapon_flNextSecondaryAttack, flSecondaryAttack)
}