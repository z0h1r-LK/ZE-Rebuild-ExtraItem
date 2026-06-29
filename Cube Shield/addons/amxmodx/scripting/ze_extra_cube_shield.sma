#include <amxmodx>
#include <fakemeta>
#include <engine>
#include <reapi>
#include <ze_core>
#define LIBRARY_WPNMODELS "ze_weap_models_api"

// Defines.
#define GRENADE_ID 7777

#define GRP_HUMAN    256
#define GRP_ZOMBIE   256 | 128
#define GRP_CUBE     128

// Cube Shield (entity).
new const CUBE_CLASSNAME[] = "cube_shield"
new const CUBE_REFERENCE[] = "info_target"
new const DISP_CLASSNAME[] = "cube_displayer"

// Zombie Escape: Item Info.
stock const ZE_ITEM_NAME[] = "Cube Shield"
stock const ZE_ITEM_COST = 20
stock const ZE_ITEM_LIMIT = 1

// Cube-Nade Models.
new g_v_szCubeModel[MAX_RESOURCE_PATH_LENGTH] = "models/v_smokegrenade.mdl"
new g_p_szCubeModel[MAX_RESOURCE_PATH_LENGTH] = "models/p_smokegrenade.mdl"
new g_w_szCubeModel[MAX_RESOURCE_PATH_LENGTH] = "models/w_smokegrenade.mdl"
new g_s_szCubeModel[MAX_RESOURCE_PATH_LENGTH] = "models/zm_es/cube_shield.mdl"

// CVars.
new Float:g_flDmgTime

// Variables.
new g_iItemID,
	g_iTrailSpr,
	g_iBreakModel,
	g_bitsHasCube

public plugin_natives()
{
	set_module_filter("fw_module_fitler")
	set_module_filter("fw_native_fitler")
}

public fw_module_filter(const module[], LibType:libtype)
{
	if (equal(module, LIBRARY_WPNMODELS))
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
	new szTrailSprite[MAX_RESOURCE_PATH_LENGTH] = "sprites/laserbeam.spr"

	// Read Cube-Nade models from INI file.
	if (!ini_read_string(ZE_FILENAME, "Weapon Models", "V_CUBENADE", g_v_szCubeModel, charsmax(g_v_szCubeModel)))
		ini_write_string(ZE_FILENAME, "Weapon Models", "V_CUBENADE", g_v_szCubeModel)
	if (!ini_read_string(ZE_FILENAME, "Weapon Models", "P_CUBENADE", g_p_szCubeModel, charsmax(g_p_szCubeModel)))
		ini_write_string(ZE_FILENAME, "Weapon Models", "P_CUBENADE", g_p_szCubeModel)
	if (!ini_read_string(ZE_FILENAME, "Weapon Models", "W_CUBENADE", g_w_szCubeModel, charsmax(g_w_szCubeModel)))
		ini_write_string(ZE_FILENAME, "Weapon Models", "W_CUBENADE", g_w_szCubeModel)

	if (!ini_read_string(ZE_FILENAME, "Grenades Effects", "CUBE_TRAIL", szTrailSprite, charsmax(szTrailSprite)))
		ini_write_string(ZE_FILENAME, "Grenades Effects", "CUBE_TRAIL", szTrailSprite)

	if (!ini_read_string(ZE_FILENAME, "MODELS", "CUBE_MODEL", g_s_szCubeModel, charsmax(g_s_szCubeModel)))
		ini_write_string(ZE_FILENAME, "MODELS", "CUBE_MODEL", g_s_szCubeModel)

	new const szGlassModel[] = "models/glassgibs.mdl"

	// Preload models.
	precache_model(g_p_szCubeModel)
	precache_model(g_v_szCubeModel)
	precache_model(g_w_szCubeModel)
	precache_model(g_s_szCubeModel)

	g_iTrailSpr = precache_model(szTrailSprite)
	g_iBreakModel = precache_model(szGlassModel)
}

public plugin_init()
{
	// Load Plug-In.
	register_plugin("[ZE] Extra Item: Cube Shield", "1.1", "z0h1r-LK")

	// Hook Chains.
	RegisterHookChain(RG_ThrowSmokeGrenade, "fw_GrenadeThrown_Post", 1)
	RegisterHookChain(RG_CGrenade_ExplodeSmokeGrenade, "fw_GrenadeExploded_Pre")

	RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "fw_Weapon_DefaultDeploy_Pre")

	// FakeMeta.
	register_forward(FM_ShouldCollide, "fw_ShouldCollide_Pre")

	// Engine.
	register_think(CUBE_CLASSNAME, "fw_Cube_Think")

	// CVars.
	bind_pcvar_float(register_cvar("ze_cube_duration", "15.0"), g_flDmgTime)

	// New Item's.
	g_iItemID = ze_item_register(ZE_ITEM_NAME, ZE_ITEM_COST, ZE_ITEM_LIMIT)
}

public ze_select_item_pre(id, iItem, bool:bIgnoreCost, bool:bInMenu)
{
	if (iItem != g_iItemID)
		return ZE_ITEM_AVAILABLE

	// Don't show this item in Items of Zombies
	if (ze_is_user_zombie(id))
		return ZE_ITEM_DONT_SHOW

	return ZE_ITEM_AVAILABLE
}

