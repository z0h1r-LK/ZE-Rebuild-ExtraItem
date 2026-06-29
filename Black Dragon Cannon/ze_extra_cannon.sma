#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <reapi>
#include <xs>
#include <ze_core>

/**
 * This will disable Black Dragon Cannon in Extra-Items (1 = Enabled | 0 = Disabled.
 */
#define ZE_EXTRA_ITEM 1

// Macroses.
#define is_DragonCannon(%0) (is_entity(%0) && get_entvar(%0, var_impulse) == WEAPON_UID)

// Dragon Cannnon: Item Info:
#define WEAPON_NAME       "weapon_cannon_lz"
#define WEAPON_REFERENCE  "weapon_m249"
#define WEAPON_ANIMEXT    "mp5"
#define WEAPON_ID         CSW_M249
#define WEAPON_UID        1245529
#define WEAPON_MAXAMMO    20
#define WEAPON_DAMAGE     220.0
#define WEAPON_PUSH_SPEED 250

#define FLAME_CLASSNAME   "cannon_fire"
#define FLAME_REFERENCE   "info_target"
#define FLAME_SCALE       1.2
#define FLAME_SIZE_MINS   Float:{-16.0, -16.0, -16.0}
#define FLAME_SIZE_MAXS   Float:{16.0, 16.0, 16.0}
#define FLAME_ED_CRITIC   100
#define FLAME_FLYSPEED    850.0
#define FLAME_NEXTDAMAGE  0.1

// Zombie Escape: Item Info.
#if ZE_EXTRA_ITEM == 1
	#define ZE_ITEM_NAME  "Black Dragon Cannon"
	#define ZE_ITEM_COST  60
	#define ZE_ITEM_LIMIT 0
#endif

// Animations.
enum (+=1)
{
	ANIM_IDLE = 0,
	ANIM_SHOOT1,
	ANIM_SHOOT2,
	ANIM_DRAW
}

// Animations Time.
#define ANIMT_IDLE  1.70
#define ANIMT_SHOOT 3.53  // Shoot + Reload
#define ANIMT_DRAW  1.37

// Flame Right Offset
new const Float:g_flRightOffset[] = { -70.0, -55.0, -30.0, 0.0, 30.0, 55.0, 70.0 }

// Dragon Cannon Resources.
new g_v_szWeapModel[MAX_RESOURCE_PATH_LENGTH] = "models/CSO/v_cannon.mdl"
new g_p_szWeapModel[MAX_RESOURCE_PATH_LENGTH] = "models/CSO/p_cannon.mdl"
new g_w_szWeapModel[MAX_RESOURCE_PATH_LENGTH] = "models/CSO/w_cannon.mdl"

new const g_szFlameSprite[] = "sprites/eexplo.spr"

new const g_szWeapFireSound[] = "weapons/CSO/cannon-1.wav"

// Variables.
new g_iPushSpeed,
	g_iWeaponList,
	g_maxSprFrames

#if ZE_EXTRA_ITEM == 1
new g_iItemId
#endif

// Array.
new Float:g_flLastDamage[MAX_PLAYERS+1]

