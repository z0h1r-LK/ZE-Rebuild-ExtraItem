#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <reapi>
#include <ze_core>

// Defines.
#define EXTRA_ITEM 1   // To disable weapon on Extra Item, Switch value to 0

// Macro.
#define FIsCustomWeapon(%1) (is_entity(%1) && (get_entvar(%1,var_impulse) == WEAPON_UID))

// Zombie Escape: Item Info.
#if EXTRA_ITEM != 0
stock const ZE_ITEM_NAME[] = "AK47 Golden"
stock const ZE_ITEM_COST = 35
stock const ZE_ITEM_LIMIT = 0
#endif

// Weapon Info:
new const WEAPON_REFERENCE[] = "weapon_ak47"
new const WEAPON_ANIMEXT[] = "rifle"
const WEAPON_UID = 8558424

// Draw anim.
const ANIM_DRAW = 2

// Weapon models.
new g_v_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/zm_es/v_ak47g.mdl"
new g_p_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/zm_es/p_ak47g.mdl"
new g_w_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/zm_es/w_ak47g.mdl"

// CVars.
new g_iClipSize,
	g_iDefaultAmmo,
	bool:g_bBltBeam,
	Float:g_flBaseDamage

// Variables.
new g_iBeamSpr,
	bool:g_bTraceLine

#if EXTRA_ITEM != 0
new g_iItemID
#endif

public plugin_precache()
{
#if EXTRA_ITEM == 1
	if (!ini_read_string(ZE_ET_FILENAME, ZE_ITEM_NAME, "VIEW_MODEL", g_v_szWeaponModel, charsmax(g_v_szWeaponModel)))
		ini_write_string(ZE_ET_FILENAME, ZE_ITEM_NAME, "VIEW_MODEL", g_v_szWeaponModel)
	if (!ini_read_string(ZE_ET_FILENAME, ZE_ITEM_NAME, "PLAYER_MODEL", g_p_szWeaponModel, charsmax(g_p_szWeaponModel)))
		ini_write_string(ZE_ET_FILENAME, ZE_ITEM_NAME, "PLAYER_MODEL", g_p_szWeaponModel)
	if (!ini_read_string(ZE_ET_FILENAME, ZE_ITEM_NAME, "WORLD_MODEL", g_w_szWeaponModel, charsmax(g_w_szWeaponModel)))
		ini_write_string(ZE_ET_FILENAME, ZE_ITEM_NAME, "WORLD_MODEL", g_w_szWeaponModel)
#endif

	new const szBeamSprite[] = "sprites/laserbeam.spr"

	// Pre-load Models.
	precache_model(g_p_szWeaponModel)
	precache_model(g_v_szWeaponModel)
	precache_model(g_w_szWeaponModel)
	g_iBeamSpr = precache_model(szBeamSprite)
}

public plugin_init()
{
	// Load Plug-In.
	register_plugin("[ZE] Extra Item: AK47 Golden", "1.1", "z0h1r-LK")

	// Hook Chain.
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "fw_Weapon_DefaultDeploy_Pre")

	// Hams.
	RegisterHam(Ham_Item_AddToPlayer, WEAPON_REFERENCE, "fw_Weapon_AddToPlayer_Post", 1)
	RegisterHam(Ham_Weapon_PrimaryAttack, WEAPON_REFERENCE, "fw_Weapon_PrimaryAttack")
	RegisterHam(Ham_Weapon_PrimaryAttack, WEAPON_REFERENCE, "fw_Weapon_PrimaryAttack_Post", 1)

	// FakeMeta.
	register_forward(FM_TraceLine, "fw_TraceLine_Post", 1)

	// CVars.
	bind_pcvar_num(register_cvar("ze_ak47g_beam", "1"), g_bBltBeam)
	bind_pcvar_num(register_cvar("ze_ak47g_clip", "30"), g_iClipSize)
	bind_pcvar_num(register_cvar("ze_ak47g_ammo", "90"), g_iDefaultAmmo)
	bind_pcvar_float(register_cvar("ze_ak47g_damage", "72.0"), g_flBaseDamage)

