# Tiny Deity implementation plan

1. Add an isolated React/TypeScript/PixiJS game, with static output in `tiny-deity/` for the existing GitHub Pages site.
2. Build a seeded, 512-sample circular planet with a shared camera transform and original procedural illustration.
3. Implement fixed-step simulation: miracles, terrain and water, follower conversion and assignments, needs, construction, production, gold, goals, and levels.
4. Add responsive controls, follower/building inspectors, store, settings, save export/import, IndexedDB autosave and capped offline progress.
5. Add the main-page launcher, unit and production-browser tests, inspect desktop/mobile screenshots, and document the shipped scope and remaining features.

This release prioritizes a complete playable single-player loop. Advanced features that do not make this release will be recorded in `tiny-deity-src/PROGRESS.md`.