public plugin_precache()
{
	// Read Weapon Models from INI file.
	if (!ini_read_string(ZE_FILENAME, "Weapon Models", "V_DRAGON_CANNON", g_v_szWeapModel, charsmax(g_v_szWeapModel)))
		ini_write_string(ZE_FILENAME, "Weapon Models", "V_DRAGON_CANNON", g_v_szWeapModel)
	if (!ini_read_string(ZE_FILENAME, "Weapon Models", "P_DRAGON_CANNON", g_p_szWeapModel, charsmax(g_p_szWeapModel)))
		ini_write_string(ZE_FILENAME, "Weapon Models", "P_DRAGON_CANNON", g_p_szWeapModel)
	if (!ini_read_string(ZE_FILENAME, "Weapon Models", "W_DRAGON_CANNON", g_w_szWeapModel, charsmax(g_w_szWeapModel)))
		ini_write_string(ZE_FILENAME, "Weapon Models", "W_DRAGON_CANNON", g_w_szWeapModel)

	g_iPushSpeed = WEAPON_PUSH_SPEED

#if ZE_EXTRA_ITEM == 1
	// Item Additional settings.
	if (!ini_read_int(ZE_ET_FILENAME, ZE_ITEM_NAME, "KNOCKBACK_SPEED", g_iPushSpeed))
		ini_write_int(ZE_ET_FILENAME, ZE_ITEM_NAME, "KNOCKBACK_SPEED", g_iPushSpeed)
#endif

	// Pre-load Models.
	precache_model(g_v_szWeapModel)
	precache_model(g_p_szWeapModel)
	precache_model(g_w_szWeapModel)
	g_maxSprFrames = engfunc(EngFunc_ModelFrames, precache_model(g_szFlameSprite))

	// Pre-load Sound.
	precache_sound(g_szWeapFireSound)
	precache_generic("sound/weapons/CSO/cannon_draw.wav")

	precache_generic("sprites/weapon_cannon_lz.txt")
	precache_generic("sprites/640hudc6.spr")
}

public plugin_init()
{
	// Load Plug-In.
	register_plugin("[ZE] Extra Item: Black Dragon Cannon", "1.1", "z0h1r-LK")

	// Hook Chains.
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "fw_Weapon_DefaultDeploy_Pre")
	RegisterHookChain(RG_CBasePlayer_RemovePlayerItem, "fw_RemovePlayerItem_Post", 1)
	RegisterHookChain(RG_CWeaponBox_SetModel, "fw_WeaponBox_SetModel")

	// Hams.
	RegisterHam(Ham_Spawn, WEAPON_REFERENCE, "fw_Weapon_Spawn_Post", 1)
	RegisterHam(Ham_Weapon_WeaponIdle, WEAPON_REFERENCE, "fw_Weapon_WeaponIdle_Pre")
	RegisterHam(Ham_Weapon_PrimaryAttack, WEAPON_REFERENCE, "fw_Weapon_PrimaryAttack_Pre")
	RegisterHam(Ham_Item_AttachToPlayer, WEAPON_REFERENCE, "fw_Weapon_AttachToPlayer_Post", 1)
	RegisterHam(Ham_Think, WEAPON_REFERENCE, "fw_Weapon_PreThink")

	// FakeMeta.
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_forward(FM_ShouldCollide, "fw_ShouldCollide_Pre")

#if ZE_EXTRA_ITEM == 1
	// Zombie Escape: Extra Item.
	g_iItemId = ze_item_register(ZE_ITEM_NAME, ZE_ITEM_COST, ZE_ITEM_LIMIT)
#endif

	// Commands.
	register_clcmd(WEAPON_NAME, "cmd_ChooseWeapon")

	// Set Values.
	g_iWeaponList = get_user_msgid("WeaponList")
}

public cmd_ChooseWeapon(const id, level, cid)
{
	engclient_cmd(id, WEAPON_REFERENCE)
	return PLUGIN_HANDLED
}

public client_disconnected(id, bool:drop, message[], maxlen)
{
	if (is_user_hltv(id))
		return

	g_flLastDamage[id] = 0.0
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

	give_DragonCannon(id)
}
#endif

public give_DragonCannon(const iPlayer)
{
	if (rg_give_custom_item(iPlayer, WEAPON_REFERENCE, GT_DROP_AND_REPLACE, WEAPON_UID) == NULLENT)
	{
		log_error(AMX_ERR_GENERAL, "[ZE] Error while giving the weapon to the player (id: %d)", iPlayer)
		return
	}

	rg_set_user_bpammo(iPlayer, WeaponIdType:WEAPON_ID, WEAPON_MAXAMMO)
}

public fw_UpdateClientData_Post(const id, sendweapons, cd_handle)
{
	if (get_cd(cd_handle, CD_DeadFlag) != DEAD_NO)
		return FMRES_IGNORED

	if (is_DragonCannon(get_member(id, m_pActiveItem)))
	{
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001)
		return FMRES_HANDLED
	}

	return FMRES_IGNORED
}

