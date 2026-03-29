#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <reapi>
#include <xs>
#include <ze_core>

// Macroses
#define FIsCustomWeapon(%0) (is_entity(%0) && get_entvar(%0,var_impulse)==WEAPON_UID)

// Weapon: Item Info
#define WEAPON_CLASSNAME "weapon_sfgun_lz"
#define WEAPON_REFERENCE "weapon_sg552"
#define WEAPON_ANIMEXT   "rifle"
#define WEAPON_UID       71731726
#define WEAPON_ID        CSW_SG552
#define WEAPON_MAXCLIP   45
#define WEAPON_MAXAMMO   90
#define WEAPON_DAMAGE    47.0
#define WEAPON_FIRERATE  0.09
#define WEAPON_RECOIL    0.86

#define MFLASH_CLASSNAME "muzzleflash"
#define MFLASH_REFERENCE "info_target"

// Zombie Escape: Functions
#define ZE_EXTRA_ITEM    1    /* 1 = Enable Extra Item | 0 = Disable Extra Item */
#define ZE_MUZZLEFLASH   1    /* 1 = Enable Extra Item | 0 = Disable Extra Item */

// Zombie Escape: Extra Item
#define ZE_ITEM_NAME     "Blaster"
#define ZE_ITEM_COST     30
#define ZE_ITEM_LIMIT    0
#define ZE_ITEM_LEVEL    0
#define ZE_ITEM_GLIMIT   0

enum (+=1)
{
	ANIM_IDLE = 0,
	ANIM_RELOAD,
	ANIM_DRAW,
	ANIM_SHOOT1,
	ANIM_SHOOT2,
	ANIM_SHOOT3
}

// Sequence duration:
const Float:ANIMTIME_IDLE   = 2.03
const Float:ANIMTIME_DRAW   = 1.13
const Float:ANIMTIME_RELOAD = 3.03
const Float:ANIMTIME_SHOOT  = 1.23

// Weapon Resources.
new g_v_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/CSO/v_sfgun.mdl"
new g_p_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/CSO/p_sfgun.mdl"
new g_w_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/CSO/w_sfgun.mdl"

#if ZE_MUZZLEFLASH == 1
	new const g_szMuzzSprite[] = "sprites/nhth1.spr"
#endif

new const g_szShootSound[] = "weapons/CSO/sfgun_shoot1.wav"

// Variables.
new g_iItemId,
	g_iMuzzMdl,
	g_iWeaponList,
	g_iShotsFired,
	g_hTraceLine

public plugin_precache()
{
	if (!ini_read_string(ZE_FILENAME, "Weapon Models", "V_SFGUN", g_v_szWeaponModel, charsmax(g_v_szWeaponModel)))
		ini_write_string(ZE_FILENAME, "Weapon Models", "V_SFGUN", g_v_szWeaponModel)
	if (!ini_read_string(ZE_FILENAME, "Weapon Models", "P_SFGUN", g_p_szWeaponModel, charsmax(g_p_szWeaponModel)))
		ini_write_string(ZE_FILENAME, "Weapon Models", "P_SFGUN", g_p_szWeaponModel)
	if (!ini_read_string(ZE_FILENAME, "Weapon Models", "W_SFGUN", g_w_szWeaponModel, charsmax(g_w_szWeaponModel)))
		ini_write_string(ZE_FILENAME, "Weapon Models", "W_SFGUN", g_w_szWeaponModel)

	precache_model_s(g_v_szWeaponModel)
	precache_model_s(g_p_szWeaponModel)
	precache_model_s(g_w_szWeaponModel)

#if ZE_MUZZLEFLASH == 1
	g_iMuzzMdl = precache_model_s(g_szMuzzSprite)
#endif

	precache_sound(g_szShootSound)

	new const szMoreResrc[][] =
	{
		"sound/weapons/CSO/sfgun_clipin.wav",
		"sound/weapons/CSO/sfgun_clipout.wav",
		"sound/weapons/CSO/sfgun_draw.wav",

		"sprites/weapon_sfgun_lz.txt",
		"sprites/640hudz5.spr"
	}

	for (new i = 0; i < sizeof(szMoreResrc); i++)
		precache_generic(szMoreResrc[i])
}

