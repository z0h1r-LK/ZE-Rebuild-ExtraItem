#include <amxmodx>
#include <ze_core>
#include <ze_levels>

// Libraries.
stock const LIB_LEVELS[] = "ze_levels"

enum _:ITEM_SETTING
{
	ITEM_EC = 0,
	ITEM_XP
}

// Zombie Escape: Item Info.
stock const ZE_ITEM_NAME[] = "Buy XP"

// Variables.
new g_iItemID

// Array.
new g_iPageNum[MAX_PLAYERS+1]

// Dynamic Arrays.
new Array:g_aItemSettings

public plugin_natives()
{
	set_module_filter("fw_module_filter")
	set_native_filter("fw_native_filter")
}

public fw_module_filter(const module[], LibType:libtype)
{
	return equal(module, LIB_LEVELS) ? PLUGIN_HANDLED : PLUGIN_CONTINUE
}

public fw_native_filter(const name[], index, trap)
{
	return !trap ? PLUGIN_HANDLED : PLUGIN_CONTINUE
}

public plugin_init()
{
	// Load Plug-In.
	register_plugin("[ZE] Extra Item: Buy XP", "1.0", "z0h1r-LK")

	// New Item.
	g_iItemID = ze_item_register(ZE_ITEM_NAME, 0, 0)

	// Create Arrays.
	g_aItemSettings = ArrayCreate(ITEM_SETTING, 1)
}

public plugin_cfg()
{
	// Default Item settings.
	new szItemSettings[INI_MAX_STRING_LEN] = "40:300 , 70:600 , 100:1000"

	// Read item settings from INI file.
	if (!ini_read_string(ZE_ET_FILENAME, ZE_ITEM_NAME, "EC_XP_LIST", szItemSettings, charsmax(szItemSettings)))
		ini_write_string(ZE_ET_FILENAME, ZE_ITEM_NAME, "EC_XP_LIST", szItemSettings)

	trim(szItemSettings)

	new aArray[ITEM_SETTING], szItem[64], szXP[15], szEC[15]
	while (szItemSettings[0] && strtok2(szItemSettings, szItem, charsmax(szItem), szItemSettings, charsmax(szItemSettings), ','))
	{
		strtok2(szItem, szEC, charsmax(szEC), szXP, charsmax(szXP), ':')

		aArray[ITEM_EC] = str_to_num(szEC)
		aArray[ITEM_XP] = str_to_num(szXP)

		ArrayPushArray(g_aItemSettings, aArray)
	}
}

public ze_select_item_post(id, iItem, bool:bIgnoreCost)
{
	if (iItem != g_iItemID)
		return

	show_BuyXP_Menu(id)
}

public show_BuyXP_Menu(const clId)
{
	// Title:
	new iMenu = menu_create(fmt("%L %L", LANG_PLAYER, "MENU_PREFIX", LANG_PLAYER, "MENU_BUYXP_TITLE"), "handler_BuyXP_Menu")
	new iMaxLoops = ArraySize(g_aItemSettings)
	new iAccount = ze_get_user_coins(clId)

	for (new szLang[64], iItemData[2], aArray[ITEM_SETTING], i = 0; i < iMaxLoops; i++)
	{
		ArrayGetArray(g_aItemSettings, i, aArray)

		if (iAccount < aArray[ITEM_EC])
			formatex(szLang, charsmax(szLang), "\d%i %L -> %i %L", aArray[ITEM_EC], LANG_PLAYER, "MENU_EC", aArray[ITEM_XP], LANG_PLAYER, "MENU_XP")
		else
			formatex(szLang, charsmax(szLang), "\y%i \w%L \r-> \y%i \w%L", aArray[ITEM_EC], LANG_PLAYER, "MENU_EC", aArray[ITEM_XP], LANG_PLAYER, "MENU_XP")

		iItemData[0] = i
		iItemData[1] = 0

		menu_additem(iMenu, szLang, iItemData, 0)
	}

	if (!menu_items(iMenu))
		menu_addtext2(iMenu, fmt("%L", LANG_PLAYER, "MENU_NO_PLAYERS"))

	menu_setprop(iMenu, MPROP_NEXTNAME, fmt("%L", LANG_PLAYER, "MENU_NEXT"))
	menu_setprop(iMenu, MPROP_BACKNAME, fmt("%L", LANG_PLAYER, "MENU_BACK"))
	menu_setprop(iMenu, MPROP_EXITNAME, fmt("%L", LANG_PLAYER, "MENU_EXIT"))

	menu_display(clId, iMenu, g_iPageNum[clId])
}

public handler_BuyXP_Menu(const clId, iMenu, iKey)
{
	switch (iKey)
	{
		case MENU_TIMEOUT, MENU_EXIT:
		{
			goto closeMenu
		}
		default:
		{
			new iItemData[2]
			menu_item_getinfo(iMenu, iKey, _, iItemData, charsmax(iItemData))
			new const i = iItemData[0]

			new aArray[ITEM_SETTING]
			ArrayGetArray(g_aItemSettings, i, aArray)

			new const iAccount = ze_get_user_coins(clId)
			new const iItemCost = aArray[ITEM_EC]

			if (iAccount >= iItemCost)
			{
				if (LibraryExists(LIB_LEVELS, LibType_Library))
				{
					ze_set_user_xp(clId, aArray[ITEM_XP], true)
					ze_set_user_coins(clId, iAccount - iItemCost)
				}

				ze_colored_print(clId, "%L", LANG_PLAYER, "MSG_PURCHASE_XP", aArray[ITEM_XP])
			}

			g_iPageNum[clId] = iKey / 7
			show_BuyXP_Menu(clId)
		}
	}

	closeMenu: // Free the Memory.
	menu_destroy(iMenu)
	return PLUGIN_HANDLED
}