public fw_ShouldCollide_Pre(const iEnt, const iOther)
{
	if (!FClassnameIs(iOther, FLAME_CLASSNAME))
		return FMRES_IGNORED

	if (!is_user_connected(iEnt))
		return FMRES_IGNORED

	forward_return(FMV_CELL, 0)
	return FMRES_SUPERCEDE
}

public fw_Weapon_DefaultDeploy_Pre(const iWpnEnt, const szViewModel[], const szWeaponModel[], iAnim, const szAnimExt[], skiplocal)
{
	if (!is_DragonCannon(iWpnEnt))
		return

	if (g_v_szWeapModel[0])
		SetHookChainArg(2, ATYPE_STRING, g_v_szWeapModel)

	if (g_p_szWeapModel[0])
		SetHookChainArg(3, ATYPE_STRING, g_p_szWeapModel)

	SetHookChainArg(4, ATYPE_INTEGER, ANIM_DRAW)
	SetHookChainArg(5, ATYPE_STRING, WEAPON_ANIMEXT)
}

public fw_WeaponBox_SetModel(const iEnt, const szModel[])
{
	if (is_nullent(iEnt))
		return

	if (is_DragonCannon(get_member(iEnt, m_WeaponBox_rgpPlayerItems, PRIMARY_WEAPON_SLOT)))
		SetHookChainArg(2, ATYPE_STRING, g_w_szWeapModel)
}

public fw_Weapon_AttachToPlayer_Post(const iWpnEnt, const iPlayer)
{
	if (!is_DragonCannon(iWpnEnt))
		return

	send_WeaponList_msg(iPlayer, 1)
}

public fw_RemovePlayerItem_Post(const iPlayer, const iWpnEnt)
{
	if (!is_DragonCannon(iWpnEnt))
		return

	set_member(iWpnEnt, m_Weapon_fInSpecialReload, 0)
	send_WeaponList_msg(iPlayer)
}

public fw_Weapon_Spawn_Post(const iWpnEnt)
{
	if (!is_DragonCannon(iWpnEnt))
		return

	set_member(iWpnEnt, m_Weapon_iClip, NULLENT)
	set_member(iWpnEnt, m_Weapon_iDefaultAmmo, WEAPON_MAXAMMO)

	rg_set_iteminfo(iWpnEnt, ItemInfo_iMaxClip, NULLENT)
	rg_set_iteminfo(iWpnEnt, ItemInfo_iMaxAmmo1, WEAPON_MAXAMMO)
}

public fw_Weapon_WeaponIdle_Pre(const iWpnEnt)
{
	if (!is_DragonCannon(iWpnEnt))
		return HAM_IGNORED

	if (get_member(iWpnEnt, m_Weapon_flTimeWeaponIdle) > 0.0)
		return HAM_SUPERCEDE

	rg_weapon_send_animation(iWpnEnt, ANIM_IDLE)
	set_member(iWpnEnt, m_Weapon_flTimeWeaponIdle, ANIMT_IDLE)
	return HAM_SUPERCEDE
}

