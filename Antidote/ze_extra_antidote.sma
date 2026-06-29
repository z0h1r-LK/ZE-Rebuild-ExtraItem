#include <amxmodx>
#include <reapi>
#include <ze_core>

// Item Info.
stock const ZE_ITEM_NAME[] = "Antidote"
stock const ZE_ITEM_COST = 15
stock const ZE_ITEM_LIMIT = 0
stock const ZE_ITEM_GLIMIT = 3

// ConVars.
new g_iItemID

// Variables.
new bool:g_bEnabled

public plugin_init()
{
	// Load Plug-In.
	register_plugin("[ZE] Extra Item: Antidote", ZE_VERSION, ZE_AUTHORS)

	// ConVars.
	bind_pcvar_num(register_cvar("ze_extra_antidote", "1"), g_bEnabled)

	// New Item.
	g_iItemID = ze_item_register_ex(ZE_ITEM_NAME, ZE_ITEM_COST, ZE_ITEM_LIMIT, 0, ZE_ITEM_GLIMIT)
}

public ze_select_item_pre(id, iItem, bool:bIgnoreCost, bool:bInMenu)
{
	if (iItem != g_iItemID)
		return ZE_ITEM_AVAILABLE

	if (!g_bEnabled)
		return ZE_ITEM_DONT_SHOW

	// Only allow zombies to buy this item
	if (!ze_is_user_zombie(id))
		return ZE_ITEM_DONT_SHOW

	if (get_member_game(m_iNumTerrorist) <= 1)
	{
		if (!bInMenu)
			ze_colored_print(id, "%L", LANG_PLAYER, "CMD_LAST_HUMAN")
		return ZE_ITEM_UNAVAILABLE
	}

	return ZE_ITEM_AVAILABLE
}

public ze_select_item_post(id, iItem, bool:bIgnoreCost)
{
	if (iItem != g_iItemID)
		return

	if (!ze_is_user_zombie(id) || get_member_game(m_iNumTerrorist) <= 1)
		return

	// Convert zombie to human immediately after purchase
	if (ze_force_set_user_human(id))
		ze_colored_print(id, "%L", LANG_PLAYER, "MSG_ANTIDOTE_CURED")
	else
		ze_colored_print(id, "%L", LANG_PLAYER, "MSG_ANTIDOTE_NOT")
}