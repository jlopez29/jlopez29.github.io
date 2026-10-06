# Assets and attribution

The project includes the **Pit Boss authored/generated visual asset library** in
`assets/pit_boss/`. Its modular SVG branding, navigation, guest dots/rings, playing
cards, chips, roulette wheel, dice and slot symbols are used by the live game.
Generated PNG starter casino furniture and flooring supply the management floor;
individual felt textures and the cabinet frame supply direct-play surfaces.
The reference screenshots are composition targets only, excluded from exports.
Some procedural elements remain for dynamic wager regions, effects, the lemon
symbol (absent from the pack), and unsupported asset details. No external fonts
or audio have been added. The pack README identifies generated raster art as
starter artwork requiring visual cleanup before release; no external license or
artist attribution was supplied with the package.

The web runtime is **Godot Engine 4.7.2**, distributed under the MIT license with
third-party dependencies. Its default bundled font and generated loading splash
come from Godot. Engine license and dependency notices are supplied in
[`casino/THIRD_PARTY_NOTICES.txt`](../casino/THIRD_PARTY_NOTICES.txt). They must remain
with redistributions. Godot sources: https://github.com/godotengine/godot.

Craps rule references are documentation only; no third-party text or visual assets
are reproduced. Game code implements the conventional rules and stated payout
configuration.