public plugin_init()
{
	// Load Plug-In.
	register_plugin("[ZE] Extra Item: SFGun (Blaser)", "1.0", "z0h1r-LK")

	// Hook Chains.
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "fw_Weapon_DefaultDeploy_Pre")
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultReload, "fw_Weapon_DefaultReload_Pre")
	RegisterHookChain(RG_CWeaponBox_SetModel, "fw_WeaponBox_SetModel")

	// Hams.
	RegisterHam(Ham_Spawn, WEAPON_REFERENCE, "fw_Weapon_Spawn_Post", 1)

	RegisterHam(Ham_Weapon_WeaponIdle, WEAPON_REFERENCE, "fw_Weapon_WeaponIdle")
	RegisterHam(Ham_Weapon_PrimaryAttack, WEAPON_REFERENCE, "fw_Weapon_PrimaryAttack")
	RegisterHam(Ham_Weapon_SecondaryAttack, WEAPON_REFERENCE, "fw_Weapon_SecondaryAttack")

	RegisterHam(Ham_Item_AddToPlayer, WEAPON_REFERENCE, "fw_Weapon_AddItem_Post", 1)
	RegisterHam(Ham_RemovePlayerItem, WEAPON_REFERENCE, "fw_Weapon_RemoveItem_Post", 1)

	// FakeMeta.
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent")
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)

	// Command.
	register_clcmd(WEAPON_CLASSNAME, "cmd_ChooseWeapon")

#if ZE_EXTRA_ITEM == 1
	// Extra Item's.
	g_iItemId = ze_item_register_ex(ZE_ITEM_NAME, ZE_ITEM_COST, ZE_ITEM_LIMIT, ZE_ITEM_LEVEL, ZE_ITEM_GLIMIT)
#endif

	// Set Values.
	g_iWeaponList = get_user_msgid("WeaponList")
}

public cmd_ChooseWeapon(const id)
{
	engclient_cmd(id, WEAPON_REFERENCE)
	return PLUGIN_HANDLED
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

	if (rg_give_custom_item(id, WEAPON_REFERENCE, GT_DROP_AND_REPLACE, WEAPON_UID) == NULLENT)
		log_error(AMX_ERR_NATIVE, "[ZE] Error while giving the weapon to the player (id: %d)", id)
}
#endif

public fw_PlaybackEvent() < /* no statement */ >
	return FMRES_IGNORED

public fw_PlaybackEvent() <StopPaybackEvent: Disabled>
	return FMRES_IGNORED

public fw_PlaybackEvent() <StopPaybackEvent: Enabled>
	return FMRES_SUPERCEDE

public fw_UpdateClientData_Post(const id, sendweapons, cd_handle)
{
	if (get_cd(cd_handle, CD_DeadFlag) != DEAD_NO)
		return FMRES_IGNORED

	if (FIsCustomWeapon(get_member(id, m_pActiveItem)))
	{
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001)
		return FMRES_HANDLED
	}

	return FMRES_IGNORED
}

public fw_Weapon_Spawn_Post(const entWpn)
{
	if (!FIsCustomWeapon(entWpn))
		return

	set_member(entWpn, m_Weapon_iClip, WEAPON_MAXCLIP)
	set_member(entWpn, m_Weapon_iDefaultAmmo, WEAPON_MAXAMMO)
	set_member(entWpn, m_Weapon_flBaseDamage, WEAPON_DAMAGE)
	set_member(entWpn, m_Weapon_bHasSecondaryAttack, false)

	//rg_set_iteminfo(entWpn, ItemInfo_pszName, WEAPON_CLASSNAME)
	rg_set_iteminfo(entWpn, ItemInfo_iMaxClip, WEAPON_MAXCLIP)
	rg_set_iteminfo(entWpn, ItemInfo_iMaxAmmo1, WEAPON_MAXAMMO)
}

