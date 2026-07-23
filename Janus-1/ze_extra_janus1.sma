#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <reapi>
#include <xs>
#include <ze_core>

// Zombie Escape: Extra Item
#define ZE_EXTRA_ITEM 1   // Show an item in Extra-Items (1 = Enabled | 0 = Disabled).

// Macroses.
#define is_JanusWeapon(%1) (is_entity(%1) && get_entvar(%1,var_impulse) == WEAPON_UID)

// CWeapon: ItemInfo
#define WEAPON_CLASSNAME    "weapon_janus1_lz"
#define WEAPON_REFERENCE    "weapon_deagle"
#define WEAPON_ANIMEXT      "onehanded"
#define WEAPON_ID           CSW_DEAGLE
#define WEAPON_UID          15272226
#define WEAPON_MAXAMMO      25
#define WEAPON_DAMAGE       85.0
#define WEAPON_RADIUS       200.0
#define WEAPON_HITS         5
#define WEAPON_SP_TIME      7
#define WEAPON_SP_DAMAGE    150.0
#define WEAPON_SP_FIRERATE  0.3

#define GRENADE_CLASSNAME   "jgrenade"
#define GRENADE_REFERENCE   "info_target"
#define GRENADE_FLY_SPEED   1000  // int
#define GRENADE_SIZE_MINS   Float:{-10.0, -5.0, -5.0}
#define GRENADE_SIZE_MAXS   Float:{10.0, 5.0, 5.0}
#define GRENADE_THRESHOLD   100

// Zombie Escape: Item Info.
#define ZE_ITEM_NAME        "Janus-I"
#define ZE_ITEM_COST        25
#define ZE_ITEM_LIMIT       0

// Animations
enum (+=1)
{
	ANIM_IDLE = 0,
	ANIM_DRAW,
	ANIM_SHOOT,
	ANIM_SHOOTT,
	ANIM_SHOOT_S,
	ANIM_CHANGE1,
	ANIM_IDLE2,
	ANIM_DRAW2,
	ANIM_SHOOT2,
	ANIM_SHOOTT2,
	ANIM_CHANGE2,
	ANIM_SIGNAL,
	ANIM_DRAW_S,
	ANIM_SHOOTT_S
}

enum (+=1)
{
	STATE_NONE = 0,
	STATE_SIGNAL,
	STATE_JANUS
}

// Animation Time.
#define ANIMT_IDLE        0.50
#define ANIMT_DRAW        1.03
#define ANIMT_SHOOT       2.83
#define ANIMT_SHOOTT      1.03
#define ANIMT_SHOOT_S     2.83
#define ANIMT_CHANGE1     2.03
#define ANIMT_IDLE2       2.03
#define ANIMT_DRAW2       1.03
#define ANIMT_SHOOT2      1.03
#define ANIMT_CHANGE2     1.70
#define ANIMT_SIGNAL      2.03
#define ANIMT_DRAW_S      1.03
#define ANIMT_SHOOTT_S    1.03

// Weapon resources.
new g_v_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/CSO/v_janus1.mdl"
new g_p_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/CSO/p_janus1.mdl"
new g_w_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/CSO/w_janus1.mdl"
new g_s_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/grenade.mdl"

new const g_szFireSounds[][] = { "weapons/CSO/janus1-1.wav", "weapons/CSO/janus1-2.wav" }

// Variables.
new g_iBeamSpr,
	g_iExploSpr,
	g_iWeaponList

#if ZE_EXTRA_ITEM == 1
new g_iItemId
#endif

// Array.
new g_iHits[MAX_PLAYERS+1],
	g_iState[MAX_PLAYERS+1]

