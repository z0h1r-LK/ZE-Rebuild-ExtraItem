#include <amxmodx>
#include <hamsandwich>
#include <engine>
#include <reapi>

#include <ze_core>

// Defines.
#define INFECT_RADIUS 240.0
#define INFECT_RING_PERIOD 1
#define INFECT_RING_AXIS_X 240
#define INFECT_RING_AXIS_Y 240
#define INFECT_RING_AXIS_Z 2400

#define INFECT_COLOR_RED   255
#define INFECT_COLOR_GREEN 127
#define INFECT_COLOR_BLUE  100

#define GRENADE_ID 6444

// Zombie Escape: Item Info
stock const ZE_ITEM_NAME[] = "Infection Bomb"
stock const ZE_ITEM_COST = 60
stock const ZE_ITEM_LEVEL = 0
stock const ZE_ITEM_LIMIT = 0
stock const ZE_ITEM_GLIMIT = 1 // Global Limit.

// Infection Bomb Models.
new g_v_szInfectNadeModel[MAX_RESOURCE_PATH_LENGTH] = "models/v_smokegrenade.mdl"
new g_p_szInfectNadeModel[MAX_RESOURCE_PATH_LENGTH] = "models/p_smokegrenade.mdl"
new g_w_szInfectNadeModel[MAX_RESOURCE_PATH_LENGTH] = "models/w_smokegrenade.mdl"

// Bomb explode sound.
new g_szInfectExplodeSound[MAX_RESOURCE_PATH_LENGTH] = "zm_es/infect_nade_explode.wav"

// Variables.
new g_iItemID,
	g_iRingSpr,
	g_iTrailSpr,
	g_iDeathMsg,
	g_iAPickupMsg,
	g_bitsHasBomb

// ConVars.
new bool:g_bLastHumanDied

public plugin_precache()
{
	new szRingSprite[MAX_RESOURCE_PATH_LENGTH] = "sprites/shockwave.spr"
	new szTrailSprite[MAX_RESOURCE_PATH_LENGTH] = "sprites/laserbeam.spr"

	// Read Infect Nade models from INI file.
	if (!ini_read_string(ZE_FILENAME, "Weapon Models", "V_INFECTNADE", g_v_szInfectNadeModel, charsmax(g_v_szInfectNadeModel)))
		ini_write_string(ZE_FILENAME, "Weapon Models", "V_INFECTNADE", g_v_szInfectNadeModel)
	if (!ini_read_string(ZE_FILENAME, "Weapon Models", "P_INFECTNADE", g_p_szInfectNadeModel, charsmax(g_p_szInfectNadeModel)))
		ini_write_string(ZE_FILENAME, "Weapon Models", "P_INFECTNADE", g_p_szInfectNadeModel)
	if (!ini_read_string(ZE_FILENAME, "Weapon Models", "W_INFECTNADE", g_w_szInfectNadeModel, charsmax(g_w_szInfectNadeModel)))
		ini_write_string(ZE_FILENAME, "Weapon Models", "W_INFECTNADE", g_w_szInfectNadeModel)

	// Read Infect Nade resources from INI file.
	if (!ini_read_string(ZE_FILENAME, "Grenades Effects", "INFECT_RING", szRingSprite, charsmax(szRingSprite)))
		ini_write_string(ZE_FILENAME, "Grenades Effects", "INFECT_RING", szRingSprite)
	if (!ini_read_string(ZE_FILENAME, "Grenades Effects", "INFECT_TRAIL", szTrailSprite, charsmax(szTrailSprite)))
		ini_write_string(ZE_FILENAME, "Grenades Effects", "INFECT_TRAIL", szTrailSprite)

	// Read Infect explode sounds from INI file.
	if (!ini_read_string(ZE_FILENAME, "Sounds", "INFECT_EXPLODE", g_szInfectExplodeSound, charsmax(g_szInfectExplodeSound)))
		ini_write_string(ZE_FILENAME, "Sounds", "INFECT_EXPLODE", g_szInfectExplodeSound)

	// Pre-load Models.
	precache_model(g_v_szInfectNadeModel)
	precache_model(g_p_szInfectNadeModel)
	precache_model(g_w_szInfectNadeModel)
	g_iRingSpr = precache_model(szRingSprite)
	g_iTrailSpr = precache_model(szTrailSprite)

	// Pre-load Sound.
	precache_sound(g_szInfectExplodeSound)
}

