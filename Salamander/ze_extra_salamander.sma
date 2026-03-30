#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <reapi>
#include <xs>
#include <ze_core>

// Macroses.
#define FIsCustomWeapon(%1) (is_entity(%1) && get_entvar(%1,var_impulse)==WEAPON_UID)

// CWeaponInfo:
#define WEAPON_CLASSNAME "weapon_salamander_lz"
#define WEAPON_REFERENCE "weapon_m249"
#define WEAPON_ANIMEXT   "m249"
#define WEAPON_UID       61232926
#define WEAPON_ID        CSW_M249
#define WEAPON_MAXCLIP   100
#define WEAPON_MAXAMMO   200
#define WEAPON_DAMAGE    41.0
#define WEAPON_FIRERATE  0.08

#define FLAME_CLASSNAME  "salam_flame"
#define FLAME_REFERENCE  "info_target"
#define FLAME_SPEED      450
#define FLAME_MINS_SIZE  Float:{-16.0, -16.0, -16.0}
#define FLAME_MAXS_SIZE  Float:{16.0, 16.0, 16.0}
#define FLAME_NEXTDAMAGE 0.1
#define FLAME_THRESHOLD  100  // Hardcoded.
#define FLAME_MAXSCALE   2.5

// Zombie Escape: Item Info
#define ZE_ITEM_NAME     "Salamander"
#define ZE_ITEM_COST     75
#define ZE_ITEM_LIMIT    0

// Functions
#define ZE_EXTRA_ITEM    1

// View Animations
enum (+=1)
{
	ANIM_IDLE = 0,
	ANIM_SHOOT,
	ANIM_SHOOT_END,
	ANIM_RELOAD,
	ANIM_DRAW
}

enum _:eWeapCustomData
{
	CData_fInFiring = 0,

	Float:CData_flLastDamage,
	Float:CData_flLastSound,
	Float:CData_flLastAnim
}

// Animation.
const Float:ANIMP_IDLE   = 9.44
const Float:ANIMP_SHOOT  = 2.10
const Float:ANIMP_RELOAD = 5.03
const Float:ANIMP_DRAW   = 1.23

// Weapon Models:
new g_p_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/CSO/p_salamander.mdl"
new g_v_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/CSO/v_salamander.mdl"
new g_w_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/CSO/w_salamander.mdl"

new const g_szFlameSprite[] = "sprites/eexplo.spr"
new const g_szWeaponFireSound[] = "weapons/CSO/flamegun-1.wav"

// Variables.
new g_iWeaponList,
	Float:g_flMaxFrames
#if ZE_EXTRA_ITEM == 1
	new g_iItemID
#endif

// Array.
new g_WeapCustData[MAX_PLAYERS+1][eWeapCustomData]

public plugin_precache()
{
	if (!ini_read_string(ZE_FILENAME, "Weapon Models", "V_SALAMANDER", g_v_szWeaponModel, charsmax(g_v_szWeaponModel)))
		ini_write_string(ZE_FILENAME, "Weapon Models", "V_SALAMANDER", g_v_szWeaponModel)
	if (!ini_read_string(ZE_FILENAME, "Weapon Models", "P_SALAMANDER", g_p_szWeaponModel, charsmax(g_p_szWeaponModel)))
		ini_write_string(ZE_FILENAME, "Weapon Models", "P_SALAMANDER", g_p_szWeaponModel)
	if (!ini_read_string(ZE_FILENAME, "Weapon Models", "W_SALAMANDER", g_w_szWeaponModel, charsmax(g_w_szWeaponModel)))
		ini_write_string(ZE_FILENAME, "Weapon Models", "W_SALAMANDER", g_w_szWeaponModel)

	// Pre-load Model(s)
	precache_model_s(g_p_szWeaponModel)
	precache_model_s(g_v_szWeaponModel)
	precache_model_s(g_w_szWeaponModel)

	g_flMaxFrames = float(engfunc(EngFunc_ModelFrames, precache_model_s(g_szFlameSprite)))

	precache_sound(g_szWeaponFireSound)

	new const szMoreResourc[][] =
	{
		"sound/weapons/CSO/flamegun_clipin1.wav",
		"sound/weapons/CSO/flamegun_clipin2.wav",
		"sound/weapons/CSO/flamegun_clipout1.wav",
		"sound/weapons/CSO/flamegun_clipout2.wav",
		"sound/weapons/CSO/flamegun_draw.wav",

		"sprites/640hudc5.spr",
		"sprites/weapon_salamander_lz.txt"
	}

	for (new i; i < sizeof(szMoreResourc); i++)
	{
		precache_generic(szMoreResourc[i])
	}
}