public fw_Weapon_AddItem_Post(const entWpn, const playerId)
	if (FIsCustomWeapon(entWpn)) send_WeaponList_msg(playerId, 1)

public fw_Weapon_RemoveItem_Post(const entWpn, const playerId)
	if (FIsCustomWeapon(entWpn)) send_WeaponList_msg(playerId)

public fw_Weapon_DefaultDeploy_Pre(const entWpn, const szViewModel[], const szWeaponModel[], iAnim, const szAnimExt[])
{
	if (!FIsCustomWeapon(entWpn))
		return

	if (g_v_szWeaponModel[0])
		SetHookChainArg(2, ATYPE_STRING, g_v_szWeaponModel)

	if (g_p_szWeaponModel[0])
		SetHookChainArg(3, ATYPE_STRING, g_p_szWeaponModel)

	SetHookChainArg(4, ATYPE_INTEGER, ANIM_DRAW)
	SetHookChainArg(5, ATYPE_STRING, WEAPON_ANIMEXT)
}

public fw_Weapon_DefaultReload_Pre(const entWpn, iClip, iAnim, Float:fDelay)
{
	if (!FIsCustomWeapon(entWpn))
		return

	SetHookChainArg(2, ATYPE_INTEGER, WEAPON_MAXCLIP)
	SetHookChainArg(3, ATYPE_INTEGER, ANIM_RELOAD)
	SetHookChainArg(4, ATYPE_FLOAT, ANIMTIME_RELOAD)
}

public fw_WeaponBox_SetModel(const entWpn, const szModel[])
{
	if (is_nullent(entWpn))
		return

	if (FIsCustomWeapon(get_member(entWpn, m_WeaponBox_rgpPlayerItems, PRIMARY_WEAPON_SLOT)))
		SetHookChainArg(2, ATYPE_STRING, g_w_szWeaponModel)
}

public fw_Weapon_WeaponIdle(const entWpn)
{
	if (!FIsCustomWeapon(entWpn))
		return HAM_IGNORED

	if (get_member(entWpn, m_Weapon_flTimeWeaponIdle) > 0.0)
		return HAM_SUPERCEDE

	rg_weapon_send_animation(entWpn, ANIM_IDLE)
	set_member(entWpn, m_Weapon_flTimeWeaponIdle, ANIMTIME_IDLE)
	return HAM_SUPERCEDE
}