public fw_Weapon_PrimaryAttack_Pre(const iWpnEnt)
{
	if (!is_DragonCannon(iWpnEnt))
		return HAM_IGNORED

	static iPlayer; iPlayer = get_member(iWpnEnt, m_pPlayer)
	static iBpAmmo; iBpAmmo = rg_get_user_bpammo(iPlayer, WeaponIdType:WEAPON_ID)

	if (iBpAmmo <= 0)
	{
		ExecuteHam(Ham_Weapon_PlayEmptySound, iWpnEnt)
		set_member(iWpnEnt, m_Weapon_flNextPrimaryAttack, 0.2)
		return HAM_SUPERCEDE
	}

	if (get_member(iWpnEnt, m_Weapon_fInSpecialReload))
	{
		set_member(iWpnEnt, m_Weapon_flNextPrimaryAttack, 0.2)
		return HAM_SUPERCEDE
	}

	static Float:flHlTime; flHlTime = get_gametime()

	// Fire!
	shoot_Flame(iPlayer)

	set_member(iWpnEnt, m_Weapon_fInSpecialReload, 1)
	set_member(iWpnEnt, m_Weapon_flNextReload, flHlTime + ANIMT_SHOOT)
	set_entvar(iWpnEnt, var_nextthink, flHlTime)

	rg_set_animation(iPlayer, PLAYER_ATTACK1)
	emit_sound(iPlayer, CHAN_WEAPON, g_szWeapFireSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	rg_weapon_send_animation(iPlayer, random_num(ANIM_SHOOT1, ANIM_SHOOT2))

	rg_set_user_bpammo(iPlayer, WeaponIdType:WEAPON_ID, iBpAmmo - 1)

	set_member(iWpnEnt, m_Weapon_flTimeWeaponIdle, ANIMT_SHOOT)
	set_member(iWpnEnt, m_Weapon_flNextPrimaryAttack, ANIMT_SHOOT)
	return HAM_SUPERCEDE
}

public fw_Weapon_PreThink(const iWpnEnt)
{
	if (!is_DragonCannon(iWpnEnt))
		return

	static iPlayer; iPlayer = get_member(iWpnEnt, m_pPlayer)

	if (!is_user_connected(iPlayer))
	{
		return
	}

	static iNumAmmo; iNumAmmo = rg_get_user_bpammo(iPlayer, WeaponIdType:WEAPON_ID)

	if (iNumAmmo <= 0)
	{
		return
	}

	static Float:flHlTime; flHlTime = get_gametime()

	if (get_member(iWpnEnt, m_Weapon_flNextReload) <= flHlTime)
	{
		set_member(iWpnEnt, m_Weapon_fInSpecialReload, 0)
		return // Reloaded!
	}

	// Th!nk.
	set_entvar(iWpnEnt, var_nextthink, flHlTime + 0.01)
}

public shoot_Flame(const iPlayer)
{
	static Float:vAngles[3], Float:vSrc[3], Float:vSpd[3], i
	ExecuteHam(Ham_Player_GetGunPosition, iPlayer, vSrc)
	get_entvar(iPlayer, var_v_angle, vAngles)

	static Float:vForw[3], Float:vRight[3]
	for (i = 0; i < sizeof(g_flRightOffset); i++)
	{
		vForw  = NULL_VECTOR
		vRight = NULL_VECTOR

		engfunc(EngFunc_AngleVectors, vAngles, vForw, vRight)

		xs_vec_mul_scalar(vForw, 128.0, vForw)
		xs_vec_mul_scalar(vRight, g_flRightOffset[i], vRight)

		vSpd[0] = vSrc[0] + vForw[0] + vRight[0]
		vSpd[1] = vSrc[1] + vForw[1] + vRight[1]
		vSpd[2] = vSrc[2] + vForw[2] + vRight[2]

		xs_vec_sub(vSpd, vSrc, vSpd)
		xs_vec_normalize(vSpd, vSpd)
		xs_vec_mul_scalar(vSpd, FLAME_FLYSPEED, vSpd)

		create_Flame(vSpd, vSrc, iPlayer)
	}
}

public create_Flame(const Float:vSpeed[3], const Float:vOrigin[3], const iAttacker)
{
	if (global_get(glb_maxEntities) - engfunc(EngFunc_NumberOfEntities) <= FLAME_ED_CRITIC)
		return

	static iEnt
	if ((iEnt = rg_create_entity(FLAME_REFERENCE)) == 0)
		return

	set_entvar(iEnt, var_classname, FLAME_CLASSNAME)
	set_entvar(iEnt, var_solid, SOLID_TRIGGER)
	set_entvar(iEnt, var_movetype, MOVETYPE_FLYMISSILE)
	set_entvar(iEnt, var_owner, iAttacker)
	set_entvar(iEnt, var_velocity, vSpeed)

	set_entvar(iEnt, var_scale, FLAME_SCALE)

	set_entvar(iEnt, var_rendermode, kRenderTransAdd)
	set_entvar(iEnt, var_renderamt, 255.0)

	engfunc(EngFunc_SetModel, iEnt, g_szFlameSprite)
	engfunc(EngFunc_SetSize, iEnt, FLAME_SIZE_MINS, FLAME_SIZE_MAXS)
	engfunc(EngFunc_SetOrigin, iEnt, vOrigin)


	// Think/Touch Hooks
	SetThink(iEnt, "fw_FlameThink_Pre")
	SetTouch(iEnt, "fw_FlameTouch_Pre")

	// Th!nk.
	dllfunc(DLLFunc_Think, iEnt)
}

public fw_FlameThink_Pre(const iEnt)
{
	if (is_nullent(iEnt))
		return

	static Float:flFrame;  flFrame  = get_entvar(iEnt, var_frame)
	if (flFrame >= g_maxSprFrames)
	{
		SetThink(iEnt, "")
		SetTouch(iEnt, "")

		rg_remove_entity(iEnt)
		return
	}

	flFrame += 2.0
	set_entvar(iEnt, var_frame, flFrame)
	set_entvar(iEnt, var_nextthink, get_gametime() + 0.05)
}

public fw_FlameTouch_Pre(const iEnt, const pevOther)
{
	if (is_nullent(iEnt) || FClassnameIs(pevOther, FLAME_CLASSNAME))
		return

	static iAttacker; iAttacker = get_entvar(iEnt, var_owner)
	static bIsPlayer; bIsPlayer = ExecuteHam(Ham_IsPlayer, pevOther)

	if (pevOther != iAttacker && !bIsPlayer)
	{
		set_entvar(iEnt, var_movetype, MOVETYPE_NONE)
	}

	static Float:flHlTime; flHlTime = get_gametime()

	if (bIsPlayer)
	{
		if (!is_user_alive(pevOther) || !ze_is_user_zombie(pevOther) || pevOther == iAttacker)
		{
			return
		}

		if (g_flLastDamage[pevOther] <= flHlTime)
		{
			if (g_iPushSpeed > 0)
			{
				static Float:vSpeed[3], Float:vNewSpeed[3]
				get_entvar(pevOther, var_velocity, vSpeed)
				velocity_by_aim(iAttacker, g_iPushSpeed, vNewSpeed)

				vNewSpeed[2] = vSpeed[2]

				set_entvar(pevOther, var_velocity, vSpeed)
				vNewSpeed = NULL_VECTOR
				vSpeed = NULL_VECTOR
			}

			// Damage the victim.
			ExecuteHamB(Ham_TakeDamage, pevOther, iEnt, iAttacker, WEAPON_DAMAGE, DMG_BURN)
			g_flLastDamage[pevOther] = flHlTime + FLAME_NEXTDAMAGE
		}
	}
	else  // Entity?
	{
		if (get_entvar(iEnt, var_dmgtime) <= flHlTime)
		{
			if (get_entvar(pevOther, var_takedamage) != DEAD_NO && get_entvar(pevOther, var_health) > 0.0)
			{
				// Damage the entity.
				ExecuteHamB(Ham_TakeDamage, pevOther, iEnt, iAttacker, WEAPON_DAMAGE, DMG_GENERIC)
			}

			set_entvar(iEnt, var_dmgtime, flHlTime + FLAME_NEXTDAMAGE)
		}
	}
}

/**
 * / Function \
 */
send_WeaponList_msg(const id, bMode = 0)
{
	message_begin(MSG_ONE, g_iWeaponList, _, id)
	write_string(bMode ? WEAPON_NAME : WEAPON_REFERENCE) // Weapon Name.
	write_byte(3) // Primary Ammo ID.
	write_byte(WEAPON_MAXAMMO) // Primary Ammo Max Amount.
	write_byte(NULLENT) // Secondary Ammo ID.
	write_byte(NULLENT) // Secondary Ammo Max Amount.
	write_byte(0) // Slot ID.
	write_byte(20) // Number In Slot.
	write_byte(WEAPON_ID) // Weapon ID.
	write_byte(0) // Flags.
	message_end()
}