public plugin_precache()
{
	// Read Weapon Models from INI file.
	if (!ini_read_string(ZE_FILENAME, "Weapon Models", "V_JANUS1", g_v_szWeaponModel, charsmax(g_v_szWeaponModel)))
		ini_write_string(ZE_FILENAME, "Weapon Models", "V_JANUS1", g_v_szWeaponModel)
	if (!ini_read_string(ZE_FILENAME, "Weapon Models", "P_JANUS1", g_p_szWeaponModel, charsmax(g_p_szWeaponModel)))
		ini_write_string(ZE_FILENAME, "Weapon Models", "P_JANUS1", g_p_szWeaponModel)
	if (!ini_read_string(ZE_FILENAME, "Weapon Models", "W_JANUS1", g_w_szWeaponModel, charsmax(g_w_szWeaponModel)))
		ini_write_string(ZE_FILENAME, "Weapon Models", "W_JANUS1", g_w_szWeaponModel)
	if (!ini_read_string(ZE_FILENAME, "Weapon Models", "S_JANUS1", g_s_szWeaponModel, charsmax(g_s_szWeaponModel)))
		ini_write_string(ZE_FILENAME, "Weapon Models", "S_JANUS1", g_s_szWeaponModel)

	precache_model(g_v_szWeaponModel)
	precache_model(g_p_szWeaponModel)
	precache_model(g_w_szWeaponModel)
	precache_model(g_s_szWeaponModel)
	g_iBeamSpr = precache_model("sprites/laserbeam.spr")
	g_iExploSpr = precache_model("sprites/fexplo.spr")

	new const szWpnResources[][] =
	{
		"sound/weapons/CSO/janus1_change1.wav",
		"sound/weapons/CSO/janus1_change2.wav",
		"sound/weapons/CSO/janus1_draw.wav",
		"sound/weapons/CSO/janus1_exp.wav",

		"sprites/weapon_janus1_lz.txt",
		"sprites/640hudc7.spr"
	}

	new i
	for (i = 0; i < sizeof(g_szFireSounds); i++)
		precache_sound(g_szFireSounds[i])
	for (i = 0; i < sizeof(szWpnResources); i++)
		precache_generic(szWpnResources[i])
}

public plugin_init()
{
	// Load Plug-In.
	register_plugin("[ZE] Extra-Item: Janus-1", "1.0", "z0h1r-LK")

	// Hook Chains.
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "fw_Weapon_DefaultDeploy_Pre")
	RegisterHookChain(RG_CBasePlayer_RemovePlayerItem, "fw_RemovePlayerItem_Post", 1)
	RegisterHookChain(RG_CWeaponBox_SetModel, "fw_WeaponBox_SetModel_Pre")

	// Hams.
	RegisterHam(Ham_Weapon_WeaponIdle, WEAPON_REFERENCE, "fw_Weapon_WeaponIdle_Pre")
	RegisterHam(Ham_Weapon_PrimaryAttack, WEAPON_REFERENCE, "fw_Weapon_PrimaryAttack_Pre")
	RegisterHam(Ham_Weapon_SecondaryAttack, WEAPON_REFERENCE, "fw_Weapon_SecondaryAttack_Pre")
	RegisterHam(Ham_Item_AttachToPlayer, WEAPON_REFERENCE, "fw_Weapon_AttachToPlayer_Post", 1)

	RegisterHam(Ham_Think, WEAPON_REFERENCE, "fw_Weapon_PreThink")

	// FakeMeta.
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)

	// Commands.
	register_clcmd(WEAPON_CLASSNAME, "cmd_SelectWeapon")

	// Zombie Escape: Extra Item
#if ZE_EXTRA_ITEM == 1
	g_iItemId = ze_item_register(ZE_ITEM_NAME, ZE_ITEM_COST, ZE_ITEM_LIMIT)
#endif

	// Set Values.
	g_iWeaponList = get_user_msgid("WeaponList")
}

public cmd_SelectWeapon(const id)
{
	engclient_cmd(id, WEAPON_REFERENCE)
	return PLUGIN_HANDLED
}

public client_disconnected(id, bool:drop, message[], maxlen)
{
	if (is_user_hltv(id))
		return

	g_iHits[id] = 0
	g_iState[id] = 0
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

	giveJanusWeapon(id)
}
#endif