public plugin_init()
{
	// Load Plug-In.
	register_plugin("[ZE] Extra Item: Infection Bomb", "1.0r1", "z0h1r-LK")

	// Hook Chains.
	RegisterHookChain(RG_ThrowHeGrenade, "fw_GrenadeThrown_Post", 1)
	RegisterHookChain(RG_CGrenade_ExplodeHeGrenade, "fw_GrenadeExploded_Pre")
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "fw_Grenade_DefaultDeploy_Pre")

	// Cvars.
	new const pCvarLastDie = get_cvar_pointer("ze_lasthuman_die")
	if (pCvarLastDie > 0)
		bind_pcvar_num(pCvarLastDie, g_bLastHumanDied)

	// New Item.
	g_iItemID = ze_item_register_ex(ZE_ITEM_NAME, ZE_ITEM_COST, ZE_ITEM_LIMIT, ZE_ITEM_LEVEL, ZE_ITEM_GLIMIT)

	// Initial Values.
	g_iDeathMsg = get_user_msgid("DeathMsg")
	g_iAPickupMsg = get_user_msgid("AmmoPickup")
}

public client_disconnected(id, bool:drop, message[], maxlen)
{
	if (is_user_hltv(id))
		return

	flag_unset(g_bitsHasBomb, id)
}

public ze_game_started()
{
	g_bitsHasBomb = 0
}

public ze_user_humanized(id)
	flag_unset(g_bitsHasBomb, id)

public ze_user_killed_post(iVictim, iAttacker, iGibs)
	flag_unset(g_bitsHasBomb, iVictim)

public ze_select_item_pre(id, iItem, bool:bIgnoreCost, bool:bInMenu)
{
	if (iItem != g_iItemID)
		return ZE_ITEM_AVAILABLE

	if (!ze_is_user_zombie(id))
		return ZE_ITEM_DONT_SHOW

	return ZE_ITEM_AVAILABLE
}

public ze_select_item_post(id, iItem, bool:bIgnoreCost)
{
	if (iItem != g_iItemID)
		return

	flag_set(g_bitsHasBomb, id)

	new const iNadeNum = rg_get_user_bpammo(id, WEAPON_HEGRENADE)
	if (!iNadeNum)
	{
		rg_give_item(id, "weapon_hegrenade", GT_APPEND)
	}
	else
	{
		rg_set_user_bpammo(id, WEAPON_HEGRENADE, iNadeNum + 1)

		message_begin(MSG_ONE_UNRELIABLE, g_iAPickupMsg, _, id)
		write_byte(12) // Ammo ID.
		write_byte(1) // Ammo Amount.
		message_end()
	}
}

public fw_Grenade_DefaultDeploy_Pre(iWpnEnt, const szViewModel[], const szWeapModel[], iAnim, const szAnimExt[], skiplocal)
{
	if (is_nullent(iWpnEnt) || get_member(iWpnEnt, m_iId) != WEAPON_HEGRENADE)
		return

	static clientIndex; clientIndex = get_member(iWpnEnt, m_pPlayer)
	if (clientIndex == NULLENT || !ze_is_user_zombie(clientIndex) || !flag_get_boolean(g_bitsHasBomb, clientIndex))
		return

	if (g_v_szInfectNadeModel[0] != EOS)
		SetHookChainArg(2, ATYPE_STRING, g_v_szInfectNadeModel)

	if (g_p_szInfectNadeModel[0] != EOS)
		SetHookChainArg(3, ATYPE_STRING, g_p_szInfectNadeModel)
}