public ze_select_item_post(id, iItem, bool:bIgnoreCost)
{
	if (iItem != g_iItemID)
		return

	/**
	 * When I use GT_REPLACE in rg_give_item(), All grenades of the player are disappeared!
	 */
	rg_remove_item(id, "weapon_smokegrenade")

	if (rg_give_item(id, "weapon_smokegrenade", GT_APPEND) == NULLENT)
		log_error(AMX_ERR_GENERAL, "[ZE] Invalid Weapon id (-1)")

	flag_set(g_bitsHasCube, id)
}

public client_disconnected(id, bool:drop, message[], maxlen)
{
	if (is_user_hltv(id))
		return

	flag_unset(g_bitsHasCube, id)
}

public ze_game_started_pre()
{
	new iClients[MAX_PLAYERS], iAliveNum
	get_players(iClients, iAliveNum, "ah")

	for (new iFlags, id, i; i < iAliveNum; i++)
	{
		id = iClients[i]

		iFlags = get_entvar(id, var_groupinfo)
		set_entvar(id, var_groupinfo, iFlags & ~GRP_HUMAN)
		set_entvar(id, var_groupinfo, iFlags & ~GRP_CUBE)
	}
}

public ze_user_humanized(id)
{
	flag_unset(g_bitsHasCube, id)

	if (has_map_ent_class(CUBE_CLASSNAME))
		set_entvar(id, var_groupinfo, get_entvar(id, var_groupinfo) | GRP_HUMAN)
}

public ze_user_infected(iVictim, iInfector)
{
	flag_unset(g_bitsHasCube, iVictim)

	if (has_map_ent_class(CUBE_CLASSNAME))
		set_entvar(iVictim, var_groupinfo, get_entvar(iVictim, var_groupinfo) | GRP_ZOMBIE)
}

public ze_user_killed_post(iVictim, iAttacker, iGibs)
{
	flag_unset(g_bitsHasCube, iVictim)

	new const iFlags = get_entvar(iVictim, var_groupinfo)
	set_entvar(iVictim, var_groupinfo, iFlags & ~GRP_HUMAN)
	set_entvar(iVictim, var_groupinfo, iFlags & ~GRP_CUBE)
}

public fw_Weapon_DefaultDeploy_Pre(pItem, const szViewModel[], const szWeaponModel[], iAnim, const szAnimExt[], skiplocal)
{
	if (is_nullent(pItem))
		return HC_CONTINUE

	if (get_member(pItem, m_iId) != WEAPON_SMOKEGRENADE)
		return HC_CONTINUE

	static pevOwner; pevOwner = get_member(pItem, m_pPlayer)
	if (!flag_get_boolean(g_bitsHasCube, pevOwner))
		return HC_CONTINUE

	if (g_v_szCubeModel[0])
		SetHookChainArg(2, ATYPE_STRING, g_v_szCubeModel)

	if (g_p_szCubeModel[0])
		SetHookChainArg(3, ATYPE_STRING, g_p_szCubeModel)

	return HC_CONTINUE
}

public fw_GrenadeThrown_Post(const id)
{
	if (ze_is_user_zombie(id) || !flag_get_boolean(g_bitsHasCube, id))
		return

	new const iEnt = GetHookChainReturn(ATYPE_INTEGER)

	if (is_nullent(iEnt))
		return

	flag_unset(g_bitsHasCube, id)

	// Set entity World Model.
	entity_set_model(iEnt, g_w_szCubeModel)

	// Set entity unique id.
	set_entvar(iEnt, var_impulse, GRENADE_ID)

	// Set entity Glow Shell.
	set_ent_rendering(iEnt, kRenderFxGlowShell, 0, 128, 255, kRenderNormal, 10)

	// Grenade Trail.
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMFOLLOW) // TE id.
	write_short(iEnt) // Entity ID.
	write_short(g_iTrailSpr) // Sprite Index.
	write_byte(5) // Duration.
	write_byte(5) // Width.
	write_byte(0) // Red.
	write_byte(128) // Green.
	write_byte(255) // Blue.
	write_byte(255) // Brightness.
	message_end()
}

public fw_GrenadeExploded_Pre(const iEnt)
{
	if (is_nullent(iEnt))
		return HC_CONTINUE

	if (get_entvar(iEnt, var_impulse) != GRENADE_ID)
		return HC_CONTINUE

	new const pevOwner = entity_get_edict2(iEnt, EV_ENT_owner)
	if (pevOwner == NULLENT)
		return HC_CONTINUE

	new Float:vOrigin[3]
	get_entvar(iEnt, var_origin, vOrigin)
	create_Cube(vOrigin, pevOwner)

	rg_remove_entity(iEnt)
	return HC_SUPERCEDE  // Prevent property of Grenade.
}

