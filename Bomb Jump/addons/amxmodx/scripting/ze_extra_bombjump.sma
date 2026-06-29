#include <amxmodx>
#include <fakemeta>
#include <engine>
#include <reapi>
#include <xs>
#include <ze_core>
#define LIBRARY_NEMESIS "ze_class_nemesis"

// Define.
#define AID_SMOKEGRENADE 13

// Zombie Escape - Item info:
stock const ZE_ITEM_NAME[] = "Bomb Jump"
stock const ZE_ITEM_COST = 10
stock const ZE_ITEM_LIMIT = 2

// Grenade Info:
new const GRENADE_NAME[] = "weapon_bombjump_lz"
new const GRENADE_REFERENCE[] = "weapon_smokegrenade"
const WeaponIdType:GRENADE_ID = WEAPON_SMOKEGRENADE
const GRENADE_UID = 7777

// Grenade models.
new g_v_szBombJumpModel[MAX_RESOURCE_PATH_LENGTH] = "models/zm_es/v_bombjump_lz.mdl"
new g_p_szBombJumpModel[MAX_RESOURCE_PATH_LENGTH] = "models/zm_es/p_bombjump_lz.mdl"
new g_w_szBombJumpModel[MAX_RESOURCE_PATH_LENGTH] = "models/zm_es/w_bombjump_lz.mdl"

// Grenade sounds.
new const g_szBombExploSound[] = "weapons/CSO/zombi_bomb_exp.wav"
new const g_szModelSounds[][] =
{
	"sound/weapons/CSO/zombi_bomb_deploy.wav",
	"sound/weapons/CSO/zombi_bomb_exp.wav",
	"sound/weapons/CSO/zombi_bomb_idle_1.wav",
	"sound/weapons/CSO/zombi_bomb_idle_2.wav",
	"sound/weapons/CSO/zombi_bomb_idle_3.wav",
	"sound/weapons/CSO/zombi_bomb_idle_4.wav",
	"sound/weapons/CSO/zombi_bomb_pull_1.wav",
	"sound/weapons/CSO/zombi_bomb_throw.wav"
}

// CVars.
new bool:g_bGiveGrenade,
	Float:g_flExploForce,
	Float:g_flExploRadius

// Variables.
new g_iItemID,
	g_iTrailSpr,
	g_iExploSpr,
	g_msgAmmoPickup,
	g_msgWeaponList,
	g_msgStatusIcon

public plugin_natives()
{
	set_module_filter("fw_module_filter")
	set_native_filter("fw_native_filter")
}

public fw_module_filter(const module[], LibType:libtype)
{
	if (equal(module, LIBRARY_NEMESIS))
		return PLUGIN_HANDLED
	return PLUGIN_CONTINUE
}

public fw_native_filter(const name[], index, trap)
{
	if (!trap)
		return PLUGIN_HANDLED
	return PLUGIN_CONTINUE
}

public plugin_precache()
{
	// Read grenade models from INI file.
	if (!ini_read_string(ZE_FILENAME, "Weapon Models", "V_BOMBJUMP", g_v_szBombJumpModel, charsmax(g_v_szBombJumpModel)))
		ini_write_string(ZE_FILENAME, "Weapon Models", "V_BOMBJUMP", g_v_szBombJumpModel)
	if (!ini_read_string(ZE_FILENAME, "Weapon Models", "P_BOMBJUMP", g_p_szBombJumpModel, charsmax(g_p_szBombJumpModel)))
		ini_write_string(ZE_FILENAME, "Weapon Models", "P_BOMBJUMP", g_p_szBombJumpModel)
	if (!ini_read_string(ZE_FILENAME, "Weapon Models", "W_BOMBJUMP", g_w_szBombJumpModel, charsmax(g_w_szBombJumpModel)))
		ini_write_string(ZE_FILENAME, "Weapon Models", "W_BOMBJUMP", g_w_szBombJumpModel)

	new const szTrailSprite[] = "sprites/laserbeam.spr"
	new const szBombExploSprite[] = "sprites/CSO/zombi_bomb_exp.spr"
	new const szWeaponListGeneric[][] = {"sprites/weapon_bombjump_lz.txt", "sprites/640hudc1.spr"}

	// Pre-load models.
	precache_model(g_v_szBombJumpModel)
	precache_model(g_p_szBombJumpModel)
	precache_model(g_w_szBombJumpModel)
	g_iTrailSpr = precache_model(szTrailSprite)
	g_iExploSpr = precache_model(szBombExploSprite)

	// Pre-load sound.
	precache_sound(g_szBombExploSound)

	// Pre-load more files.
	new i
	for (i = 0; i < sizeof(g_szModelSounds); i++)
		precache_generic(g_szModelSounds[i])
	for (i = 0; i < sizeof(szWeaponListGeneric); i++)
		precache_generic(szWeaponListGeneric[i])
}