public fw_GrenadeThrown_Post(const id)
{
	if (!is_user_connected(id) || !ze_is_user_zombie(id) || !flag_get_boolean(g_bitsHasBomb, id))
		return

	// Get grenade entity.
	new const iEnt = GetHookChainReturn(ATYPE_INTEGER)
	if (is_nullent(iEnt))
		return

	// Set entity World Model.
	entity_set_model(iEnt, g_w_szInfectNadeModel)

	// Set entity unique id.
	set_entvar(iEnt, var_impulse, GRENADE_ID)

	// Set entity Glow Shell.
	set_ent_rendering(iEnt, kRenderFxGlowShell, INFECT_COLOR_RED, INFECT_COLOR_GREEN, INFECT_COLOR_BLUE, kRenderNormal, 10)

	// Grenade Trail.
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMFOLLOW) // TE id.
	write_short(iEnt) // Entity ID.
	write_short(g_iTrailSpr) // Sprite Index.
	write_byte(5) // Duration.
	write_byte(5) // Width.
	write_byte(INFECT_COLOR_RED) // Red.
	write_byte(INFECT_COLOR_GREEN) // Green.
	write_byte(INFECT_COLOR_BLUE) // Blue.
	write_byte(255) // Brightness.
	message_end()
}

public fw_GrenadeExploded_Pre(const iEnt)
{
	if (is_nullent(iEnt))
		return HC_CONTINUE

	if (get_entvar(iEnt, var_impulse) != GRENADE_ID)
		return HC_CONTINUE

	bomb_Explode(iEnt)

	// Remove entity.
	rg_remove_entity(iEnt)
	return HC_SUPERCEDE // Prevent property of Grenade.
}

public bomb_Explode(const iEnt)
{
	new Float:vOrigin[3]
	get_entvar(iEnt, var_origin, vOrigin)

	// Search victims.
	new iPlayers[MAX_PLAYERS]
	new const iAliveNum = find_sphere_class(0, "player", INFECT_RADIUS, iPlayers, MAX_PLAYERS, vOrigin)
	new const iInfector = get_entvar(iEnt, var_owner)

	// Freeze victims.
	for (new iLastHuman, iVictim, i = 0; i < iAliveNum; i++)
	{
		iVictim = iPlayers[i]
		iLastHuman = ze_is_last_human()

		// Is Zombie?
		if (!is_user_alive(iVictim) || ze_is_user_zombie(iVictim))
			continue

		if (g_bLastHumanDied && iLastHuman == iVictim)
		{
			set_msg_block(g_iDeathMsg, BLOCK_ONCE)

			// Kill him.
			ExecuteHamB(Ham_Killed, iVictim, iInfector, GIB_NORMAL)

			// Death message.
			message_begin(MSG_ALL, g_iDeathMsg)
			write_byte(iInfector) // Attacker.
			write_byte(iVictim) // Victim.
			write_byte(0) // 1 = Headshot.
			write_string("grenade") // Weapon Name.
			message_end()
		}
		else // Infect him.
		{
			new const iArmorVal = get_entvar(iVictim, var_armorvalue)

			if (iArmorVal > 0)
			{
				rg_set_user_armor(iVictim, 0, ARMOR_NONE)
			}
			else
			{
				ze_force_set_user_zombie(iVictim, iInfector)

				if (iLastHuman == iVictim)
					ze_round_end(ZE_TEAM_ZOMBIE)
			}
		}
	}

	for (new i = 0; i < 2; i++)  // 2 messges are required to fix shockwave issues.
	{
		// Ring effect.
		message_begin_f(MSG_PVS, SVC_TEMPENTITY, vOrigin)
		write_byte(TE_BEAMCYLINDER) // TE id.
		write_coord_f(vOrigin[0]) // Position X.
		write_coord_f(vOrigin[1]) // Position Y.
		write_coord_f(vOrigin[2] + 64.0) // Position Z.
		write_coord_f(vOrigin[0] + INFECT_RING_AXIS_X) // Axis X.
		write_coord_f(vOrigin[1] + INFECT_RING_AXIS_Y) // Axis Y.
		write_coord_f(vOrigin[2] + INFECT_RING_AXIS_Z) // Axis Z.
		write_short(g_iRingSpr) // Sprite Index.
		write_byte(0) // Frame.
		write_byte(0) // Frame rate.
		write_byte(INFECT_RING_PERIOD) // Duration.
		write_byte(64) // Width.
		write_byte(0) // Noise.
		write_byte(INFECT_COLOR_RED) // Red.
		write_byte(INFECT_COLOR_GREEN) // Green.
		write_byte(INFECT_COLOR_BLUE) // Blue.
		write_byte(255) // Brightness.
		write_byte(0) // Scroll Speed.
		message_end()
	}

	// Emit explode sound.
	emit_sound(iEnt, CHAN_WEAPON, g_szInfectExplodeSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
}