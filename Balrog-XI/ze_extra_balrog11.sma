#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <reapi>
#include <xs>
#include <ze_core>

// Macro.
#define FIsCustomWeapon(%0)     (is_entity(%0) && get_entvar(%0,var_impulse)==WEAPON_UID)
#define SetWeaponNextAttack(%0,%1,%2,%3) set_member(%0,m_Weapon_flNextPrimaryAttack,%1), set_member(%0,m_Weapon_flNextSecondaryAttack,%2), set_member(%0,m_Weapon_flTimeWeaponIdle,%3)

// CWeapon: ItemInfo
#define WEAPON_CLASSNAME  "weapon_balrog11_lz"
#define WEAPON_REFERENCE  "weapon_xm1014"
#define WEAPON_ANIMEXT    "m249"
#define WEAPON_UID        53731926
#define WEAPON_ID         CSW_XM1014
#define WEAPON_MAXCLIP    7
#define WEAPON_THRESHOLD  7
#define WEAPON_MAXAMMO    35
#define WEAPON_MAXAMMO2   9
#define WEAPON_DAMAGE     13.0
#define WEAPON_DAMAGE2    406.0
#define WEAPON_FIRERATE   0.25
#define WEAPON_FIRERATE2  0.30
// #define WEAPON_RECOIL     0.86

#define FLAME_CLASSNAME   "br_flame"
#define FLAME_REFERENCE   "info_target"
#define FLAME_SIZE_MINS   Float: {-16.0, -16.0, -16.0}
#define FLAME_SIZE_MAXS   Float: {16.0, 16.0, 16.0}
#define FLAME_FLYSPEED    650.0
#define FLAME_NEXTDAMAGE  0.1

#define ICON_HUD_COLOR    { 25, 100, 250 }

// Zombie Escape: Functions
#define ZE_EXTRA_ITEM     1    /* 1 = Enable Extra Item | 0 = Disable Extra Item */
#define ZE_MUZZLEFLASH    1    /* 1 = Enable Extra Item | 0 = Disable Extra Item */

// Zombie Escape: Extra Item
#define ZE_ITEM_NAME      "Balrog-XI"
#define ZE_ITEM_COST      60
#define ZE_ITEM_LIMIT     0

enum _:Colors
{
	Red,
	Green,
	Blue
}

enum _:eCustomData
{
	CData_iFiredShots = 0,
	CData_iMaxAmmo2,

	CData_szIconName[MAX_NAME_LENGTH],
	CData_iIconColor[Colors],
	CData_iAppearMode,

	Float:CData_flLastDamage
}

enum (+=1)
{
	ANIM_IDLE = 0,
	ANIM_SHOOT,
	ANIM_SHOOT2,
	ANIM_INSERT,
	ANIM_RELOAD_AFTER,
	ANIM_RELOAD_START,
	ANIM_DRAW
}

const Float:ANIMP_IDLE = 3.37
const Float:ANIMP_SHOOT = 1.03
const Float:ANIMP_INSERT = 0.43
const Float:ANIMP_AFTER_RELOAD = 0.43
const Float:ANIMP_START_RELOAD = 0.63
const Float:ANIMP_DRAW = 1.13

new const Float:g_flRightOffset[] = { -60.0, -30.0, 0.0, 30.0, 60.0 }

// Weapon Resources
new g_v_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/CSO/v_balrog11.mdl"
new g_p_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/CSO/p_balrog11.mdl"
new g_w_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/CSO/w_balrog11.mdl"

new const g_szFlameSprite[] = "sprites/eexplo.spr"

new const g_szEmitSounds[][] =
{
	"weapons/CSO/balrog11-1.wav",
	"weapons/CSO/balrog11-2.wav",
	"weapons/CSO/balrog11_charge.wav"
}

// Variables.
new g_hTraceLine,
	g_iStatusIcon,
	g_iWeaponList,
	g_maxSprFrames

#if ZE_EXTRA_ITEM == 1
new g_iItemId
#endif

// Array.
new g_WpnCustData[MAX_PLAYERS+1][eCustomData]

// String.
new g_szIconName[32]

// Trie's.
new Trie:g_tCBalrogData