#if EXTRA_ITEM == 1
	g_iItemID = ze_item_register(ZE_ITEM_NAME, ZE_ITEM_COST, ZE_ITEM_LIMIT)  // New Item.
#endif
}

#if EXTRA_ITEM == 1
public ze_select_item_pre(id, iItem, bool:bIgnoreCost, bool:bInMenu)
{
	if (iItem != g_iItemID)
		return ZE_ITEM_AVAILABLE

	// Don't display this item in Zombies Items.
	if (ze_is_user_zombie(id))
		return ZE_ITEM_DONT_SHOW

	return ZE_ITEM_AVAILABLE
}

public ze_select_item_post(id, iItem, bool:bIgnoreCost)
{
	if (iItem != g_iItemID)
		return

	give_Weapon(id)
}

public give_Weapon(const id)
{
	new iWpnEnt
	if ((iWpnEnt = rg_give_custom_item(id, WEAPON_REFERENCE, GT_DROP_AND_REPLACE, WEAPON_UID)) == NULLENT)
	{
		log_error(AMX_ERR_NONE, "[ZE] Invalid Weapon ID (-1)")
		return
	}

	set_member(iWpnEnt, m_Weapon_iClip, g_iClipSize)
	set_member(iWpnEnt, m_Weapon_flBaseDamage, g_flBaseDamage)

	rg_set_iteminfo(iWpnEnt, ItemInfo_iMaxClip, g_iClipSize)
	rg_set_iteminfo(iWpnEnt, ItemInfo_iMaxAmmo1, g_iDefaultAmmo)
}
#endif

public fw_Weapon_DefaultDeploy_Pre(const iWpnEnt, const szViewModel[], const szWeaponModel[], iAnim, const szAnimExt[], skiplocal)
{
	if (!FIsCustomWeapon(iWpnEnt))
		return

	SetHookChainArg(2, ATYPE_STRING, g_v_szWeaponModel)
	SetHookChainArg(3, ATYPE_STRING, g_p_szWeaponModel)
	SetHookChainArg(5, ATYPE_STRING, WEAPON_ANIMEXT)
}

public fw_Weapon_PrimaryAttack(const iWpnEnt)
{
	if (!FIsCustomWeapon(iWpnEnt))
		return

	g_bTraceLine = true
}

public fw_Weapon_PrimaryAttack_Post(const iWpnEnt)
{
	if (!FIsCustomWeapon(iWpnEnt))
		return

	g_bTraceLine = false
}

public fw_TraceLine_Post(const Float:vStart[3], const Float:vEnd[3], iFlags, pevAttacker, pTraceHandle)
{
	if (!g_bTraceLine || iFlags & IGNORE_MONSTERS)
		return

	static Float:vPoint[3]
	get_tr2(pTraceHandle, TR_vecEndPos, vPoint)

	// Small Beam.
	message_begin_f(MSG_PVS, SVC_TEMPENTITY, vPoint)
	write_byte(TE_BEAMENTPOINT) // TE id.
	write_short(pevAttacker | 0x1000) // Entity ID.
	write_coord_f(vPoint[0]) // End Position X.
	write_coord_f(vPoint[1]) // End Position Y.
	write_coord_f(vPoint[2]) // End Position Z.
	write_short(g_iBeamSpr) // Sprite index.
	write_byte(0) // Frame.
	write_byte(0) // Frame rate.
	write_byte(1) // Duration.
	write_byte(5) // Width.
	write_byte(0) // Noise amplitude.
	write_byte(255) // Red.
	write_byte(200) // Green.
	write_byte(0) // Blue.
	write_byte(255) // Brightness.
	write_byte(-75) // Scroll Speed.
	message_end()

	vPoint = NULL_VECTOR  // {0, 0, 0}
}

public fw_Weapon_AddToPlayer_Post(const iWpnEnt, const clientIndex)
{
	if (!FIsCustomWeapon(iWpnEnt))
		return

	set_member(iWpnEnt, m_Weapon_flBaseDamage, g_flBaseDamage)
	rg_set_iteminfo(iWpnEnt, ItemInfo_iMaxClip, g_iClipSize)
}