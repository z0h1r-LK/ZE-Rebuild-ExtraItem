#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <reapi>
#include <xs>
#include <ze_core>

// Macroses.
#define FIsCustomWeapon(%1) (is_entity(%1) && get_entvar(%1,var_impulse)==WEAPON_UID)
#define FIsPlayer(%1)       (1<=(%1)<=MaxClients)

// CWeapon | ItemInfo:
#define WEAPON_CLASSNAME "weapon_buffak_lz"
#define WEAPON_REFERENCE "weapon_ak47"
#define WEAPON_ANIMEXT   "rifle"
#define WEAPON_ID        CSW_AK47
#define WEAPON_UID       3454626
#define WEAPON_MAXCLIP   50
#define WEAPON_MAXAMMO   250
#define WEAPON_DAMAGE    24.0
#define WEAPON_DAMAGE_S  224.0
#define WEAPON_FIRERATE  0.11
#define WEAPON_FIRERATE2 0.6
#define WEAPON_MAXRANGE  4096.0  // Secondary Attack.
#define WEAPON_SPERADIUS 32.0
#define WEAPON_ACCURACY  0.83
#define WEAPON_SPECFOV   85

#define MUZZ_CLASSNAME   "muzz_buffak"
#define MUZZ_REFERNECE   "info_target"
#define MUZZ_SPRSCALE    0.08
#define MUZZ_THRESHOLD   100  // Hardcoded value.

// Zombie Escape: Item Info
#define ZE_ITEM_NAME     "AK47 Paladin"
#define ZE_ITEM_COST     45
#define ZE_ITEM_LIMIT    0

// Zombie Escape: Functions
#define ZE_EXTRA_ITEM     1   /* 1 = Enabled | 0 = Disabled */
#define ZE_MUZZLE_FLASH   1   /* 1 = Enabled | 0 = Disabled */

enum (+=1)
{
	ANIM_IDLE = 0,
	ANIM_RELOAD,
	ANIM_DRAW,
	ANIM_SHOOT1,
	ANIM_SHOOT2,
	ANIM_SHOOT3
}

enum _:eFireSounds
{
	SND_FIRE_NORMAL = 0,
	SND_FIRE_SPECIAL
}

const Float:ANIMP_IDLE  = 3.03
const Float:ANIMP_DRAW  = 1.03
const Float:ANIMP_RELOAD= 2.03
const Float:ANIMP_SHOOT = 1.03

// Weapon Resources:
new g_p_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/CSO/p_buffak.mdl"
new g_v_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/CSO/v_buffak.mdl"
new g_w_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/CSO/w_buffak.mdl"

new const g_szMuzzSprite[] = "sprites/CSO/ef_buffak_mflash.spr"

new const g_szFireSounds[eFireSounds][] =
{
	"weapons/CSO/ak47buff-1.wav",
	"weapons/CSO/ak47buff-2.wav"
}

// Variables.
new g_iFOV,
	g_iExploSpr,
	g_iNumTrace,
	g_iMaxMFrames,
	g_hTraceLine,
	g_iWeaponList,
	g_bitsSpecMode
#if ZE_EXTRA_ITEM == 1
	new g_iItemId
#endif

