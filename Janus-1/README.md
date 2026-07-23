# Janus-I

<div align="center">
	<img src="https://i.ibb.co/xK7WZVZW/th.jpg" alt="Thumbnail" />
</div>

## – Description :
- JANUS-1 is a grenade launcher categorized under the pistol slot and developed by Aegis Institute. It is fed with 5 rounds of 40mm grenade and is equipped with the Janus Transformation System which enables the weapon to continuously fire unlimited rounds for 7 seconds. However, the system only activates after all initial grenade rounds are used up (and hit) on a target. The weapon's Janus form has greater firepower and rate of fire.

## – Instructions && Installations:
- Compile plug-in with *AMX Mod X v1.10.0.5467* or newer
- Copy and paste first *INI settings* in `ze_extra_items.ini` and second in `zombie_escape.ini`

## – INI Settings :
```ini
[Janus-I]
NAME = Janus-I
COST = 30
LIMIT = 0
LEVEL = 0
GLOBAL_LIMIT = 0
```
```ini
[Weapon Models]
V_JANUS1 = models/CSO/v_janus1.mdl
P_JANUS1 = models/CSO/p_janus1.mdl
W_JANUS1 = models/CSO/w_janus1.mdl
S_JANUS1 = models/grenade.mdl
```

## – Weapons Menu :
- If you want disable Janus-I in Extra Item, U will find `#define ZE_EXTRA_ITEM 1`, 1 = Enabled | 0 = Disabled
- `"p" "Janus-I" "weapon_deagle" "25" "15272226" "0"`