public plugin_init()
{
	// Load Plug-In.
	register_plugin("[ZE] Extra Item: Salamander", "1.0", "z0h1r-LK")

	// Hook Chains.
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "fw_Weapon_DefaultDeploy_Pre")
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultReload, "fw_Weapon_DefaultReload_Pre")
	RegisterHookChain(RG_CBasePlayer_RemovePlayerItem, "fw_RemovePlayerIrem_Pre")
	RegisterHookChain(RG_CWeaponBox_SetModel, "fw_WeaponBox_SetModel_Pre")

	// Hams.
	RegisterHam(Ham_Weapon_WeaponIdle, WEAPON_REFERENCE, "fw_Weapon_WeaponIdle_Pre")
	RegisterHam(Ham_Weapon_PrimaryAttack, WEAPON_REFERENCE, "fw_Weapon_PrimaryAttack_Pre")
	RegisterHam(Ham_Item_AddToPlayer, WEAPON_REFERENCE, "fw_Weapon_AddToPlayer_Post", 1)

	// FakeMeta.
	register_forward(FM_ShouldCollide, "fw_ShouldCollide_Pre")
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)

	// Commands.
	register_clcmd(WEAPON_CLASSNAME, "cmd_SelectWeapon")

	// Extra Item's.
#if ZE_EXTRA_ITEM == 1
	g_iItemID = ze_item_register(ZE_ITEM_NAME, ZE_ITEM_COST, ZE_ITEM_LIMIT)
#endif

	// Set Values.
	g_iWeaponList = get_user_msgid("WeaponList")
}

#if ZE_EXTRA_ITEM == 1
public ze_select_item_pre(id, iItem, bool:bIgnoreCost, bool:bInMenu)
{
	if (iItem != g_iItemID)
		return ZE_ITEM_AVAILABLE

	if (ze_is_user_zombie(id))
		return ZE_ITEM_DONT_SHOW

	return ZE_ITEM_AVAILABLE
}

public ze_select_item_post(id, iItem, bool:bIgnoreCost)
{
	if (iItem != g_iItemID)
		return

	if (rg_give_custom_item(id, WEAPON_REFERENCE, GT_DROP_AND_REPLACE, WEAPON_UID) == NULLENT)
		server_print("[ZE] Error while giving the weapon to the player (id: %d)", id)
}
#endif

public cmd_SelectWeapon(const id, level, cid)
{
	engclient_cmd(id, WEAPON_REFERENCE)
	return PLUGIN_HANDLED
}

public fw_ShouldCollide_Pre(const entID, const pevOther)
{
	if (!FClassnameIs(pevOther, FLAME_CLASSNAME))
		return FMRES_IGNORED

	if (!is_user_connected(entID))
		return FMRES_IGNORED

	forward_return(FMV_CELL, 0)
	return FMRES_SUPERCEDE
}

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

public fw_Weapon_DefaultDeploy_Pre(const entWpn, const szViewModel[], const szWeaponModel[], iAnim, const szAnimExt[], skiplocal)
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

public fw_Weapon_DefaultReload_Pre(const entWpn, iClipSize, iAnim, Float:flDelay)
{
	if (!FIsCustomWeapon(entWpn))
		return

	SetHookChainArg(2, ATYPE_INTEGER, WEAPON_MAXCLIP)
	SetHookChainArg(3, ATYPE_INTEGER, ANIM_RELOAD)
	SetHookChainArg(4, ATYPE_FLOAT, ANIMP_RELOAD)
}

public fw_Weapon_AddToPlayer_Post(const entWpn, const iPlayer)
{
	if (!FIsCustomWeapon(entWpn))
		return

	send_WeaponList_msg(iPlayer, 1)
}