public plugin_precache()
{
	if (!ini_read_string(ZE_FILENAME, ZE_ITEM_NAME, "V_BUFFAK", g_v_szWeaponModel, charsmax(g_v_szWeaponModel)))
		ini_write_string(ZE_FILENAME, ZE_ITEM_NAME, "V_BUFFAK", g_v_szWeaponModel)
	if (!ini_read_string(ZE_FILENAME, ZE_ITEM_NAME, "P_BUFFAK", g_p_szWeaponModel, charsmax(g_p_szWeaponModel)))
		ini_write_string(ZE_FILENAME, ZE_ITEM_NAME, "P_BUFFAK", g_p_szWeaponModel)
	if (!ini_read_string(ZE_FILENAME, ZE_ITEM_NAME, "W_BUFFAK", g_w_szWeaponModel, charsmax(g_w_szWeaponModel)))
		ini_write_string(ZE_FILENAME, ZE_ITEM_NAME, "W_BUFFAK", g_w_szWeaponModel)

	precache_model_s(g_p_szWeaponModel)
	precache_model_s(g_v_szWeaponModel)
	precache_model_s(g_w_szWeaponModel)
	g_iExploSpr = precache_model_s("sprites/CSO/ef_buffak_hit.spr")

	precache_sound(g_szFireSounds[SND_FIRE_NORMAL])
	precache_sound(g_szFireSounds[SND_FIRE_SPECIAL])

	new const szModelResources[][] =
	{
		"sound/weapons/CSO/ak47buff_idle.wav",
		"sound/weapons/CSO/ak47buff_draw.wav",
		"sound/weapons/CSO/ak47buff_reload.wav",

		"sprites/640hudc5.spr",
		"sprites/weapon_buffak_lz.txt"
	}

	for (new i = 0; i < sizeof(szModelResources); i++)
		precache_generic(szModelResources[i])

	g_iMaxMFrames = engfunc(EngFunc_ModelFrames, precache_model_s(g_szMuzzSprite))
}

public plugin_init()
{
	// Load Plug-In.
	register_plugin("[ZE] Extra Item: AK47 Paladin", "1.0", "z0h1r-LK")

	// Hook Chains.
	RegisterHookChain(RG_CBasePlayer_RemovePlayerItem, "fw_RemovePlayerItem_Post", 1)
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "fw_Weapon_DefaultDeploy_Pre")
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultReload, "fw_Weapon_DefaultReload_Pre")
	RegisterHookChain(RG_CWeaponBox_SetModel, "fw_WeaponBox_SetModel_Pre")

	// Hams.
	RegisterHam(Ham_Spawn, WEAPON_REFERENCE, "fw_Weapon_Spawn_Post", 1)
	RegisterHam(Ham_Weapon_WeaponIdle, WEAPON_REFERENCE, "fw_Weapon_WeaponIdle_Pre")
	RegisterHam(Ham_Weapon_PrimaryAttack, WEAPON_REFERENCE, "fw_Weapon_PrimaryAttack_Pre")
	RegisterHam(Ham_Weapon_SecondaryAttack, WEAPON_REFERENCE, "fw_Weapon_SecondaryAttack_Pre")
	RegisterHam(Ham_Item_AddToPlayer, WEAPON_REFERENCE, "fw_Weapon_AddToPlayer_Post", 1)
	RegisterHam(Ham_Item_Holster, WEAPON_REFERENCE, "fw_Weapon_Holster_Post", 1)

	// FakeMeta.
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent_Pre")
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)

	// New Item.
#if ZE_EXTRA_ITEM == 1
	g_iItemId = ze_item_register(ZE_ITEM_NAME, ZE_ITEM_COST, ZE_ITEM_LIMIT)
#endif

	// Commands.
	register_clcmd(WEAPON_CLASSNAME, "cmd_SelectWeapon")

	// Set Values.
	g_iFOV = get_user_msgid("SetFOV")
	g_iWeaponList = get_user_msgid("WeaponList")
}

public client_disconnected(id, bool:drop, message[], maxlen)
{
	if (is_user_hltv(id))  // Proxy?
		return

	flag_unset(g_bitsSpecMode, id)
}

public cmd_SelectWeapon(const id, level, cid)
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
		log_error(AMX_ERR_GENERAL, "[ZE] Invalid Weapon ID (-1)")
}
#endif

public fw_PlaybackEvent_Pre() < /* no statement */ >
	return FMRES_IGNORED

public fw_PlaybackEvent_Pre() <FireBullets: Enabled>
	return FMRES_SUPERCEDE

public fw_PlaybackEvent_Pre() <FireBullets: Disabled>
	return FMRES_IGNORED

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

public fw_Weapon_AddToPlayer_Post(const entWpn, const playerID)
{
	if (!FIsCustomWeapon(entWpn))
		return

	send_WeaponList_msg(playerID, 1)
}

public fw_RemovePlayerItem_Post(const playerID, const entWpn)
{
	if (!FIsCustomWeapon(entWpn))
		return

	send_WeaponList_msg(playerID)
}

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

