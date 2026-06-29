#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <reapi>
#include <ze_core>

// Macroses.
#define is_CustomWeapon(%0) (get_entvar(%0,var_impulse)==WEAPON_UID)

// Weapon Informations.
new const WEAPON_REFERENCE[] = "weapon_mp5navy"
new const WEAPON_ID = CSW_MP5NAVY
new const WEAPON_UID = 247411
new const WEAPON_DEFAULTAMMO = 120

// Zombie Escape: Item
stock const ZE_ITEM_NAME[] = "MP5 Navy Golden"
stock const ZE_ITEM_COST = 30
stock const ZE_ITEM_LIMIT = 0

// Weapon Models.
new g_v_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/v_mp5.mdl"
new g_p_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/p_mp5.mdl"
new g_w_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/w_mp5.mdl"

// CVars.
new Float:g_flBaseDamage

// Variables.
new g_iItemID,
	g_iBeamSpr

public plugin_precache()
{
	// Read Weapon Models from INI file.
	if (!ini_read_string(ZE_ET_FILENAME, ZE_ITEM_NAME, "VIEW_MODEL", g_v_szWeaponModel, charsmax(g_v_szWeaponModel)))
		ini_write_string(ZE_ET_FILENAME, ZE_ITEM_NAME, "VIEW_MODEL", g_v_szWeaponModel)
	if (!ini_read_string(ZE_ET_FILENAME, ZE_ITEM_NAME, "WEAPON_MODEL", g_p_szWeaponModel, charsmax(g_p_szWeaponModel)))
		ini_write_string(ZE_ET_FILENAME, ZE_ITEM_NAME, "WEAPON_MODEL", g_p_szWeaponModel)
	if (!ini_read_string(ZE_ET_FILENAME, ZE_ITEM_NAME, "WORLD_MODEL", g_w_szWeaponModel, charsmax(g_w_szWeaponModel)))
		ini_write_string(ZE_ET_FILENAME, ZE_ITEM_NAME, "WORLD_MODEL", g_w_szWeaponModel)

	// Pre-Load Models.
	precache_model(g_p_szWeaponModel)
	precache_model(g_v_szWeaponModel)
	precache_model(g_w_szWeaponModel)

	new const szBeamSprite[] = "sprites/zbeam2.spr"

	// Pre-Load Sprite.
	g_iBeamSpr = precache_model(szBeamSprite)
}

public plugin_init()
{
	// Load Plug-In.
	register_plugin("[ZE] Extra Item: MP5 Golden", "1.0", "z0h1r-LK")

	// Hams.
	RegisterHam(Ham_Item_AddToPlayer, WEAPON_REFERENCE, "fw_Weapon_AddToPlayer")
	RegisterHam(Ham_Weapon_PrimaryAttack, WEAPON_REFERENCE, "fw_Weapon_PrimaryAttack")
	RegisterHam(Ham_Weapon_PrimaryAttack, WEAPON_REFERENCE, "fw_Weapon_PrimaryAttack_Post", 1)

	// Hook Chains.
	RegisterHookChain(RG_CWeaponBox_SetModel, "fw_WeaponBox_SetModel")
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "fw_Weapon_DefaultDeploy")

	// FakeMeta.
	register_forward(FM_TraceLine, "fw_TraceLine_Post", 1)

	// CVars.
	bind_pcvar_float(register_cvar("ze_mp5g_damage", "62.0"), g_flBaseDamage)

	// Commands.
	register_clcmd("say /mp5g", "cmd_GiveMP5Golden")
	register_clcmd("say_team /mp5g", "cmd_GiveMP5Golden")

	// New Item's.
	g_iItemID = ze_register_item(ZE_ITEM_NAME, ZE_ITEM_COST, ZE_ITEM_LIMIT)
}

public cmd_GiveMP5Golden(id)
{
	if (!is_user_alive(id) || !(get_user_flags(id) & ADMIN_RCON))
		return

	give_Weapon(id)
}

public give_Weapon(id)
{
	if (rg_give_custom_item(id, WEAPON_REFERENCE, GT_DROP_AND_REPLACE, WEAPON_UID) == NULLENT)
		return

	rg_set_user_bpammo(id, WeaponIdType:WEAPON_ID, WEAPON_DEFAULTAMMO)
}

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

	give_Weapon(id)
}

public fw_Weapon_AddToPlayer(pItem, iPlayer)
{
	if (is_nullent(pItem) || !is_CustomWeapon(pItem))
		return

	set_member(pItem, m_Weapon_flBaseDamage, g_flBaseDamage)
	rg_set_iteminfo(pItem, ItemInfo_iMaxAmmo1, WEAPON_DEFAULTAMMO)
}

public fw_Weapon_PrimaryAttack(pItem)
{
	if (is_nullent(pItem) || !is_CustomWeapon(pItem))
		return HC_CONTINUE

	state FireBullets: Enabled
	return HC_CONTINUE
}

public fw_Weapon_PrimaryAttack_Post(pItem)
{
	if (is_nullent(pItem) || !is_CustomWeapon(pItem))
		return

	state FireBullets: Disabled
}

public fw_TraceLine_Post(const Float:vStart[3], const Float:vEnd[3], bitsFlags, pevAttacker, pTraceHandle) <FireBullets: Enabled>
{
	if (bitsFlags & IGNORE_MONSTERS)
		return FMRES_IGNORED

	static Float:vPoint[3]
	get_tr2(pTraceHandle, TR_vecEndPos, vPoint)

	// Beam Sprite.
	message_begin_f(MSG_PVS, SVC_TEMPENTITY, vPoint)
	write_byte(TE_BEAMENTPOINT) // TE id.
	write_short(pevAttacker | 0x1000) // Entity ID | Attachment ID.
	write_coord_f(vPoint[0]) // Position X.
	write_coord_f(vPoint[1]) // Position Y.
	write_coord_f(vPoint[2]) // Position Z.
	write_short(g_iBeamSpr) // Sprite index.
	write_byte(0) // Frame.
	write_byte(0) // Framerate.
	write_byte(1) // Duration.
	write_byte(6) // Width.
	write_byte(0) // Noise amplitude.
	write_byte(255) // Red.
	write_byte(201) // Green.
	write_byte(14) // Blue.
	write_byte(127) // Brightness.
	write_byte(-75) // Scroll Speed.
	message_end()
	return FMRES_IGNORED
}

public fw_TraceLine_Post() <FireBullets: Disabled>
	return FMRES_IGNORED

public fw_TraceLine_Post() <>
	return FMRES_IGNORED

public fw_WeaponBox_SetModel(iEnt, const szModel[])
{
	if (is_nullent(iEnt))
		return HC_CONTINUE

	if (is_CustomWeapon(get_member(iEnt, m_WeaponBox_rgpPlayerItems, PRIMARY_WEAPON_SLOT)))
		SetHookChainArg(2, ATYPE_STRING, g_w_szWeaponModel)
	return HC_CONTINUE
}

public fw_Weapon_DefaultDeploy(pItem, const szViewModel[], const szWeaponModel[], iAnim, const szAnimExt[], skiplocal)
{
	if (is_nullent(pItem) || !is_CustomWeapon(pItem))
		return HC_CONTINUE

	SetHookChainArg(2, ATYPE_STRING, g_v_szWeaponModel)
	SetHookChainArg(3, ATYPE_STRING, g_p_szWeaponModel)
	return HC_CONTINUE
}