public fw_RemovePlayerIrem_Pre(const iPlayer, const entWpn)
{
	if (!FIsCustomWeapon(entWpn))
		return

	send_WeaponList_msg(iPlayer)
}

public fw_WeaponBox_SetModel_Pre(const entWpn, const szModel[])
{
	if (is_nullent(entWpn))
		return

	if (FIsCustomWeapon(get_member(entWpn, m_WeaponBox_rgpPlayerItems, PRIMARY_WEAPON_SLOT)))
		SetHookChainArg(2, ATYPE_STRING, g_w_szWeaponModel)
}

public fw_Weapon_WeaponIdle_Pre(const entWpn)
{
	if (!FIsCustomWeapon(entWpn))
		return HAM_IGNORED

	if (get_member(entWpn, m_Weapon_flTimeWeaponIdle) > 0.0)
		return HAM_SUPERCEDE

	static iPlayer; iPlayer = get_member(entWpn, m_pPlayer)

	if (g_WeapCustData[iPlayer][CData_fInFiring])
	{
		rg_weapon_send_animation(iPlayer, ANIM_SHOOT_END)
		set_member(entWpn, m_Weapon_flTimeWeaponIdle, ANIMP_SHOOT)
		g_WeapCustData[iPlayer][CData_flLastAnim] = 0.0
		g_WeapCustData[iPlayer][CData_fInFiring] = 0
	}
	else
	{
		rg_weapon_send_animation(iPlayer, ANIM_IDLE)
		set_member(entWpn, m_Weapon_flTimeWeaponIdle, ANIMP_IDLE)
	}

	return HAM_SUPERCEDE
}

