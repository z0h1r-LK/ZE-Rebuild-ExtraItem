# Buy XP
- This add-on displays an item in Extra Item Menu for EC exchange to XP points.

## Screenshots :
![ScreenShots](https://i.ibb.co/Vp0Yrc6B/screenshot.jpg)

## Instructions && Installation :
- Compile plug-in with **AMX Mod X v1.10.0.5467** or newer.
- Copy and paste first INI settings in `ze_extra_items.ini` and second in `zombie_escape.ini`.

## INI Settings :
```ini
[Buy XP]
NAME = Buy XP
COST = 0
LIMIT = 0
LEVEL = 0
GLOBAL_LIMIT = 0
EC_XP_LIST = 40:300, 70:600, 100:1000, 150:2000
```
- **You can add more items in Buy XP, Just follow format below!**

## Format Usage :
- `EC:XP` – In left side is XP cost and right side is XP points, Split it using :.
- E.g..:`15:200`
- E.g..:`15:200, 40:400, 50:700, 75:800, 100:1000, 120:1500`