public create_Cube(const Float:vOrigin[3], const pevOwner)
{
	new iEnt
	if (!(iEnt = rg_create_entity(CUBE_REFERENCE)))
		return

	new const Float:flHlTime = get_gametime()
	set_entvar(iEnt, var_classname, CUBE_CLASSNAME)
	set_entvar(iEnt, var_solid, SOLID_BBOX)
	set_entvar(iEnt, var_owner, pevOwner)
	set_entvar(iEnt, var_origin, vOrigin)
	set_entvar(iEnt, var_groupinfo, GRP_CUBE)
	set_entvar(iEnt, var_dmgtime, flHlTime + g_flDmgTime)

	// Set entity Model.
	entity_set_model(iEnt, g_s_szCubeModel)

	new Float:vMins[3], Float:vMaxs[3]
	GetModelBoundingBox(iEnt, vMins, vMaxs)
	entity_set_size(iEnt, vMins, vMaxs)

	set_ent_rendering(iEnt, kRenderFxGlowShell, 0, 128, 255, kRenderNormal, 10)
	SetClientAttrib()

	set_entvar(iEnt, var_iuser3, create_Displayer(vOrigin))

	// Think again (delay before Remove).
	set_entvar(iEnt, var_nextthink, flHlTime)
}

public create_Displayer(const Float:vOrigin[3])
{
	new iEnt
	if (!(iEnt = rg_create_entity(CUBE_REFERENCE)))
		return 0

	new const Float:flHlTime = get_gametime()
	set_entvar(iEnt, var_classname, DISP_CLASSNAME)
	set_entvar(iEnt, var_solid, SOLID_NOT)
	set_entvar(iEnt, var_movetype, MOVETYPE_NONE)
	set_entvar(iEnt, var_origin, vOrigin)
	set_entvar(iEnt, var_dmgtime, flHlTime + g_flDmgTime)
	set_entvar(iEnt, var_iuser4, 3333)
	set_entvar(iEnt, var_groupinfo, 0)

	// Set entity Model.
	entity_set_model(iEnt, g_s_szCubeModel)
	set_ent_rendering(iEnt, kRenderFxGlowShell, 0, 128, 255, kRenderNormal, 10)
	set_entvar(iEnt, var_nextthink, flHlTime)
	return iEnt
}

public fw_Cube_Think(const iEnt)
{
	if (is_nullent(iEnt))
		return

	static Float:flHlTime; flHlTime = get_gametime()
	if (get_entvar(iEnt, var_dmgtime) <= flHlTime)
	{
		FX_BreakModel(iEnt)
		return
	}

	static pevOwner; pevOwner = entity_get_edict2(iEnt, EV_ENT_owner)
	if (pevOwner == NULLENT || ze_is_user_zombie(pevOwner))
	{
		FX_BreakModel(iEnt)
		return
	}

	// Think again.
	set_entvar(iEnt, var_nextthink, flHlTime + 0.1)
}

public SetClientAttrib()
{
	new iClients[MAX_PLAYERS], iAliveNum
	get_players(iClients, iAliveNum, "ah")

	for (new iFlags, id, i; i < iAliveNum; i++)
	{
		id = iClients[i]
		iFlags = get_entvar(id, var_groupinfo)

		if (ze_is_user_zombie(id))
			set_entvar(id, var_groupinfo, iFlags | GRP_ZOMBIE)
		else
			set_entvar(id, var_groupinfo, iFlags | GRP_HUMAN)
	}
}

public UnsetClientAttrib()
{
	new iClients[MAX_PLAYERS], iAliveNum
	get_players(iClients, iAliveNum, "ah")

	for (new iFlags, id, i; i < iAliveNum; i++)
	{
		id = iClients[i]
		iFlags = get_entvar(id, var_groupinfo)

		if (ze_is_user_zombie(id))
			set_entvar(id, var_groupinfo, iFlags & ~GRP_ZOMBIE)
		else
			set_entvar(id, var_groupinfo, iFlags & ~GRP_HUMAN)
	}
}

/**
 * -=| Function |=-
 */
FX_BreakModel(const iEnt)
{
	new Float:vOrigin[3], Float:vSize[3]
	get_entvar(iEnt, var_origin, vOrigin)
	get_entvar(iEnt, var_size, vSize)

	message_begin_f(MSG_PVS, SVC_TEMPENTITY, vOrigin)
	write_byte(TE_BREAKMODEL) // TE id.
	write_coord_f(vOrigin[0]) // Start Position X.
	write_coord_f(vOrigin[1]) // Start Position Y.
	write_coord_f(vOrigin[2]) // Start Position Z.
	write_coord_f(vSize[0]) // Size X.
	write_coord_f(vSize[1]) // Size Y.
	write_coord_f(vSize[2]) // Size Z.
	write_coord(0) // Velocity X.
	write_coord(0) // Velocity Y.
	write_coord(0) // Velocity Z.
	write_byte(15) // Randomness velocity.
	write_short(g_iBreakModel) // Model index.
	write_byte(255) // Count.
	write_byte(12) // Duration.
	write_byte(BREAK_GLASS) // Flags.
	message_end()

	UnsetClientAttrib()

	// Free edict.
	rg_remove_entity(iEnt)
	rg_remove_entity(get_entvar(iEnt, var_iuser3))
}