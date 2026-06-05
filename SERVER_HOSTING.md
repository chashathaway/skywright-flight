# Server Hosting Notes

Skywright Flight is a standalone Luanti game. Install the `skywright_flight` folder into the Luanti `games/` directory, then create a world using **Skywright Flight**.

## Recommended

- Use Luanti 5.13 or newer.
- Start with a fresh world while the game is still changing quickly.
- Keep player counts modest until flight and missile performance have been tested on the host machine.
- Back up worlds before major game updates.

## Useful Commands

- `/manual` opens the in-game manual.
- `/plane` spawns and enters a trainer aircraft.
- `/runway` shows a player's assigned runway.
- `/airfield` repairs the player's assigned runway.
- `/airfield all` repairs all 12 runways. This is intentionally heavy.
- `/greenery [radius]` lightly seeds plants and thin trees into already-generated terrain.
- `/softlight [radius]` relights nearby terrain if shadows look strange.

## Performance Notes

Aircraft physics, missiles, camera synchronization, crash checks, and parachutes are server-side. Server lag will affect aircraft feel. Avoid repeatedly running heavy repair commands during active dogfights.

## World Persistence

Runways are generated when chunks are first created. They are not automatically rebuilt on join or respawn, so player changes and repairs persist.

