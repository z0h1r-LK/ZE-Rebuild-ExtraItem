# AK47 Golden
- AK47 golden is powerful weapon.

## Screenshots :
![AKG](https://i.ibb.co/JwmXdgDz/akg.jpg)

## Instructions && Installation :
- Compile plug-in with **AMX Mod X v1.10.0.5467** or newer.
- Copy and paste first INI settings in `ze_extra_items.ini` and second in `zombie_escape.ini`.

## INI Settings :
```ini
[AK47 Golden]
NAME = AK47 Golden
COST = 35
LIMIT = 0
LEVEL = 0
GLOBAL_LIMIT = 0
VIEW_MODEL = models/zm_es/v_ak47g.mdl
PLAYER_MODEL = models/zm_es/p_ak47g.mdl
WORLD_MODEL = models/zm_es/w_ak47g.mdl
```

## Console Variables :
```c
// --- --- ---
// AK47 Golden
// --- --- ---
ze_ak47g_beam 1         // AK47 golden bullet trace (1 = Enabled | 0 = Disabled).
ze_ak47g_clip 35        // AK47 golden max clip (Default: 30).
ze_ak47g_ammo 200       // AK47 golden maximum ammo (Default: 90).
ze_ak47g_damage "71.0"  // AK47 golden base damage (Default: 40).
```

## For Weapons Menu :
- If you want disable AK47 golden in Extra Item, U will find `#define EXTRA_ITEM 1`, 1 = Enabled | 0 = Disabled
- `"p" "AK47 Golden" "weapon_ak47" "200" "8558424" "0"`
