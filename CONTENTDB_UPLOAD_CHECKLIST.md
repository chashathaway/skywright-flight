# ContentDB Upload Checklist

Skywright Flight is packaged as a standalone Luanti game.

## Ready

- `game.conf` has title, description, author, and minimum Luanti version.
- `.cdb.json` identifies the package as a game.
- `.cdb.json` sets `license` to `MIT` and `media_license` to `Other (Free/Open)`.
- `.cdb.json` includes the GitHub source repository URL.
- `LICENSE.md` documents code licensing, mixed media licensing, and current attribution groups.
- `CREDITS.md` gives author and upstream community attribution.
- README describes gameplay, controls, commands, survival basics, and hosting notes.
- No external mods are required.
- The installed game folder and source folder have been kept in sync during development.

## Required Before Public Upload

- Add at least one current gameplay screenshot named `screenshot.png`.
- Review any user-added texture/model sources whose upstream origin is uncertain and keep only assets that can be redistributed and modified under the licenses documented in `LICENSE.md`.

## Suggested License Shape

Current ContentDB-friendly choices:

- Code: `MIT`
- Media: `Other (Free/Open)` because the package currently mixes original `CC-BY-SA-4.0` media with third-party free/open media groups.

Use only licenses you are comfortable granting publicly. Do not publish until any third-party or derived textures have known compatible source/attribution notes.

## Current Asset Areas To Verify

- `default_*` textures and model-compatible player body assets
- `mcl_core_*` textures
- flower textures
- generated/AI-assisted aircraft, console, item, and runway art
- any assets copied from other Luanti games or texture packs

## Recommended Screenshot

Take a current in-game screenshot showing:

- a trainer aircraft in chase view
- terrain with runways or hills
- some visible sky/ground context

ContentDB requires at least one screenshot; featured-quality packages also expect a strong cover image.