public fw_Weapon_DefaultReload_Pre(const entWpn, iClip, iAnim, Float:flDelay)
{
	if (!FIsCustomWeapon(entWpn))
		return

	SetHookChainArg(2, ATYPE_INTEGER, WEAPON_MAXCLIP)
	SetHookChainArg(3, ATYPE_INTEGER, ANIM_RELOAD)
	SetHookChainArg(4, ATYPE_FLOAT, ANIMP_RELOAD)

	Weapon_SetSpecialMode(get_member(entWpn, m_pPlayer), false)
}

public fw_WeaponBox_SetModel_Pre(const entWpn, const szModel[])
{
	if (is_nullent(entWpn))
		return

	if (FIsCustomWeapon(get_member(entWpn, m_WeaponBox_rgpPlayerItems, PRIMARY_WEAPON_SLOT)))
		SetHookChainArg(2, ATYPE_STRING, g_w_szWeaponModel)
}

public fw_Weapon_Spawn_Post(const entWpn)
{
	if (!FIsCustomWeapon(entWpn))
		return

	set_member(entWpn, m_Weapon_iClip, WEAPON_MAXCLIP)
	set_member(entWpn, m_Weapon_iDefaultAmmo, WEAPON_MAXAMMO)
	set_member(entWpn, m_Weapon_flBaseDamage, WEAPON_DAMAGE)
	set_member(entWpn, m_Weapon_flAccuracy, WEAPON_ACCURACY)
	set_member(entWpn, m_Weapon_bHasSecondaryAttack, true)

	rg_set_iteminfo(entWpn, ItemInfo_iMaxClip, WEAPON_MAXCLIP)
	rg_set_iteminfo(entWpn, ItemInfo_iMaxAmmo1, WEAPON_MAXAMMO)
}

public fw_Weapon_WeaponIdle_Pre(const entWpn)
{
	if (!FIsCustomWeapon(entWpn))
		return HAM_IGNORED

	if (get_member(entWpn, m_Weapon_flTimeWeaponIdle) > 0.0)
		return HAM_SUPERCEDE

	rg_weapon_send_animation(entWpn, ANIM_IDLE)
	set_member(entWpn, m_Weapon_flTimeWeaponIdle, ANIMP_IDLE)
	return HAM_SUPERCEDE
}