public plugin_init()
{
	// Load Plug-In.
	register_plugin("[ZE] Extra Item: Knockback Bomb", ZE_VERSION, ZE_AUTHORS)

	// Hook Chains.
	RegisterHookChain(RG_ThrowSmokeGrenade, "fw_GrenadeThrown_Post", 1)
	RegisterHookChain(RG_CBasePlayer_AddPlayerItem, "fw_AddPlayerItem_Post", 1)
	RegisterHookChain(RG_CBasePlayer_RemovePlayerItem, "fw_RemovePlayerItem_Post", 1)

	// CVars.
	bind_pcvar_num(register_cvar("ze_bombjump_give", "1"), g_bGiveGrenade)
	bind_pcvar_float(register_cvar("ze_bombjump_force", "200.0"), g_flExploForce)
	bind_pcvar_float(register_cvar("ze_bombjump_radius", "400.0"), g_flExploRadius)

	// Commands.
	register_clcmd(GRENADE_NAME, "cmd_ChooseWeapon")

	// New Item's.
	g_iItemID = ze_item_register(ZE_ITEM_NAME, ZE_ITEM_COST, ZE_ITEM_LIMIT)

	// Initial Value.
	g_msgAmmoPickup = get_user_msgid("AmmoPickup")
	g_msgWeaponList = get_user_msgid("WeaponList")
	g_msgStatusIcon = get_user_msgid("StatusIcon")
}

public ze_select_item_pre(id, iItem, bool:bIgnoreCost, bool:bInMenu)
{
	// This is not our Item!
	if (iItem != g_iItemID)
		return ZE_ITEM_AVAILABLE

	// Item not allowed for Nemesis class!
	if (module_exists(LIBRARY_NEMESIS) && ze_is_user_nemesis(id))
		return ZE_ITEM_DONT_SHOW

	if (ze_is_user_zombie(id))
		return ZE_ITEM_AVAILABLE

	return ZE_ITEM_DONT_SHOW
}

public ze_select_item_post(id, iItem, bool:bIgnoreCost)
{
	if (iItem != g_iItemID)
		return

	new iBpAmmo
	if (!(iBpAmmo = rg_get_user_bpammo(id, GRENADE_ID)))
	{
		give_BombJump(id)
	}
	else
	{
		rg_set_user_bpammo(id, GRENADE_ID, iBpAmmo + 1)

		message_begin(MSG_ONE_UNRELIABLE, g_msgAmmoPickup, _, id)
		write_byte(AID_SMOKEGRENADE) // Ammo ID.
		write_byte(1) // Amount.
		message_end()
	}
}

public ze_user_humanized(id)
{
	StatusIcon(id, 0)
	WeaponList(id, 0)
}

public ze_user_infected(iVictim, iInfector)
{
	if (!g_bGiveGrenade)
		return

	if (module_exists(LIBRARY_NEMESIS) && ze_is_user_nemesis(iVictim))
		return

	give_BombJump(iVictim)
}

public ze_user_killed_post(iVictim, iAttacker)
{
	StatusIcon(iVictim, 0)
	WeaponList(iVictim, 0)
}

public give_BombJump(id)
{
	WeaponList(id, 1)
	rg_give_item(id, GRENADE_REFERENCE, GT_APPEND)
	engclient_cmd(id, "weapon_knife")

	ze_set_user_view_model(id, CSW_SMOKEGRENADE, g_v_szBombJumpModel)
	ze_set_user_weap_model(id, CSW_SMOKEGRENADE, g_p_szBombJumpModel)
}

public cmd_ChooseWeapon(id)
{
	engclient_cmd(id, GRENADE_REFERENCE)
	return PLUGIN_HANDLED
}

public fw_GrenadeThrown_Post(id)
{
	if (!ze_is_user_zombie(id))
		return

	new const iEnt = GetHookChainReturn(ATYPE_INTEGER)

	set_entvar(iEnt, var_impulse, GRENADE_UID)
	entity_set_model(iEnt, g_w_szBombJumpModel)
	set_ent_rendering(iEnt, kRenderFxGlowShell, 200, 100, 0, kRenderNormal, 10)

	message_begin_f(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMFOLLOW) // TE id.
	write_short(iEnt) // Entity index.
	write_short(g_iTrailSpr) // Sprite index.
	write_byte(5) // Life time.
	write_byte(5) // Line width.
	write_byte(200) // Red.
	write_byte(100) // Green.
	write_byte(0) // Blue.
	write_byte(200) // Brightness.
	message_end()

	SetThink(iEnt, "fw_GrenadeThink_Pre")

	// Think immediately.
	dllfunc(DLLFunc_Think, iEnt)
}

