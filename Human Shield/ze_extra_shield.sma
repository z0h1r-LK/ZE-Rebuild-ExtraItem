#include <amxmodx>
#include <reapi>
#include <ze_core>

// Zombie Escape: Item Info
stock const ZE_ITEM_NAME[] = "Infection Shield"
stock const ZE_ITEM_COST = 40
stock const ZE_ITEM_LIMIT = 1

// Variables.
new g_iItemID

// Setting.
new g_iAmount = 100

public plugin_init()
{
	// Load Plug-In.
	register_plugin("[ZE] Extra Item: Human Shield", "1.0", "z0h1r-LK")

	// New Item.
	g_iItemID = ze_item_register(ZE_ITEM_NAME, ZE_ITEM_COST, ZE_ITEM_LIMIT)
}

public plugin_cfg()
{
	if (!ini_read_int(ZE_ET_FILENAME, ZE_ITEM_NAME, "STRENGTH", g_iAmount))
		ini_write_int(ZE_ET_FILENAME, ZE_ITEM_NAME, "STRENGTH", g_iAmount)
}

public ze_select_item_pre(id, iItem, bool:bIgnoreCost, bool:bInMenu)
{
	// Wrong item?
	if (iItem != g_iItemID)
		return ZE_ITEM_AVAILABLE

	// Allow an item only for Humans.
	if (ze_is_user_zombie(id))
		return ZE_ITEM_DONT_SHOW

	if (get_user_armor(id) >= g_iAmount)
		return ZE_ITEM_UNAVAILABLE

	return ZE_ITEM_AVAILABLE // Show item on Menu.
}

public ze_select_item_post(id, iItem, bool:bIgnoreCost)
{
	if (iItem != g_iItemID)
		return

	client_cmd(id, "spk ^"items/tr_kevlar.wav^"")
	rg_set_user_armor(id, g_iAmount, ARMOR_VESTHELM)
}