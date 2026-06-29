# Infection Bomb
- This bomb when exploded, It is infects all Humans that located in explosion field!

## Screenshots :
![thumb](https://i.ibb.co/QFy1Vdjk/CSX.jpg)

## Instructions && Installation :
- Compile plug-in with **AMX Mod X v1.10.0.5467** or newer.
- Copy and paste first INI settings in `ze_extra_items.ini` and second in `zombie_escape.ini`.

## INI Settings :
```ini
[Infection Bomb]
NAME = Infection Bomb
COST = 60
LIMIT = 0
LEVEL = 0
GLOBAL_LIMIT = 1
```
```ini
[Weapon Models]
V_INFECTNADE = models/zm_es/v_infect_bomb.mdl
P_INFECTNADE = models/zm_es/p_infect_bomb.mdl
W_INFECTNADE = models/w_hegrenade.mdl

[Sounds]
INFECT_EXPLODE = zm_es/infect_nade_explode.wav

[Grenade Effects]
INFECT_RING = sprites/shockwave.spr
INFECT_TRAIL = sprites/laserbeam.spr
```