public fw_Weapon_PrimaryAttack_Pre(const entWpn)
{
	if (!FIsCustomWeapon(entWpn))
		return HAM_IGNORED

	static iClip; iClip = get_member(entWpn, m_Weapon_iClip)
	if (iClip <= 0)
	{
		ExecuteHam(Ham_Weapon_PlayEmptySound, entWpn)
		set_member(entWpn, m_Weapon_flNextPrimaryAttack, 0.2)
		return HAM_SUPERCEDE
	}

	static iPlayer; iPlayer = get_member(entWpn, m_pPlayer)

	static Float:vSrc[3], Float:vVelo[3], Float:vAng[3], Float:vFwd[5]
	ExecuteHam(Ham_Player_GetGunPosition, iPlayer, vSrc)
	get_entvar(iPlayer, var_v_angle, vAng)

	engfunc(EngFunc_AngleVectors, vAng, vFwd, 0, vAng)
	xs_vec_mul_scalar(vFwd, 10.0, vFwd)
	xs_vec_mul_scalar(vAng, -5.0, vAng)
	xs_vec_add(vSrc, vFwd, vSrc)
	xs_vec_add(vSrc, vAng, vSrc)

	velocity_by_aim(iPlayer, FLAME_SPEED, vVelo)

	create_FlameSpr(vSrc, vVelo, iPlayer)
	set_member(entWpn, m_Weapon_iClip, iClip - 1)

	static Float:flHlTime; flHlTime = get_gametime()
	if (g_WeapCustData[iPlayer][CData_flLastAnim] <= flHlTime)
	{
		rg_weapon_send_animation(iPlayer, ANIM_SHOOT)
		g_WeapCustData[iPlayer][CData_flLastAnim] = flHlTime + ANIMP_SHOOT
	}

	if (g_WeapCustData[iPlayer][CData_flLastSound] <= flHlTime)
	{
		emit_sound(iPlayer, CHAN_WEAPON, g_szWeaponFireSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		g_WeapCustData[iPlayer][CData_flLastSound] = flHlTime + 0.9
	}

	g_WeapCustData[iPlayer][CData_fInFiring] = 1
	set_member(entWpn, m_Weapon_flTimeWeaponIdle, WEAPON_FIRERATE)
	set_member(entWpn, m_Weapon_flNextPrimaryAttack, WEAPON_FIRERATE)
	return HAM_SUPERCEDE
}

public create_FlameSpr(const Float:vSrc[3], const Float:vVelo[3], iAttacker)
{
	if (global_get(glb_maxEntities) - engfunc(EngFunc_NumberOfEntities) <= FLAME_THRESHOLD)
		return

	static entity
	if ((entity = rg_create_entity(FLAME_REFERENCE)) == 0)
		return

	set_entvar(entity, var_classname, FLAME_CLASSNAME)
	set_entvar(entity, var_solid, SOLID_TRIGGER)
	set_entvar(entity, var_movetype, MOVETYPE_FLYMISSILE)
	set_entvar(entity, var_owner, iAttacker)
	set_entvar(entity, var_velocity, vVelo)
	set_entvar(entity, var_scale, 0.1)

	set_entvar(entity, var_rendermode, kRenderTransAdd)
	set_entvar(entity, var_renderamt, 255.0)

	engfunc(EngFunc_SetModel, entity, g_szFlameSprite)
	engfunc(EngFunc_SetSize, entity, FLAME_MINS_SIZE, FLAME_MAXS_SIZE)
	engfunc(EngFunc_SetOrigin, entity, vSrc)

	SetThink(entity, "fw_FlameThink_Pre")
	SetTouch(entity, "fw_FlameTouch_Pre")

	// Th!nk.
	// set_entvar(entity, var_nextthink, get_gametime())
	dllfunc(DLLFunc_Think, entity)
}

public fw_FlameThink_Pre(const entity)
{
	if (is_nullent(entity))
		return

	static Float:flFrame; flFrame = get_entvar(entity, var_frame)

	if (flFrame >= g_flMaxFrames)
	{
		SetThink(entity, "")
		SetTouch(entity, "")
		rg_remove_entity(entity)
		return
	}

	flFrame++
	set_entvar(entity, var_frame, flFrame)

	static Float:flHlTime; flHlTime = get_gametime()
	static Float:flScale;  flScale  = get_entvar(entity, var_scale)

	if (get_entvar(entity, var_flSwimTime) <= flHlTime)
	{
		flScale += 0.2
		set_entvar(entity, var_scale, flScale)
		set_entvar(entity, var_flSwimTime, flHlTime + 0.1)
	}

	// Th!nk...
	set_entvar(entity, var_nextthink, flHlTime + 0.05)
}

public fw_FlameTouch_Pre(const entity, const pevOther)
{
	if (is_nullent(entity) || FClassnameIs(pevOther, FLAME_CLASSNAME))
		return HC_CONTINUE

	static iAttacker; iAttacker = get_entvar(entity, var_owner)

	if (pevOther != iAttacker && !is_user_connected(pevOther))
	{
		set_entvar(entity, var_movetype, MOVETYPE_NONE)
	}

	if (!is_user_alive(iAttacker) || !ze_is_user_zombie(pevOther) || pevOther == iAttacker)
	{
		return HC_CONTINUE
	}

	static Float:flHlTime; flHlTime = get_gametime()

	if (g_WeapCustData[pevOther][CData_flLastDamage] <= flHlTime)
	{
		// Damage the victim.
		ExecuteHamB(Ham_TakeDamage, pevOther, iAttacker, iAttacker, WEAPON_DAMAGE, DMG_BURN)
		g_WeapCustData[pevOther][CData_flLastDamage] = flHlTime + FLAME_NEXTDAMAGE
	}

	return HC_CONTINUE
}

/* --- Functions --- */
precache_model_s(const model[])
{
	if (!file_exists(model, true))
		set_fail_state("[FATAL ERROR] File does not exists '%s'", model)
	return precache_model(model)
}

send_WeaponList_msg(const id, const iMode = 0)
{
	message_begin(MSG_ONE, g_iWeaponList, _, id)
	write_string(iMode ? WEAPON_CLASSNAME : WEAPON_REFERENCE) // Weapon Name.
	write_byte(3) // Primary Ammo ID.
	write_byte(WEAPON_MAXAMMO) // Primary Ammo Max Amount.
	write_byte(NULLENT) // Secondary Ammo ID.
	write_byte(NULLENT) // Secondary Ammo Max Amount.
	write_byte(0) // Slot ID.
	write_byte(4) // Number In Slot.
	write_byte(WEAPON_ID) // Weapon ID.
	write_byte(0) // Flags.
	message_end()
}