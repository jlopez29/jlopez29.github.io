# Application audio

`AudioManager` is an autoload, initialized before the main scene. `audio_bus_layout.tres` routes all game buses through Games, and all category buses through Master. Volumes compose multiplicatively. Context gains live on the loop players and never change saved sliders. `user://pit_boss_audio.cfg` stores version 1 preferences independently of casino saves; changes debounce for 350 ms, Close flushes, and malformed values fall back to defaults.

`audio_catalog.gd` caches used resources once at startup. Missing resources produce empty cue lists and are skipped. Aliases share recordings; all game aliases still route to the requesting game's bus. The original slot timeline calls the narrow `slot_audio.gd` adapter, with one interruptible voice and the original 65 ms anti-overlap gate. Other games share three foreground voices, roulette has one orbit player, world and supporting activity share five voices, and UI has one interruptible voice. Music and casino atmosphere each use one looping player. Round-robin variations never read gambling RNG. Wall-clock cooldowns keep 1x/2x/4x/8x simulation audio density bounded.

`game_view.gd` emits sounds after accepted shared public/private/event actions, and result cues after the existing reveal ends. Craps uses the existing capture-roll snapshot and cushion path timing in `craps_surface.gd`. Sound callbacks never settle money. The main controller listens to actual financial and milestone signals; departures/arrivals and incidents are sampled once per real second from existing counters. Bar sounds require a completed drink transaction. Ambient slot activity requires a real settled slot event.

Atmosphere uses real guest counts once per second: busy at 14 guests, quiet at 8 or fewer, and no public crowd layer when closed. Music and ambience approach context gains over about two seconds. Back Room and active games lower the crowd layer. The public owner's distance to the real bar changes relative Jazz/crowd gains; world events use the existing floor camera rectangle and world geometry for off-screen culling and inexpensive distance attenuation.

Audio Settings is one retained themed overlay shared by public Menu action 6, Back Room Menu action 6, and game options action 9. The category body scrolls; Close and Reset stay in its footer. Opening the overlay does not rebuild or reset the game. Speaker icons indicate effective audibility while toggling only the stored game preference.

Desktop starts loops after preferences load. Web starts them only on the first pressed pointer/touch/key event, relying on Godot's browser audio activation. Focus loss pauses existing loops and drops transient voices; focus return resumes those same players. No song starts on a room/menu transition.

## Adding cues and games

1. Add only used, commercially distributable recordings under `assets/pit_boss/audio/` and update `AUDIO_CREDITS.md` with title, creator, license and exact filenames.
2. Add paths or shared aliases to `audio_catalog.gd`. Dispatch `play_game(kind, cue)` from an accepted action or a presentation boundary, never from a redraw or audio completion callback. World/UI cues use their dedicated methods.
3. A new game needs one child bus sent to Games in `audio_bus_layout.tres`, entries in AudioManager's `GAME_BUSES` and `DEFAULTS`, and a row in the shared settings section. Existing games use their lowercase canonical kind (`holdem` for Ultimate Texas Hold'em).
4. Run `godot --headless --max-fps 60 --path casino-godot --script res://tests/audio_smoke.gd` and the smallest affected presentation smoke. Headless checks validate streams/routing/state, not perceived mix or browser gesture handling. Listen in a real browser before tuning gains.