public fw_Weapon_PrimaryAttack_Pre(const entWpn)
{
	if (!FIsCustomWeapon(entWpn))
		return HAM_IGNORED

	static iClip
	if ((iClip = get_member(entWpn, m_Weapon_iClip)) <= 0)
	{
		ExecuteHam(Ham_Weapon_PlayEmptySound, entWpn)
		set_member(entWpn, m_Weapon_flNextPrimaryAttack, 0.2)
		return HAM_SUPERCEDE
	}

	static iAttacker; iAttacker = get_member(entWpn, m_pPlayer)

	if (flag_get_boolean(g_bitsSpecMode, iAttacker))
	{
		static Float:vSrc[3], Float:vEnd[3]
		ExecuteHamB(Ham_Player_GetGunPosition, iAttacker, vSrc)

		// Target.
		get_entvar(iAttacker, var_v_angle, vEnd)
		angle_vector(vEnd, ANGLEVECTOR_FORWARD, vEnd)
		xs_vec_mul_scalar(vEnd, WEAPON_MAXRANGE, vEnd)
		xs_vec_add(vSrc, vEnd, vEnd)

		engfunc(EngFunc_TraceLine, vSrc, vEnd, DONT_IGNORE_MONSTERS, iAttacker, 0)
		get_tr2(0, TR_vecEndPos, vEnd)

		static iEnemy; iEnemy = NULLENT
		while ((iEnemy = engfunc(EngFunc_FindEntityInSphere, iEnemy, vEnd, WEAPON_SPERADIUS)))
		{
			if (is_nullent(iEnemy))
				continue

			if (FIsPlayer(iEnemy))
			{
				if (iAttacker != iEnemy && is_user_alive(iEnemy) && ze_is_user_zombie(iEnemy))
					ExecuteHamB(Ham_TakeDamage, iEnemy, iAttacker, iAttacker, WEAPON_DAMAGE_S, (DMG_BLAST|DMG_BULLET))
			}
			else // Entity.
			{
				if (get_entvar(iEnemy, var_health) > 0.0 && get_entvar(iEnemy, var_takedamage) != DAMAGE_NO)
					ExecuteHamB(Ham_TakeDamage, iEnemy, iAttacker, iAttacker, WEAPON_DAMAGE_S, DMG_GENERIC)
			}
		}

		// Explosion.
		message_begin_f(MSG_PVS, SVC_TEMPENTITY, vEnd)
		write_byte(TE_EXPLOSION) // TE id.
		write_coord_f(vEnd[0]) // Position X.
		write_coord_f(vEnd[1]) // Position Y.
		write_coord_f(vEnd[2]) // Position Z.
		write_short(g_iExploSpr) // Sprite Index.
		write_byte(8) // Scale.
		write_byte(10) // Framerate.
		write_byte(TE_EXPLFLAG_NODLIGHTS|TE_EXPLFLAG_NOPARTICLES|TE_EXPLFLAG_NOSOUND) // Flags.
		message_end()

		set_member(entWpn, m_Weapon_iClip, iClip - 1)

		rg_set_animation(iAttacker, PLAYER_ATTACK1)
		rg_weapon_kickback(iAttacker, 1.1, 1.1, 0.1, 0.1, 2.4, 2.4, 2)
		emit_sound(iAttacker, CHAN_WEAPON, g_szFireSounds[SND_FIRE_SPECIAL], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)

		rp_weapon_set_nextattack(entWpn, WEAPON_FIRERATE2, WEAPON_FIRERATE2, ANIMP_SHOOT)
	}
	else
	{
		g_iNumTrace = 0
		state FireBullets: Enabled
		g_hTraceLine = register_forward(FM_TraceLine, "fw_TraceLine_Post", 1)
		ExecuteHam(Ham_Weapon_PrimaryAttack, entWpn)
		unregister_forward(FM_TraceLine, g_hTraceLine, 1)
		state FireBullets: Disabled

		rp_weapon_set_nextattack(entWpn, WEAPON_FIRERATE, WEAPON_FIRERATE, ANIMP_SHOOT)
		emit_sound(iAttacker, CHAN_WEAPON, g_szFireSounds[SND_FIRE_NORMAL], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	}

	create_MuzzleFlash(iAttacker, 1)
	rg_weapon_send_animation(iAttacker, random_num(ANIM_SHOOT1, ANIM_SHOOT3))
	return HAM_SUPERCEDE
}

public fw_Weapon_SecondaryAttack_Pre(const entWpn)
{
	if (!FIsCustomWeapon(entWpn))
		return HAM_IGNORED

	static iPlayer; iPlayer = get_member(entWpn, m_pPlayer)
	if (flag_get_boolean(g_bitsSpecMode, iPlayer))
		Weapon_SetSpecialMode(iPlayer, false)
	else
		Weapon_SetSpecialMode(iPlayer, true)

	rp_weapon_set_nextattack(entWpn, 0.85, 0.85, ANIMP_SHOOT)
	return HAM_SUPERCEDE
}

public fw_Weapon_Holster_Post(const entWpn)
{
	if (!FIsCustomWeapon(entWpn))
		return

	Weapon_SetSpecialMode(get_member(entWpn, m_pPlayer), false)
}

public fw_TraceLine_Post(const Float:vSrc[3], const Float:vEnd[3], iFlags, iAttacker, hTr)
{
	if (g_iNumTrace > 0 || iFlags & IGNORE_MONSTERS)
		return FMRES_IGNORED

	static iTarget; iTarget = get_tr2(hTr, TR_pHit)
	if (iTarget > 0) if (get_entvar(hTr, var_solid) != SOLID_BSP) return FMRES_IGNORED

	static Float:vTarget[3]
	get_tr2(hTr, TR_vecEndPos, vTarget)

	// Decal.
	message_begin_f(MSG_PVS, SVC_TEMPENTITY, vTarget)
	write_byte(TE_GUNSHOTDECAL) // TE id.
	write_coord_f(vTarget[0]) // Position X.
	write_coord_f(vTarget[1]) // Position Y.
	write_coord_f(vTarget[2]) // Position Z.
	write_short(iTarget > 0 ? iTarget : 0) // Entity ID.
	write_byte(random_num(41, 45)) // Decal Index.
	message_end()

	g_iNumTrace++
	return FMRES_IGNORED
}

public Weapon_SetSpecialMode(const id, bool:bSet)
{
	if (!bSet)
	{
		rp_set_user_fov(id)
		flag_unset(g_bitsSpecMode, id)
	}
	else
	{
		rp_set_user_fov(id, 85)
		flag_set(g_bitsSpecMode, id)
	}
}

public create_MuzzleFlash(const id, iAttachment)
{
	if (global_get(glb_maxEntities) - engfunc(EngFunc_NumberOfEntities) <= MUZZ_THRESHOLD)
		return

	static entID
	if (!(entID = rg_create_entity(MUZZ_REFERNECE)))
		return

	set_entvar(entID, var_classname, MUZZ_CLASSNAME)
	set_entvar(entID, var_movetype, MOVETYPE_FOLLOW)
	set_entvar(entID, var_scale, MUZZ_SPRSCALE)
	set_entvar(entID, var_aiment, id)
	set_entvar(entID, var_owner, id)
	set_entvar(entID, var_skin, id)
	set_entvar(entID, var_body, iAttachment)
	set_entvar(entID, var_rendermode, kRenderTransAdd)
	set_entvar(entID, var_renderamt, 255.0)

	engfunc(EngFunc_SetModel, entID, g_szMuzzSprite)

	SetThink(entID, "fw_MuzzFThink_Pre")
	set_entvar(entID, var_nextthink, get_gametime() + 0.05)
}

public fw_MuzzFThink_Pre(const entID)
{
	if (is_nullent(entID))
		return

	static Float:flFrame; flFrame = get_entvar(entID, var_frame)
	if (flFrame > g_iMaxMFrames)
	{
		SetThink(entID, "")
		rg_remove_entity(entID)
		return
	}

	flFrame++
	set_entvar(entID, var_frame, flFrame)
	set_entvar(entID, var_nextthink, get_gametime() + 0.1)
}

/**
 * Function(s) :
 */
precache_model_s(const szModel[])
{
	if (!file_exists(szModel, true))
		return set_fail_state("[FATAL ERROR] File does not exists (%s)", szModel)

	return precache_model(szModel)
}

rp_set_user_fov(const id, iFOV = DEFAULT_NO_ZOOM)
{
	set_member(id, m_iFOV, iFOV)

	// Update FOV in server-side.
	message_begin(MSG_ONE, g_iFOV, _, id)
	write_byte(iFOV) // Degree.
	message_end()
}

rp_weapon_set_nextattack(const entity, Float:pri_attack, Float:sec_attack, Float:idle_time)
{
	set_member(entity, m_Weapon_flTimeWeaponIdle, idle_time)
	set_member(entity, m_Weapon_flNextPrimaryAttack, pri_attack)
	set_member(entity, m_Weapon_flNextSecondaryAttack, sec_attack)
}

send_WeaponList_msg(const id, iMode = 0)
{
	message_begin(MSG_ONE, g_iWeaponList, _, id)
	write_string(iMode ? WEAPON_CLASSNAME : WEAPON_REFERENCE) // Weapon Name.
	write_byte(2) // Primary Ammo ID.
	write_byte(WEAPON_MAXAMMO) // Primary Ammo Max Amount.
	write_byte(NULLENT) // Secondary Ammo ID.
	write_byte(NULLENT) // Secondary Ammo Max Amount.
	write_byte(0) // SlotID.
	write_byte(1) // Number in slot.
	write_byte(WEAPON_ID) // Weapon ID.
	write_byte(0) // Flags
	message_end()
}