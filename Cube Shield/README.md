# Cube Shield
- This grenade creates a large cube that the zombie cannot enter or break. It remains for a certain period of time and breaks on its own. Humans are the only ones who can enter it, This is better than Holy Hand Grenade :smile:

## Screenshots :
![thumb](https://i.ibb.co/V9q8ck4/de-dust20012.jpg)

## Instructions && Installation :
- Compile plug-in with **AMX Mod X v1.10.0.5467** or newer.
- Copy and paste first INI settings in `ze_extra_items.ini` and second in `zombie_escape.ini`.

## INI Settings :
```ini
[Cube Shield]
NAME = Cube Shield
COST = 20
LIMIT = 1
```
```ini
[Weapon Models]
V_CUBENADE = models/zm_es/v_3dcube.mdl
P_CUBENADE = models/p_smokegrenade.mdl
W_CUBENADE = models/w_smokegrenade.mdl

[Models]
CUBE_MODEL = models/zm_es/cube_shield.mdl

[Grenade Effects]
CUBE_TRAIL = sprites/laserbeam.spr
```

## Console Variables :
```c
// --- --- ---
// Cube Shield
// --- --- ---
ze_cube_duration "15.0"        // Time before break Cube in seconds (default: 15.0)
```

## Special Thanks :
- [Kyle WoodenMan](https://gamebanana.com/members/2090158) -→ Creator of cube_shield.mdl and v_3dcube.mdl