public fw_GrenadeThink_Pre(iEnt)
{
	if (is_nullent(iEnt))
		return HC_CONTINUE

	static pevOwner; pevOwner = get_entvar(iEnt, var_owner)
	if (!ze_is_user_zombie(pevOwner))
	{
		SetThink(iEnt, "")
		rg_remove_entity(iEnt)
		return HC_SUPERCEDE
	}

	static Float:flHlTime; flHlTime = get_gametime()
	if (get_entvar(iEnt, var_dmgtime) <= flHlTime)
	{
		knockback_Explode(iEnt, pevOwner)
		return HC_SUPERCEDE
	}

	// Think again.
	set_entvar(iEnt, var_nextthink, flHlTime + 0.1)
	return HC_CONTINUE
}

public knockback_Explode(iEnt, pevOwner)
{
	new Float:vOrigin[3], Float:vVicOrigin[3], Float:vSpeed[3], Float:flPushSpeed, Float:flDist
	get_entvar(iEnt, var_origin, vOrigin)

	new pevEnemy = NULLENT  // Search on enemies in field of explosion.
	while ((pevEnemy = find_ent_in_sphere(pevEnemy, vOrigin, g_flExploRadius)))
	{
		if (!is_user_alive(pevEnemy))
			continue

		get_entvar(pevEnemy, var_origin, vVicOrigin)
		flDist = vector_distance(vOrigin, vVicOrigin)

		// New velocity.
		xs_vec_sub(vVicOrigin, vOrigin, vSpeed)
		xs_vec_normalize(vSpeed, vSpeed)
		flPushSpeed = g_flExploForce * (1.0 - (flDist / g_flExploRadius))
		xs_vec_mul_scalar(vSpeed, flPushSpeed, vSpeed)
		set_entvar(pevEnemy, var_velocity, vSpeed)
	}

	message_begin_f(MSG_PVS, SVC_TEMPENTITY, vOrigin)
	write_byte(TE_SPRITE) // TE id.
	write_coord_f(vOrigin[0]) // Position X.
	write_coord_f(vOrigin[1]) // Position Y.
	write_coord_f(vOrigin[2] + 16.0) // Position Z.
	write_short(g_iExploSpr) // Sprite index.
	write_byte(30) // Scale.
	write_byte(255) // Brightness.
	message_end()

	emit_sound(iEnt, CHAN_WEAPON, g_szBombExploSound, VOL_NORM, ATTN_NORM, 0, PITCH_LOW)

	// Free edict.
	SetThink(iEnt, "")
	rg_remove_entity(iEnt)
}

public fw_AddPlayerItem_Post(const id, const pItem)
{
	if (is_nullent(pItem) || !is_user_alive(id))
		return

	if (!ze_is_user_zombie(id))
		return

	if (get_member(pItem, m_iId) == GRENADE_ID)
		StatusIcon(id, 1)
}

public fw_RemovePlayerItem_Post(const id, const pItem)
{
	if (is_nullent(pItem) || !ze_is_user_zombie(id))
		return

	if (get_member(pItem, m_iId) == GRENADE_ID && !rg_get_user_bpammo(id, GRENADE_ID))
		StatusIcon(id, 0)
}

/**
 * -=| Function |=-
 */
StatusIcon(id, iMode = 0)
{
	message_begin(MSG_ONE, g_msgStatusIcon, .player = id)
	write_byte(iMode) // 0 = Hide | 1 = Show | 2 = Flash
	write_string("dmg_gas") // Icon Name
	write_byte(255) // Red
	write_byte(165) // Green
	write_byte(0) // Blue
	message_end()
}

WeaponList(id, iMode = 0)
{
	static const ammo_smokegrenade = 13

	message_begin(MSG_ONE, g_msgWeaponList, .player = id)
	write_string(iMode ? GRENADE_NAME : GRENADE_REFERENCE) // Weapon Name.
	write_byte(ammo_smokegrenade) // Primary Ammo ID.
	write_byte(1) // Primary Ammo Max Amount
	write_byte(NULLENT) // Secondary Ammo ID
	write_byte(NULLENT) // Secondary Ammo Max Amount
	write_byte(3) // Slot ID
	write_byte(3) // Number in Slot
	write_byte(CSW_SMOKEGRENADE) // Weapon ID
	write_byte(ITEM_FLAG_LIMITINWORLD|ITEM_FLAG_EXHAUSTIBLE) // Flags
	message_end()
}