public plugin_precache()
{
	if (!ini_read_string(ZE_FILENAME, "Weapon Models", "V_BALROGXI", g_v_szWeaponModel, charsmax(g_v_szWeaponModel)))
		ini_write_string(ZE_FILENAME, "Weapon Models", "V_BALROGXI", g_v_szWeaponModel)
	if (!ini_read_string(ZE_FILENAME, "Weapon Models", "P_BALROGXI", g_p_szWeaponModel, charsmax(g_p_szWeaponModel)))
		ini_write_string(ZE_FILENAME, "Weapon Models", "P_BALROGXI", g_p_szWeaponModel)
	if (!ini_read_string(ZE_FILENAME, "Weapon Models", "W_BALROGXI", g_w_szWeaponModel, charsmax(g_w_szWeaponModel)))
		ini_write_string(ZE_FILENAME, "Weapon Models", "W_BALROGXI", g_w_szWeaponModel)

	precache_model_s(g_v_szWeaponModel)
	precache_model_s(g_p_szWeaponModel)
	precache_model_s(g_w_szWeaponModel)
	g_maxSprFrames = engfunc(EngFunc_ModelFrames, precache_model_s(g_szFlameSprite))

	for (new i; i < sizeof(g_szEmitSounds); i++)
		precache_sound(g_szEmitSounds[i])

	new const szGenericFiles[][] =
	{
		/* Sound */
		"sound/weapons/CSO/balrog11_insert.wav",
		"sound/weapons/CSO/balrog11_draw.wav",

		/* Sprites */
		"sprites/weapon_balrog11_lz.txt",
		"sprites/640hudc5.spr"
	}

	for (new i; i < sizeof(szGenericFiles); i++)
		precache_generic(szGenericFiles[i])
}

public plugin_init()
{
	// Load Plug-In.
	register_plugin("[ZE] Extra Item: Balrog-XI", "1.0", "z0h1r-LK")

	// Events.
	register_event("HLTV", "fw_NewRound_Event", "a", "1=0", "2=0")

	// Hook Chains.
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "fw_Weapon_DefaultDeploy")
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultShotgunReload, "fw_Weapon_DefaultShotgunReload")
	RegisterHookChain(RG_CBasePlayer_RemovePlayerItem, "fw_RemovePlayerItem_Post", 1)
	RegisterHookChain(RG_CWeaponBox_SetModel, "fw_WeaponBox_SetModel")

	// Hams.
	RegisterHam(Ham_Spawn, WEAPON_REFERENCE, "fw_Weapon_Spawn_Post", 1)

	RegisterHam(Ham_Weapon_WeaponIdle, WEAPON_REFERENCE, "fw_Weapon_WeaponIdle")
	RegisterHam(Ham_Weapon_PrimaryAttack, WEAPON_REFERENCE, "fw_Weapon_PrimaryAttack")
	RegisterHam(Ham_Weapon_SecondaryAttack, WEAPON_REFERENCE, "fw_Weapon_SecondaryAttack")
	RegisterHam(Ham_Item_AddToPlayer, WEAPON_REFERENCE, "fw_Weapon_AddToPlayer_Post", 1)

	// FakeMeta.
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent")
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_forward(FM_ShouldCollide, "fw_ShouldCollide")

	// Commands.
	register_clcmd(WEAPON_CLASSNAME, "cmd_SelectWeapon")

	// Extra Item's.
#if ZE_EXTRA_ITEM == 1
	g_iItemId = ze_item_register(ZE_ITEM_NAME, ZE_ITEM_COST, ZE_ITEM_LIMIT)
#endif

	// Set Values.
	g_iStatusIcon   = get_user_msgid("StatusIcon")
	g_iWeaponList   = get_user_msgid("WeaponList")
}

public plugin_cfg()
{
	// Trie's.
	if ((g_tCBalrogData = TrieCreate()) == Invalid_Trie)
		set_fail_state("[BALROG-XI] TRIE: Error while initializing Trie (g_tCBalrogData)")
}

public plugin_end()
{
	TrieDestroy(g_tCBalrogData)
}

