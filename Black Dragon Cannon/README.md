# Blaster

<div align="center">
<img src="https://i.ibb.co/nq6KzHkq/Half-Life02-1.jpg" alt="Thumbnail" />
</div>

## – Description :
- This is a cannon decorated to look like a dragon. It is a single-shot break-action equipment that has 20 Cannon Rounds in spare, which detonate within the targeted area creating a large volcano-like explosion, dealing tremendous damage to anything in its radius. Also, the weapon's gun barrel is built short, granting excellent mobility in combat.

## – Instructions && Installations:
- Compile plug-in with *AMX Mod X v1.10.0.5467* or newer
- Copy and paste first *INI settings* in `ze_extra_items.ini` and second in `zombie_escape.ini`

## – INI Settings :
```ini
[Black Dragon Cannon]
NAME = Black Dragon Cannon
COST = 60
LIMIT = 0
LEVEL = 0
GLOBAL_LIMIT = 0
KNOCKBACK_SPEED = 250
```
```ini
[Weapon Models]
V_DRAGON_CANNON = models/CSO/v_cannon.mdl
P_DRAGON_CANNON = models/CSO/p_cannon.mdl
W_DRAGON_CANNON = models/CSO/w_cannon.mdl
```
- `KNOCKBACK_SPEED` Knockback push speed when Flame touch the Zombies.