public giveJanusWeapon(const iPlayer)
{
	new iWpnEnt
	if ((iWpnEnt = rg_give_custom_item(iPlayer, WEAPON_REFERENCE, GT_DROP_AND_REPLACE, WEAPON_UID)) == NULLENT)
	{
		log_error(AMX_ERR_GENERAL, "[ZE] Error while giving weapon to the player (-1)")
		return
	}

	set_member(iWpnEnt, m_Weapon_iClip, NULLENT)
	set_member(iWpnEnt, m_Weapon_iDefaultAmmo, WEAPON_MAXAMMO)
	set_member(iWpnEnt, m_Weapon_bHasSecondaryAttack, true)

	rg_set_iteminfo(iWpnEnt, ItemInfo_iMaxClip, NULLENT)
	rg_set_iteminfo(iWpnEnt, ItemInfo_iMaxAmmo1, WEAPON_MAXAMMO)

	rg_set_user_bpammo(iPlayer, WeaponIdType:WEAPON_ID, WEAPON_MAXAMMO)

	g_iState[iPlayer] = STATE_NONE
	g_iHits[iPlayer] = 0
}

public fw_UpdateClientData_Post(const id, sendweapons, cd_handle)
{
	if (get_cd(cd_handle, CD_DeadFlag) != DEAD_NO)
		return FMRES_IGNORED

	if (is_JanusWeapon(get_member(id, m_pActiveItem)))
	{
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001)
		return FMRES_HANDLED
	}

	return FMRES_IGNORED
}

public fw_Weapon_DefaultDeploy_Pre(const iWpnEnt, const szViewModel[], const szWeaponModel[], iAnim, const szAnimExt[], skiplocal)
{
	if (!is_JanusWeapon(iWpnEnt))
		return

	SetHookChainArg(2, ATYPE_STRING, g_v_szWeaponModel)
	SetHookChainArg(3, ATYPE_STRING, g_p_szWeaponModel)
	SetHookChainArg(5, ATYPE_STRING, WEAPON_ANIMEXT)

	switch (g_iState[get_member(iWpnEnt, m_pPlayer)])
	{
		case STATE_NONE:   SetHookChainArg(4, ATYPE_INTEGER, ANIM_DRAW)
		case STATE_SIGNAL: SetHookChainArg(4, ATYPE_INTEGER, ANIM_DRAW_S)
		case STATE_JANUS:  SetHookChainArg(4, ATYPE_INTEGER, ANIM_DRAW2)
	}
}

public fw_WeaponBox_SetModel_Pre(const iEnt, const szModel[])
{
	if (is_nullent(iEnt))
		return

	if (is_JanusWeapon(get_member(iEnt, m_WeaponBox_rgpPlayerItems, PISTOL_SLOT)))
		SetHookChainArg(2, ATYPE_STRING, g_w_szWeaponModel)
}

public fw_Weapon_WeaponIdle_Pre(const iWpnEnt)
{
	if (!is_JanusWeapon(iWpnEnt))
		return HAM_IGNORED

	if (get_member(iWpnEnt, m_Weapon_flTimeWeaponIdle) > 0.0)
		return HAM_SUPERCEDE

	switch (g_iState[get_member(iWpnEnt, m_pPlayer)])
	{
		case STATE_NONE:
		{
			rg_weapon_send_animation(iWpnEnt, ANIM_IDLE)
			set_member(iWpnEnt, m_Weapon_flTimeWeaponIdle, ANIMT_IDLE)
		}
		case STATE_SIGNAL:
		{
			rg_weapon_send_animation(iWpnEnt, ANIM_SIGNAL)
			set_member(iWpnEnt, m_Weapon_flTimeWeaponIdle, ANIMT_SIGNAL)
		}
		case STATE_JANUS:
		{
			rg_weapon_send_animation(iWpnEnt, ANIM_IDLE2)
			set_member(iWpnEnt, m_Weapon_flTimeWeaponIdle, ANIMT_IDLE2)
		}
	}

	return HAM_SUPERCEDE
}

