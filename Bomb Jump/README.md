# Bomb Jump
- This bomb is only available to Zombies and when it explodes, it pushes enemies within its range.

## Screenshots :
![bj](https://i.ibb.co/V76Wsn2/Zbgrn.webp)

## Instructions && Installation :
- Compile plug-in with **AMX Mod X v1.10.0.5467** or newer.
- Copy and paste first INI settings in `ze_extra_items.ini` and second in `zombie_escape.ini`.

## Console Variables :
```c
// --- --- ---
// Extra Item: Bomb Jump
// --- --- ---
ze_bombjump_give 1         // Give free bomb jump (1 = Enabled | 0 = Disabled).
ze_bombjump_force "500.0"  // Knockback force (default: 500.0).
ze_bombjump_radius "240.0" // Explosion radius (default: 240.0).
```

## INI Settings :
- `ze_extra_items.ini`
```ini
[Bomb Jump]
NAME = Bomb Jump
COST = 10
LIMIT = 2
```
- `zombie_escape.ini`
```ini
[Weapon Models]
V_BOMBJUMP = models/zm_es/v_bombjump_lz.mdl
P_BOMBJUMP = models/zm_es/p_bombjump_lz.mdl
W_BOMBJUMP = models/zm_es/w_bombjump_lz.mdl
```