public client_disconnected(id, bool:drop, message[], maxlen)
{
	if (is_user_hltv(id))
		return

	g_WpnCustData[id][CData_iFiredShots] = 0
	g_WpnCustData[id][CData_iMaxAmmo2] = 0

	g_WpnCustData[id][CData_szIconName] = EOS
	g_WpnCustData[id][CData_iIconColor] = { 0, 0, 0 }

	g_WpnCustData[id][CData_flLastDamage] = 0.0
}

public cmd_SelectWeapon(const id, level, cid)
{
	engclient_cmd(id, WEAPON_REFERENCE)
	return PLUGIN_HANDLED
}

public fw_NewRound_Event()
{
	// Restart()
	new entID = FM_NULLENT
	while ((entID = rg_find_ent_by_class(entID, FLAME_CLASSNAME)))
	{
		SetThink(entID, "")
		SetTouch(entID, "")

		rg_remove_entity(entID)  // Free edict.
	}

	TrieClear(g_tCBalrogData)
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
		server_print("[ZE] Error while giving the weapon to the player (id: %d)", id)
}
#endif

public fw_PlaybackEvent() < /* no statement */ >
	return FMRES_IGNORED

public fw_PlaybackEvent() <StopPlaybackEvent: Enabled>
	return FMRES_SUPERCEDE

public fw_PlaybackEvent() <StopPlaybackEvent: Disabled>
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

public fw_ShouldCollide(const entID, const pevOther)
{
	if (!FClassnameIs(pevOther, FLAME_CLASSNAME))
		return FMRES_IGNORED

	if (!is_user_connected(entID))
		return FMRES_IGNORED

	forward_return(FMV_CELL, 0)
	return FMRES_SUPERCEDE
}

public fw_Weapon_DefaultDeploy(const entWpn, const szViewModel[], const szWeaponModel[], iAnim, const szAnimExt[])
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

public fw_Weapon_DefaultShotgunReload(const entWpn, iAnim, iStartAnim, Float:flDelay, Float:flStartDelay, const szReloadSound1[], const szReloadSound2[])
{
	if (!FIsCustomWeapon(entWpn))
		return

	SetHookChainArg(2, ATYPE_INTEGER, ANIM_INSERT)
	SetHookChainArg(3, ATYPE_INTEGER, ANIM_RELOAD_START)
	SetHookChainArg(4, ATYPE_FLOAT, ANIMP_INSERT)
	SetHookChainArg(5, ATYPE_FLOAT, ANIMP_START_RELOAD)
}

public fw_Weapon_AddToPlayer_Post(const entWpn, const playerId)
{
	if (!FIsCustomWeapon(entWpn))
		return

	new szHash[5]
	num_to_str(entWpn, szHash, charsmax(szHash))
	if (TrieGetArray(g_tCBalrogData, szHash, g_WpnCustData[playerId], eCustomData))
		send_StatusIcon_msg(playerId, g_WpnCustData[playerId][CData_szIconName], ICON_HUD_COLOR, g_WpnCustData[playerId][CData_iAppearMode])

	send_WeaponList_Msg(playerId, 1)
}

public fw_RemovePlayerItem_Post(const playerId, const entWpn)
{
	if (!FIsCustomWeapon(entWpn))
		return

	new szHash[5]
	num_to_str(entWpn, szHash, charsmax(szHash))
	TrieSetArray(g_tCBalrogData, szHash, g_WpnCustData[playerId], eCustomData)

	send_WeaponList_Msg(playerId)
	send_StatusIcon_msg(playerId)

	// Free global Array.
	arrayset(g_WpnCustData[playerId], 0, sizeof(g_WpnCustData[]))
}

public fw_WeaponBox_SetModel(const entity, const szModel[])
{
	if (is_nullent(entity))
		return

	if (FIsCustomWeapon(get_member(entity, m_WeaponBox_rgpPlayerItems, PRIMARY_WEAPON_SLOT)))
		SetHookChainArg(2, ATYPE_STRING, g_w_szWeaponModel)
}

public fw_Weapon_Spawn_Post(const entWpn)
{
	if (!FIsCustomWeapon(entWpn))
		return

	set_member(entWpn, m_Weapon_iClip, WEAPON_MAXCLIP)
	set_member(entWpn, m_Weapon_iDefaultAmmo, WEAPON_MAXAMMO)
	set_member(entWpn, m_Weapon_flBaseDamage, WEAPON_DAMAGE)
	set_member(entWpn, m_Weapon_bHasSecondaryAttack, true)

	rg_set_iteminfo(entWpn, ItemInfo_iMaxClip, WEAPON_MAXCLIP)
	rg_set_iteminfo(entWpn, ItemInfo_iMaxAmmo1, WEAPON_MAXAMMO)
}