public fw_Weapon_PrimaryAttack_Pre(const iWpnEnt)
{
	if (!is_JanusWeapon(iWpnEnt))
		return HAM_IGNORED

	static iPlayer; iPlayer = get_member(iWpnEnt, m_pPlayer)
	static iAmount; iAmount = rg_get_user_bpammo(iPlayer, WeaponIdType:WEAPON_ID)

	if (g_iState[iPlayer] != STATE_JANUS)
	{
		if (get_member(iWpnEnt, m_Weapon_iGlock18ShotsFired))
		{
			set_member(iWpnEnt, m_Weapon_flNextPrimaryAttack, 0.2)
			return HAM_SUPERCEDE
		}

		if (iAmount <= 0)
		{
			ExecuteHam(Ham_Weapon_PlayEmptySound, iWpnEnt)
			set_member(iWpnEnt, m_Weapon_flNextPrimaryAttack, 0.2)
			return HAM_SUPERCEDE
		}
	}

	static Float:flHlTime; flHlTime = get_gametime()

	static Float:vOrigin[3]
	ExecuteHam(Ham_Player_GetGunPosition, iPlayer, vOrigin)

	static Float:vSpeed[3]
	velocity_by_aim(iPlayer, GRENADE_FLY_SPEED, vSpeed)

	static Float:flDamage
	switch (g_iState[iPlayer])
	{
		case STATE_JANUS: flDamage = WEAPON_SP_DAMAGE
		case STATE_NONE, STATE_SIGNAL: flDamage = WEAPON_DAMAGE
	}

	// Fire!
	shoot_Grenade(vOrigin, vSpeed, flDamage, iPlayer)

	switch (g_iState[iPlayer])
	{
		case STATE_NONE:
		{
			if (g_iHits[iPlayer] >= WEAPON_HITS)
			{
				g_iState[iPlayer] = STATE_SIGNAL
				g_iHits[iPlayer] = 0
			}
		}
		case STATE_JANUS:
		{
			goto _JanusMode
		}
	}

	// Reload()
	if (iAmount - 1 > 0)
	{
		set_member(iWpnEnt, m_Weapon_iGlock18ShotsFired, 1)
		set_entvar(iWpnEnt, var_nextthink, flHlTime)
	}

	rg_set_user_bpammo(iPlayer, WeaponIdType:WEAPON_ID, iAmount -1)

	switch (g_iState[iPlayer])
	{
		case STATE_NONE:
		{
			if (iAmount - 1 > 0)
			{
				rg_weapon_send_animation(iWpnEnt, ANIM_SHOOT)
				set_member(iWpnEnt, m_Weapon_flNextReload, flHlTime + ANIMT_SHOOT)
				set_member(iWpnEnt, m_Weapon_flTimeWeaponIdle, ANIMT_SHOOT)
				set_member(iWpnEnt, m_Weapon_flNextSecondaryAttack, ANIMT_SHOOT)
			}
			else
			{
				rg_weapon_send_animation(iWpnEnt, ANIM_SHOOTT)
				set_member(iWpnEnt, m_Weapon_flTimeWeaponIdle, ANIMT_SHOOTT)
				set_member(iWpnEnt, m_Weapon_flNextSecondaryAttack, ANIMT_SHOOT)
			}
		}
		case STATE_SIGNAL:
		{
			if (iAmount - 1 > 0)
			{
				rg_weapon_send_animation(iWpnEnt, ANIM_SHOOT_S)
				set_member(iWpnEnt, m_Weapon_flNextReload, flHlTime + ANIMT_SHOOT)
				set_member(iWpnEnt, m_Weapon_flTimeWeaponIdle, ANIMT_SHOOT)
				set_member(iWpnEnt, m_Weapon_flNextSecondaryAttack, ANIMT_SHOOT)
			}
			else
			{
				rg_weapon_send_animation(iWpnEnt, ANIM_SHOOTT_S)
				set_member(iWpnEnt, m_Weapon_flTimeWeaponIdle, ANIMT_SHOOTT_S)
				set_member(iWpnEnt, m_Weapon_flNextSecondaryAttack, ANIMT_SHOOTT_S)
			}
		}
		case STATE_JANUS:
		{
			_JanusMode:
			rg_weapon_send_animation(iWpnEnt, random_num(ANIM_SHOOT2, ANIM_SHOOTT2))
			set_member(iWpnEnt, m_Weapon_flTimeWeaponIdle, ANIMT_SHOOT2)
		}
	}

	rg_set_animation(iPlayer, PLAYER_ATTACK1)
	emit_sound(iPlayer, CHAN_WEAPON, g_szFireSounds[random_num(0, charsmax(g_szFireSounds))], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	set_member(iWpnEnt, m_Weapon_flNextPrimaryAttack, WEAPON_SP_FIRERATE)
	return HAM_SUPERCEDE
}

public fw_Weapon_SecondaryAttack_Pre(const iWpnEnt)
{
	if (!is_JanusWeapon(iWpnEnt))
		return HAM_IGNORED

	static iPlayer; iPlayer = get_member(iWpnEnt, m_pPlayer)
	if (g_iState[iPlayer] == STATE_JANUS)
	{
		set_member(iWpnEnt, m_Weapon_flNextPrimaryAttack, 0.2)
		return HAM_SUPERCEDE
	}

	if (get_member(iWpnEnt, m_Weapon_iGlock18ShotsFired))
	{
		set_member(iWpnEnt, m_Weapon_flNextSecondaryAttack, 0.2)
		return HAM_SUPERCEDE
	}

	if (g_iState[iPlayer] != STATE_SIGNAL)
	{
		ExecuteHam(Ham_Weapon_PlayEmptySound, iWpnEnt)
		set_member(iWpnEnt, m_Weapon_flNextSecondaryAttack, 0.2)
		return HAM_SUPERCEDE
	}

	new const Float:flHlTime = get_gametime()

	g_iState[iPlayer] = STATE_JANUS
	rg_weapon_send_animation(iWpnEnt, ANIM_CHANGE1)

	set_entvar(iWpnEnt, var_fuser4, flHlTime + WEAPON_SP_TIME)
	set_entvar(iWpnEnt, var_nextthink, flHlTime + ANIMT_CHANGE1)

	set_member(iWpnEnt, m_Weapon_flTimeWeaponIdle, ANIMT_CHANGE1)
	set_member(iWpnEnt, m_Weapon_flNextPrimaryAttack, ANIMT_CHANGE1)
	set_member(iWpnEnt, m_Weapon_flNextSecondaryAttack, ANIMT_CHANGE1)
	return HAM_SUPERCEDE
}

public fw_Weapon_PreThink(const iWpnEnt)
{
	if (!is_JanusWeapon(iWpnEnt))
		return

	static iPlayer; iPlayer = get_member(iWpnEnt, m_pPlayer)
	if (!is_user_connected(iPlayer))
		return

	static Float:flHlTime; flHlTime = get_gametime()
	if (g_iState[iPlayer] == STATE_JANUS)
	{
		if (get_entvar(iWpnEnt, var_fuser4) <= flHlTime)
		{
			g_iState[iPlayer] = STATE_NONE
			rg_weapon_send_animation(iPlayer, ANIM_CHANGE2)

			set_member(iWpnEnt, m_Weapon_flTimeWeaponIdle, ANIMT_CHANGE2)
			set_member(iWpnEnt, m_Weapon_flNextPrimaryAttack, ANIMT_CHANGE2)
			set_member(iWpnEnt, m_Weapon_flNextSecondaryAttack, ANIMT_CHANGE2)
			return
		}

		// Th!nk.
		set_entvar(iWpnEnt, var_nextthink, flHlTime + 0.1)
	}
	else
	{
		if (rg_get_user_bpammo(iPlayer, WeaponIdType:WEAPON_ID) <= 0)
		{
			return
		}

		if (get_member(iWpnEnt, m_Weapon_flNextReload) <= flHlTime)
		{
			set_member(iWpnEnt, m_Weapon_iGlock18ShotsFired, 0)
			return  // Reloaded!
		}

		// Th!nk.
		set_entvar(iWpnEnt, var_nextthink, flHlTime + 0.01)
	}
}

public shoot_Grenade(const Float:vSpawn[3], const Float:vSpeed[3], Float:flDamage, iAttacker)
{
	if (global_get(glb_maxEntities) - engfunc(EngFunc_NumberOfEntities) <= GRENADE_THRESHOLD)
		return

	static iEnt
	if (!(iEnt = rg_create_entity(GRENADE_REFERENCE)))
		return

	set_entvar(iEnt, var_classname, GRENADE_CLASSNAME)
	set_entvar(iEnt, var_movetype, MOVETYPE_PUSHSTEP)
	set_entvar(iEnt, var_solid, SOLID_TRIGGER)
	set_entvar(iEnt, var_owner, iAttacker)
	set_entvar(iEnt, var_fuser4, flDamage)
	set_entvar(iEnt, var_iuser1, g_iState[iAttacker])
	set_entvar(iEnt, var_velocity, vSpeed)

	engfunc(EngFunc_SetSize, iEnt, GRENADE_SIZE_MINS, GRENADE_SIZE_MAXS)
	engfunc(EngFunc_SetModel, iEnt, g_s_szWeaponModel)
	engfunc(EngFunc_SetOrigin, iEnt, vSpawn)

	// Think/Touch.
	SetThink(iEnt, "fw_GrenaThink_Pre")
	SetTouch(iEnt, "fw_GrenaTouch_Pre")

	// Small Beam.
	message_begin_f(MSG_PVS, SVC_TEMPENTITY, vSpawn)
	write_byte(TE_BEAMFOLLOW) // TE id.
	write_short(iEnt) // Entity.
	write_short(g_iBeamSpr) // Sprite Index.
	write_byte(5) // Duration.
	write_byte(5) // Width.
	write_byte(100) // Red.
	write_byte(100) // Green.
	write_byte(100) // Blue.
	write_byte(100) // Brightness.
	message_end()

	// Th!nk.
	dllfunc(DLLFunc_Think, iEnt)
}

public fw_GrenaThink_Pre(const iEnt)
{
	if (is_nullent(iEnt))
		return

	static Float:vOrigin[3]
	get_entvar(iEnt, var_origin, vOrigin)

	static Float:vSpeed[3]
	get_entvar(iEnt, var_velocity, vSpeed)
	xs_vec_add(vSpeed, vOrigin, vSpeed)
	xs_vec_sub(vSpeed, vOrigin, vSpeed)
	vector_to_angle(vSpeed, vSpeed)

	set_entvar(iEnt, var_angles, vSpeed)

	// Think!
	set_entvar(iEnt, var_nextthink, get_gametime() + 0.01)
}

public fw_GrenaTouch_Pre(const iEnt, const iOther)
{
	if (is_nullent(iEnt))
		return

	static iAttacker; iAttacker = get_entvar(iEnt, var_owner)
	if (!is_user_connected(iAttacker))
		iAttacker = 0

	// Ignore inflictor owner.
	if (iOther == iAttacker)
		return

	static Float:vOrigin[3]
	get_entvar(iEnt, var_origin, vOrigin)

	static Float:flNewDamage, Float:flDamage, iVictim, bIsHit; flDamage = get_entvar(iEnt, var_fuser4)

	bIsHit = 0
	iVictim = NULLENT

	while ((iVictim = engfunc(EngFunc_FindEntityInSphere, iVictim, vOrigin, WEAPON_RADIUS)))
	{
		if (is_nullent(iVictim))
			continue

		static Float:vVicOrigin[3]
		get_entvar(iVictim, var_origin, vVicOrigin)

		if (ExecuteHam(Ham_IsPlayer, iVictim))
		{
			if (iVictim == iAttacker)  // Owner?
				continue

			if (!is_user_alive(iVictim))
				continue

			if (!ze_is_user_zombie(iVictim))
				continue

			flNewDamage = flDamage * (1.0 - (vector_distance(vOrigin, vVicOrigin) / WEAPON_RADIUS))

			// Damages the victim.
			ExecuteHamB(Ham_TakeDamage, iVictim, iEnt, iAttacker, flNewDamage, DMG_GRENADE)
			bIsHit = 1
		}
		else if (get_entvar(iVictim, var_takedamage) != DAMAGE_NO && get_entvar(iVictim, var_health) > 0.0)
		{
			ExecuteHamB(Ham_TakeDamage, iVictim, iEnt, iAttacker, flDamage, DMG_GENERIC)
			bIsHit = 1
		}
	}

	if (iAttacker)
	{
		if (get_entvar(iEnt, var_iuser1) == STATE_NONE)
		{
			if (bIsHit)
			{
				if (++g_iHits[iAttacker] >= WEAPON_HITS)
				{
					g_iState[iAttacker] = STATE_SIGNAL
					g_iHits[iAttacker] = 0
				}
			}
		}
	}

	// Explosion.
	message_begin_f(MSG_PVS, SVC_TEMPENTITY, vOrigin)
	write_byte(TE_EXPLOSION) // TE id.
	write_coord_f(vOrigin[0]) // Position X.
	write_coord_f(vOrigin[1]) // Position Y.
	write_coord_f(vOrigin[2] + 35.0) // Position Z.
	write_short(g_iExploSpr) // Sprite Index.
	write_byte(20) // Scale.
	write_byte(30) // Framerate.
	write_byte(TE_EXPLFLAG_NONE) // Flags.
	message_end()

	static Float:vTarget[3]
	get_entvar(iEnt, var_angles, vTarget)
	angle_vector(vTarget, ANGLEVECTOR_FORWARD, vTarget)
	xs_vec_mul_scalar(vTarget, 2.0, vTarget)
	xs_vec_add(vOrigin, vTarget, vTarget)

	engfunc(EngFunc_TraceLine, vOrigin, vTarget, DONT_IGNORE_MONSTERS, iEnt, 0)
	get_tr2(0, TR_vecEndPos, vTarget)
	static pHit; pHit = get_tr2(0, TR_pHit)

	message_begin_f(MSG_PVS, SVC_TEMPENTITY, vTarget)
	write_byte(TE_DECAL) // TE id.
	write_coord_f(vTarget[0]) // Position X.
	write_coord_f(vTarget[1]) // Position Y.
	write_coord_f(vTarget[2]) // Position Z.
	write_byte(random_num(46, 48)) // Texture Index.
	write_short(pHit > 0 ? pHit : 0) // Entity Index.
	message_end()

	vTarget = NULL_VECTOR
	vOrigin = NULL_VECTOR

	// Free edict.
	SetThink(iEnt, "")
	SetTouch(iEnt, "")
	rg_remove_entity(iEnt)
}

public fw_Weapon_AttachToPlayer_Post(const iWpnEnt, const iPlayer)
{
	if (!is_JanusWeapon(iWpnEnt))
		return

	WeaponList(iPlayer, 1)

	g_iHits[iPlayer] = get_entvar(iWpnEnt, var_iuser4)
	g_iState[iPlayer] = get_member(iWpnEnt, m_Weapon_iWeaponState)

	if (g_iState[iPlayer] == STATE_JANUS && get_entvar(iWpnEnt, var_fuser4) <= get_gametime())
		g_iState[iPlayer] = STATE_NONE
}

public fw_RemovePlayerItem_Post(const iPlayer, const iWpnEnt)
{
	if (!is_JanusWeapon(iWpnEnt))
		return

	WeaponList(iPlayer, 0)

	set_entvar(iWpnEnt, var_iuser4, g_iHits[iPlayer])
	set_member(iWpnEnt, m_Weapon_iWeaponState, g_iState[iPlayer])
	set_member(iWpnEnt, m_Weapon_iGlock18ShotsFired, 0)

	g_iState[iPlayer] = 0
	g_iHits[iPlayer] = 0
}

WeaponList(const id, bMode = 0)
{
	message_begin(MSG_ONE, g_iWeaponList, _, id)
	write_string(bMode ? WEAPON_CLASSNAME : WEAPON_REFERENCE) // Weapon Name.
	write_byte(8) // Primary Ammo ID.
	write_byte(WEAPON_MAXAMMO) // Primary Ammo Max Amount
	write_byte(NULLENT) // Secondary Ammo ID
	write_byte(NULLENT) // Secondary Ammo Max Amount
	write_byte(1) // Slot ID
	write_byte(1) // Number in Slot
	write_byte(WEAPON_ID) // Weapon ID
	write_byte(0) // Flags
	message_end()
}