# Skywright Flight

Skywright Flight is a standalone Luanti game about small aircraft, rough runways, parachutes, crash salvage, and light survival crafting.

The game is built around an old-school flight-sim feel: roll into a bank, pull back to turn, manage speed, and watch the ground. Players spawn at persistent home runways arranged around the origin, can fly trainer aircraft, fire early heat-seeking missiles, eject and parachute, repair runways, dig terrain, gather wood, craft tools, and build basic support structures.

## Requirements

- Luanti 5.13 or newer
- No external mods required

## Quick Start

1. Create a new world using the **Skywright Flight** game.
2. Join the world and read the in-game manual.
3. Type `/plane` to spawn and enter a trainer aircraft, or craft a trainer kit later.
4. Use `/manual`, `/flightmanual`, or `/controls` to reopen the manual.

## Flight Controls

- `Jump`: throttle up
- `Sneak`: throttle down
- `W` / `S`: pitch nose down / up
- `A` / `D`: roll left / right
- `Aux + A` / `Aux + D`: rudder left / right
- `Place` / right-click: brake
- Punch / left-click or `/fire`: launch missile
- `Shift+E` or `/eject`: eject
- Airborne `Jump`: toggle parachute after ejecting

## World

- New players are assigned one of 12 persistent runways around the origin.
- Runways are generated with the world and are not rebuilt automatically.
- `/runway` shows your assigned runway.
- `/airfield` repairs your own runway.
- `/airfield all` repairs the full runway ring.
- `/greenery [radius]` lightly seeds flowers and thin trees into existing terrain.

## Survival Basics

Pilots on foot can dig dirt, sand, flowers, leaves, wood, and stone-like blocks. Wood is slower to dig by hand than soft ground.

Basic crafting includes:

- tree trunks into wood planks
- wood planks into sticks
- wooden, stone, iron, and steel tools
- stone stove
- sand into glass
- cobble into stone
- aircraft scrap iron into ordinary iron ingots
- ordinary iron ingots into steel ingots
- titanium ore into lumps, stove-cooked titanium ingots, blocks, sheets, tools, and blast-resistant armor
- coal ore into coal lumps for stove fuel and torches
- cracked aircraft glass into ordinary glass
- trainer kit from iron, glass, and sticks

## Notes For Server Hosts

This game is still early, but playable. Expect tuning changes to aircraft physics, dogfighting, crafting, and terrain. A fresh world is recommended while the game is changing quickly.

The flight model is server-side. High server lag will affect aircraft smoothness, especially with many planes or missiles active.

## ContentDB Status

This folder has been prepared for ContentDB-style packaging, but public release still needs:

- at least one current gameplay screenshot named `screenshot.png`

Licensing has been added in `LICENSE.md`. Code is MIT. Media is listed as mixed free/open media in `.cdb.json` because the game includes original assets plus free/open Minetest Game and VoxeLibre/MineClone-family derived assets.

## License

Skywright Flight is free/open content. Code and documentation are licensed under the MIT License. Media is documented as mixed free/open media, with original Skywright Flight media under `CC-BY-SA-4.0` and inherited free/open assets retaining their upstream licenses. See `LICENSE.md` and `CREDITS.md`.