public fw_Weapon_PrimaryAttack(const entWpn)
{
	if (!FIsCustomWeapon(entWpn))
		return HAM_IGNORED

	if (get_member(entWpn, m_Weapon_iClip) <= 0)
	{
		ExecuteHam(Ham_Weapon_PlayEmptySound, entWpn)
		set_member(entWpn, m_Weapon_flNextPrimaryAttack, 0.2)
		return HAM_SUPERCEDE
	}

	g_iShotsFired = 0

	// Shoot the bullet.
	state StopPaybackEvent: Enabled
	g_hTraceLine = register_forward(FM_TraceLine, "fw_TraceLine_Post", 1)
	ExecuteHam(Ham_Weapon_PrimaryAttack, entWpn)
	unregister_forward(FM_TraceLine, g_hTraceLine, 1)
	state StopPaybackEvent: Disabled

	static playerId; playerId = get_member(entWpn, m_pPlayer)
	emit_sound(playerId, CHAN_WEAPON, g_szShootSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	rg_weapon_send_animation(playerId, random_num(ANIM_SHOOT1, ANIM_SHOOT3))

	#if ZE_MUZZLEFLASH == 1
		create_MuzzleFlash(playerId, 1)
	#endif

	static Float:vAngle[3]
	get_entvar(playerId, var_punchangle, vAngle)
	xs_vec_mul_scalar(vAngle, WEAPON_RECOIL, vAngle)
	set_entvar(playerId, var_punchangle, vAngle)

	set_member(entWpn, m_Weapon_flTimeWeaponIdle, ANIMTIME_SHOOT)
	set_member(entWpn, m_Weapon_flNextPrimaryAttack, WEAPON_FIRERATE)
	return HAM_SUPERCEDE
}

public fw_Weapon_SecondaryAttack(const entWpn)
{
	if (!FIsCustomWeapon(entWpn))
		return HAM_IGNORED

	/**
	 * Prevent SG552 Zoom.
	 */
	set_member(entWpn, m_Weapon_flNextSecondaryAttack, 0.2)
	return HAM_SUPERCEDE
}

public fw_TraceLine_Post(const Float:vSrc[3], const Float:vEnd[3], iFlags, iAttacker, hTrace)
{
	if (g_iShotsFired >= 1 || iFlags & IGNORE_MONSTERS)
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
	write_byte(random_num(41, 45)) // Decal.
	message_end()

	g_iShotsFired++
	return FMRES_IGNORED
}

#if ZE_MUZZLEFLASH == 1
public create_MuzzleFlash(const id, iAttachment)
{
	static entID
	if ((entID = rg_create_entity(MFLASH_REFERENCE)) == 0)
		return 0

	set_entvar(entID, var_classname, MFLASH_CLASSNAME)
	set_entvar(entID, var_movetype, MOVETYPE_FOLLOW)
	set_entvar(entID, var_aiment, id)
	set_entvar(entID, var_body, iAttachment)
	set_entvar(entID, var_skin, id)
	set_entvar(entID, var_owner, id)

	set_entvar(entID, var_frame, 0.0)
	set_entvar(entID, var_scale, 0.1)

	set_entvar(entID, var_renderamt, 255.0)
	set_entvar(entID, var_rendermode, kRenderTransAdd)

	set_entvar(entID, var_flSwimTime, float(engfunc(EngFunc_ModelFrames, g_iMuzzMdl) - 1))

	engfunc(EngFunc_SetModel, entID, g_szMuzzSprite)

	SetThink(entID, "fw_MuzzFThink")
	set_entvar(entID, var_nextthink, get_gametime() + 0.1)
	return entID
}

public fw_MuzzFThink(const entID)
{
	if (is_nullent(entID))
		return

	static Float:flFrame; flFrame = get_entvar(entID, var_frame)
	static Float:flMaxFrame; flMaxFrame = get_entvar(entID, var_flSwimTime)

	if (++flFrame > flMaxFrame)
	{
		rg_remove_entity(entID)
		return
	}

	set_entvar(entID, var_frame, flFrame)
	set_entvar(entID, var_nextthink, get_gametime() + 0.01)
}
#endif

/**
 * ***| Function |***
 */
precache_model_s(const model[])
{
	if (!file_exists(model, true))
		return set_fail_state("[FATAL ERROR] File does not exists (%s)", model)
	return precache_model(model)
}

send_WeaponList_msg(const playerId, bFakeMsg = 0)
{
	message_begin(MSG_ONE, g_iWeaponList, _, playerId)
	write_string(bFakeMsg ? WEAPON_CLASSNAME : WEAPON_REFERENCE) // Weapon Name.
	write_byte(4) // Primary Ammo ID.
	write_byte(WEAPON_MAXAMMO) // Primary Ammo Max Amount.
	write_byte(NULLENT) // Secondary Ammo ID.
	write_byte(NULLENT) // Secondary Ammo Max Amount.
	write_byte(0) // SlotID.
	write_byte(10) // Number In Slot.
	write_byte(WEAPON_ID) // WeaponID.
	write_byte(0) // Flags.
	message_end()
}