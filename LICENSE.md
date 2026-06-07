# Skywright Flight License

Skywright Flight is distributed as a free/open Luanti game.

This project uses separate licensing for code and media because Luanti/ContentDB tracks those separately and because the package includes a mix of original assets and free/open assets derived from existing Luanti games.

## Code License

Unless otherwise noted, Lua source code, game configuration files, and project documentation authored for Skywright Flight are licensed under the MIT License.

Copyright (c) 2026 Chas Hathaway and contributors

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Media License Summary

Skywright Flight media is distributed under Creative Commons Attribution-ShareAlike terms. The package-level media license selected on ContentDB is Creative Commons Attribution-ShareAlike 4.0 International (`CC-BY-SA-4.0`).

- Original Skywright Flight media created for this project is licensed under Creative Commons Attribution-ShareAlike 4.0 International (`CC-BY-SA-4.0`), unless a more specific note below applies.
- Minetest Game-derived media originated under Creative Commons Attribution-ShareAlike 3.0 Unported (`CC-BY-SA-3.0`) and is credited below.
- VoxeLibre / MineClone-family-derived media is licensed under Creative Commons Attribution-ShareAlike 4.0 International (`CC-BY-SA-4.0`).

The ContentDB package metadata uses `CC-BY-SA-4.0` for `media_license` so the package has a concrete free/open media license selected in ContentDB.

## Current Media Attribution Notes

The following groups are believed to include or derive from Minetest Game media and retain `CC-BY-SA-3.0`:

- `mods/flight_world/models/character.b3d`
- `mods/flight_world/textures/default_*.png`
- `mods/flight_world/textures/flowers_*.png` where sourced from Minetest Game-style flora assets

The following groups are believed to include or derive from VoxeLibre / MineClone-family media and retain `CC-BY-SA-4.0`:

- `mods/flight_world/textures/mcl_core_*.png`
- MineClone-style block, plant, tool, and item textures where sourced from VoxeLibre / MineClone-family assets

The following groups were created or adapted for Skywright Flight and are licensed as `CC-BY-SA-4.0`:

- aircraft textures and recolors
- missile, runway, stripe, spawn marker, console, HUD, hand, pilot, ore, tool, titanium, stove, glass, and cold ridge textures that were created or adapted for this game
- simple OBJ card/shadow aircraft display models
- `menu/icon.png`

## Upstream References

- Minetest Game media is distributed under `CC-BY-SA-3.0`; its code is under `LGPL-2.1-or-later`.
- VoxeLibre, formerly MineClone2, lists code as `GPL-3.0-or-later` and media as `CC-BY-SA-4.0` on ContentDB.
- ContentDB accepts package metadata fields named `license` and `media_license`; this package uses `MIT` for code and `CC-BY-SA-4.0` for media.

## Source Audit Note

Before a high-visibility public release, review any user-added image whose upstream source is uncertain. If an asset cannot be traced to an original project file, an original author contribution, a generated asset you are comfortable licensing, or a free/open source with compatible terms, replace it before upload.
