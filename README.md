# omarchy-profile-idle

A headless [Omarchy](https://omarchy.org/) shell service that gives each
power profile its own idle timings, and adds the one timer Omarchy
doesn't have: **automatic system sleep** (suspend) after a period of
inactivity.

Omarchy itself has a single, global screensaver/lock pair (the `idle` block
in `shell.json`; the display blanks a few seconds after the lock). This
service rewrites that pair whenever the active profile changes, and runs a
suspend timer alongside it. Idle inhibitors (video playback, games,
stay-awake) are respected, like Omarchy's own timers.

It also knows the **Game** choice of
[omarchy-session-actions-power](https://github.com/Thomster/omarchy-session-actions-power):
while that holds gamemode on, the profile is `game`.

No bar icon, no UI.

## Configuration

`~/.config/omarchy/profile-idle.json`, seconds of inactivity:

```json
{
  "power-saver": { "screensaver": 150, "lock": 300, "sleep": 0 },
  "balanced": { "screensaver": 150, "lock": 300, "sleep": 0 },
  "performance": { "screensaver": 1800, "lock": 3600, "sleep": 7200 },
  "game": "never"
}
```

- `screensaver`, `lock`: written to the `idle` block of
  `~/.config/omarchy/shell.json`, which the shell reloads live. While this
  service runs, that block is managed by it — edit this file instead.
- `sleep`: automatic `systemctl suspend`. `0` or missing = never.
- `"never"`: no screensaver, lock or sleep, via Omarchy's own stay-awake
  switch. It is switched back off when you leave that profile, unless you
  had already switched it on yourself.
- Profiles missing from the file get Omarchy's defaults (150 / 300, no
  sleep); without the file nothing changes.

Try a profile without changing anything:

```
PROFILE_IDLE_PROFILE=performance ~/.config/omarchy/plugins/profile-idle/apply.sh --dry-run
```

## Install

```
omarchy plugin add https://github.com/Thomster/omarchy-profile-idle.git --enable
```

## Requirements

- power-profiles-daemon (`powerprofilesctl`), standard on Omarchy
- Optional: omarchy-session-actions-power with gamemode, for the `game` profile

## Related

Knows the Game profile of [omarchy-session-actions-power](https://github.com/Thomster/omarchy-session-actions-power); without it the `game` profile never becomes active.

## Changelog

Current version: **1.0.1**. See [CHANGELOG.md](CHANGELOG.md).

## How this came to be

This is a personal customization for my own Omarchy setup, built with the
help of [Claude Code](https://claude.com/claude-code) (Anthropic's AI coding
agent). I'm not a professional plugin developer — please read through the
source before installing, and open an issue if something looks off.

## License

MIT