public fw_Weapon_WeaponIdle(const entWpn)
{
	if (!FIsCustomWeapon(entWpn))
		return HAM_IGNORED

	if (get_member(entWpn, m_Weapon_flTimeWeaponIdle) > 0.0)
		return HAM_SUPERCEDE

	static iClip; iClip = get_member(entWpn, m_Weapon_iClip)
	static playerId; playerId = get_member(entWpn, m_pPlayer)
	static fInSReload; fInSReload = get_member(entWpn, m_Weapon_fInSpecialReload)
	static iBpAmmo; iBpAmmo = rg_get_user_bpammo(playerId, WeaponIdType:WEAPON_ID)

	if (iClip <= 0 && fInSReload == 0 && iBpAmmo > 0)
	{
		ShotgunReload(playerId)
	}
	else if (fInSReload != 0)
	{
		if (iClip < WEAPON_MAXCLIP && iBpAmmo > 0)
		{
			ShotgunReload(playerId)
		}
		else
		{
			set_member(entWpn, m_Weapon_fInSpecialReload, 0)
			rg_weapon_send_animation(playerId, ANIM_RELOAD_AFTER)
			set_member(entWpn, m_Weapon_flTimeWeaponIdle, Float:ANIMP_AFTER_RELOAD)
		}
	}
	else
	{
		rg_weapon_send_animation(playerId, ANIM_IDLE)
		set_member(entWpn, m_Weapon_flTimeWeaponIdle, ANIMP_IDLE)
	}

	return HAM_SUPERCEDE
}

