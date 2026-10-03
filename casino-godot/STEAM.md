# Native / Steam direction

Steam integration is deferred. The current GDScript project can run in desktop
Godot without Steam or an account. Native Windows export needs Godot's matching
Windows templates; no Windows binary has been built or tested in this session.

Before a commercial release:

- Prove the core loop through playtesting, then tune progression and recovery.
- Add desktop export presets, release identifiers, installer/package validation.
- Test Windows performance, display sizes, input, audio, accessibility and saves.
- Put platform achievements/cloud save services behind an adapter so local play
  remains independent of Steam.
- Obtain Steam partner access and SDK only when needed for integration.
- Review commercial asset attribution and third-party dependency notices.
- Decide how browser and native save/version compatibility will be supported.

C# is optional for native release; it is not a prerequisite for Steam. No Steam
SDK, credentials, live service, or paid dependency is included in 0.1.