public ShotgunReload(const playerId)
{
	rg_weapon_shotgun_reload(playerId, ANIM_INSERT, ANIM_RELOAD_START, ANIMP_INSERT, ANIMP_START_RELOAD, "weapons/reload1.wav", "weapons/reload3.wav")
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

	state StopPlaybackEvent: Enabled
	g_hTraceLine = register_forward(FM_TraceLine, "fw_TraceLine_Post", 1)
	ExecuteHam(Ham_Weapon_PrimaryAttack, entWpn)
	unregister_forward(FM_TraceLine, g_hTraceLine, 1)
	state StopPlaybackEvent: Disabled

	static playerId; playerId = get_member(entWpn, m_pPlayer)
	emit_sound(playerId, CHAN_WEAPON, g_szEmitSounds[0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	rg_weapon_send_animation(playerId, ANIM_SHOOT)

	if (g_WpnCustData[playerId][CData_iMaxAmmo2] != WEAPON_MAXAMMO2)
	{
		if (++g_WpnCustData[playerId][CData_iFiredShots] >= WEAPON_THRESHOLD)
		{
			if (++g_WpnCustData[playerId][CData_iMaxAmmo2] < WEAPON_MAXAMMO2)
			{
				formatex(g_szIconName, charsmax(g_szIconName), "number_%i", g_WpnCustData[playerId][CData_iMaxAmmo2])
				send_StatusIcon_msg(playerId, g_szIconName, ICON_HUD_COLOR, 1)
			}
			else
			{
				send_StatusIcon_msg(playerId, "number_9", ICON_HUD_COLOR, 2)
			}

			emit_sound(playerId, CHAN_ITEM, g_szEmitSounds[2], VOL_NORM, 0.75, 0, PITCH_NORM)
			g_WpnCustData[playerId][CData_iFiredShots] = 0
		}
	}

	SetWeaponNextAttack(entWpn, WEAPON_FIRERATE, WEAPON_FIRERATE, ANIMP_SHOOT)
	return HAM_SUPERCEDE
}

public fw_TraceLine_Post(const Float:vSrc[3], const Float:vEnd[3], iFlags, iAttacker, hTrace)
{
	if (iFlags & IGNORE_MONSTERS)
		return

	static pHit; pHit = get_tr2(hTrace, TR_pHit)
	if (pHit > 0) if (get_entvar(pHit, var_solid) != SOLID_BBOX) return

	static Float:vTarget[3]
	get_tr2(hTrace, TR_vecEndPos, vTarget)

	// Gun Shot (Decal)
	message_begin_f(MSG_PVS, SVC_TEMPENTITY, vTarget)
	write_byte(TE_GUNSHOTDECAL) // TE id.
	write_coord_f(vTarget[0]) // Position X.
	write_coord_f(vTarget[1]) // Position Y.
	write_coord_f(vTarget[2]) // Position Z.
	write_short(pHit > 0 ? pHit : 0) // Entity ID.
	write_byte(random_num(41, 45)) // Decal.
	message_end()
}

public fw_Weapon_SecondaryAttack(const entWpn)
{
	if (!FIsCustomWeapon(entWpn))
		return HAM_IGNORED

	static playerId; playerId = get_member(entWpn, m_pPlayer)
	if (g_WpnCustData[playerId][CData_iMaxAmmo2] <= 0)
	{
		set_member(entWpn, m_Weapon_flNextSecondaryAttack, 0.2)
		return HAM_SUPERCEDE
	}

	static Float:vAngles[3], Float:vSrc[3], Float:vSpd[3], i
	ExecuteHam(Ham_Player_GetGunPosition, playerId, vSrc)
	get_entvar(playerId, var_v_angle, vAngles)

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

		create_Flame(vSpd, vSrc, playerId)
	}

	g_WpnCustData[playerId][CData_iMaxAmmo2]--

	if (g_WpnCustData[playerId][CData_iMaxAmmo2] <= 0)
	{
		send_StatusIcon_msg(playerId, g_WpnCustData[playerId][CData_szIconName], g_WpnCustData[playerId][CData_iIconColor], 0)
	}
	else if (g_WpnCustData[playerId][CData_iMaxAmmo2] <= 9)
	{
		formatex(g_szIconName, charsmax(g_szIconName), "number_%i", g_WpnCustData[playerId][CData_iMaxAmmo2])
		send_StatusIcon_msg(playerId, g_szIconName, ICON_HUD_COLOR, 1)
	}
	else
	{
		send_StatusIcon_msg(playerId, "number_9", ICON_HUD_COLOR, 2)
	}

	rg_weapon_send_animation(playerId, ANIM_SHOOT2)
	emit_sound(playerId, CHAN_WEAPON, g_szEmitSounds[1], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	rg_set_animation(playerId, PLAYER_ATTACK1)

	SetWeaponNextAttack(entWpn, WEAPON_FIRERATE2, WEAPON_FIRERATE2, ANIMP_SHOOT)
	return HAM_SUPERCEDE
}

public create_Flame(const Float:vSpeed[3], const Float:vSpawn[3], iAttacker)
{
	static entity
	if ((entity = rg_create_entity(FLAME_REFERENCE)) == 0)
		return

	set_entvar(entity, var_classname, FLAME_CLASSNAME)
	set_entvar(entity, var_solid, SOLID_TRIGGER)
	set_entvar(entity, var_movetype, MOVETYPE_FLYMISSILE)
	set_entvar(entity, var_owner, iAttacker)
	set_entvar(entity, var_animtime, get_gametime())
	set_entvar(entity, var_scale, 1.0)
	set_entvar(entity, var_renderamt, 255.0)
	set_entvar(entity, var_rendermode, kRenderTransAdd)
	set_entvar(entity, var_velocity, vSpeed)

	engfunc(EngFunc_SetModel, entity, g_szFlameSprite)
	engfunc(EngFunc_SetSize, entity, FLAME_SIZE_MINS, FLAME_SIZE_MAXS)
	engfunc(EngFunc_SetOrigin, entity, vSpawn)

	// Think/Touch Hooks.
	SetThink(entity, "fw_FlameThink_Pre")
	SetTouch(entity, "fw_FlameTouch_Pre")

	dllfunc(DLLFunc_Think, entity)
}

public fw_FlameThink_Pre(const entID)
{
	if (is_nullent(entID))
		return

	static Float:flFrame;  flFrame  = get_entvar(entID, var_frame)
	if (flFrame >= g_maxSprFrames)
	{
		SetThink(entID, "")
		SetTouch(entID, "")

		rg_remove_entity(entID)
		return
	}

	flFrame += 2.0
	set_entvar(entID, var_frame, flFrame)
	set_entvar(entID, var_nextthink, get_gametime() + 0.05)
}

public fw_FlameTouch_Pre(const entID, const pevOther)
{
	if (is_nullent(entID) || FClassnameIs(pevOther, FLAME_CLASSNAME))
		return HC_CONTINUE

	static iAttacker; iAttacker = get_entvar(entID, var_owner)

	if (pevOther != iAttacker && !is_user_connected(pevOther))
	{
		set_entvar(entID, var_movetype, MOVETYPE_NONE)
	}

	if (!is_user_alive(iAttacker) || !ze_is_user_zombie(pevOther) || pevOther == iAttacker)
	{
		return HC_CONTINUE
	}

	static Float:flHlTime; flHlTime = get_gametime()

	if (g_WpnCustData[pevOther][CData_flLastDamage] <= flHlTime)
	{
		// Damage the victim.
		ExecuteHamB(Ham_TakeDamage, pevOther, iAttacker, iAttacker, WEAPON_DAMAGE2, DMG_BURN)
		g_WpnCustData[pevOther][CData_flLastDamage] = flHlTime + FLAME_NEXTDAMAGE
	}

	return HC_CONTINUE
}

/* --- The Function --- */
precache_model_s(const model[])
{
	if (!file_exists(model, true))
		return set_fail_state("[FATAL ERROR] File does not exists '%s'", model)
	return precache_model(model)
}

send_StatusIcon_msg(const id, const szIconName[] = "", const iColor[Colors] = {0, 0, 0}, iMode = 0)
{
	if (iMode > 0)
	{
		if (g_WpnCustData[id][CData_szIconName])
		{
			message_begin(MSG_ONE, g_iStatusIcon, _, id)
			write_byte(0) // Status (0 = Disabled | 1 = Show | 2 = Flash).
			write_string(g_WpnCustData[id][CData_szIconName]) // Icon Name.
			message_end()
		}

		message_begin(MSG_ONE, g_iStatusIcon, _, id)
		write_byte(iMode) // Status (0 = Disabled | 1 = Show | 2 = Flash).
		write_string(szIconName) // Icon Name.
		write_byte(iColor[Red]) // Red
		write_byte(iColor[Green]) // Green
		write_byte(iColor[Blue]) // Blue
		message_end()

		copy(g_WpnCustData[id][CData_szIconName], charsmax(g_WpnCustData[]) - CData_szIconName, szIconName)

		g_WpnCustData[id][CData_iIconColor][Red]   = iColor[Red]
		g_WpnCustData[id][CData_iIconColor][Green] = iColor[Green]
		g_WpnCustData[id][CData_iIconColor][Blue]  = iColor[Blue]

		g_WpnCustData[id][CData_iAppearMode] = iMode
	}
	else
	{
		message_begin(MSG_ONE, g_iStatusIcon, _, id)
		write_byte(0) // Status (0 = Disabled | 1 = Show | 2 = Flash).
		write_string(g_WpnCustData[id][CData_szIconName]) // Icon Name.
		message_end()

		g_WpnCustData[id][CData_szIconName]  = NULL_STRING
		g_WpnCustData[id][CData_iIconColor]  = { 0, 0, 0 }
		g_WpnCustData[id][CData_iAppearMode] = 0
	}

	g_szIconName = NULL_STRING
}

send_WeaponList_Msg(const id, const iMode = 0)
{
	message_begin(MSG_ONE, g_iWeaponList, .player = id)
	write_string(iMode ? WEAPON_CLASSNAME : WEAPON_REFERENCE) // Weapon Name.
	write_byte(5) // Primary Ammo ID.
	write_byte(WEAPON_MAXAMMO) // Primary Ammo Max Amount.
	write_byte(NULLENT) // Secondary Ammo ID.
	write_byte(NULLENT) // Secondary Ammo Max Amount.
	write_byte(0) // SlotID.
	write_byte(1) // Number in slot.
	write_byte(WEAPON_ID) // Weapon ID.
	write_byte(0) // Flags
	message_end()
}