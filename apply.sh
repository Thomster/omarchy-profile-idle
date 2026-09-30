#!/bin/bash

# Applies the idle timings for the active power profile. Run periodically by
# Service.qml; idempotent, so it only writes when something differs.
#
# Profiles: power-profiles-daemon's active profile, or "game" while the
# Game choice of omarchy-session-actions-power holds gamemode on (its
# transient user unit omarchy-gamemode-hold is active).
#
# Timings come from ~/.config/omarchy/profile-idle.json, e.g.:
#   { "performance": { "screensaver": 1800, "lock": 3600, "sleep": 7200 },
#     "game": "never" }
# Seconds of inactivity. "sleep" = automatic system suspend, 0 or missing =
# never. "never" = no screensaver, lock or sleep at all. Profiles missing
# from the file use Omarchy's defaults (150 / 300, no sleep).
#
# screensaver/lock go into the "idle" block of ~/.config/omarchy/shell.json,
# which the shell reloads live. "never" uses Omarchy's own stay-awake switch
# instead, and turns it back off on leaving -- unless it was already on
# before, i.e. switched on by you.
#
# Prints "<profile> <sleep seconds>" for Service.qml, where the sleep timer
# runs. Sleep is 0 whenever stay-awake is on.
#
# Usage: apply.sh [--dry-run]
#   PROFILE_IDLE_PROFILE=performance apply.sh --dry-run   # try a profile

set -uo pipefail

dry_run=0
[[ ${1:-} == "--dry-run" ]] && dry_run=1

config="$HOME/.config/omarchy/profile-idle.json"
shell_json="$HOME/.config/omarchy/shell.json"
stay_awake_file="$HOME/.local/state/omarchy/indicators/stay-awake"
state_dir="${XDG_RUNTIME_DIR:-/tmp}/omarchy/profile-idle"
ours_file="$state_dir/stay-awake-ours"

default_screensaver=150
default_lock=300

run() {
  if (( dry_run )); then
    echo "would run: $*" >&2
  else
    "$@"
  fi
}

# PROFILE_IDLE_PROFILE overrides the detection, for testing with --dry-run.
if [[ -n ${PROFILE_IDLE_PROFILE:-} ]]; then
  profile=$PROFILE_IDLE_PROFILE
elif systemctl --user is-active --quiet omarchy-gamemode-hold 2>/dev/null; then
  profile=game
else
  profile=$(powerprofilesctl get 2>/dev/null || echo balanced)
fi

entry='null'
[[ -f $config ]] && entry=$(jq -c --arg p "$profile" '.[$p] // null' "$config" 2>/dev/null || echo null)
[[ $entry == null ]] && entry='{}'

if [[ $entry == '"never"' ]]; then
  if [[ ! -f $stay_awake_file ]]; then
    run omarchy-shell idle disable >/dev/null
    (( dry_run )) || { mkdir -p "$state_dir"; touch "$ours_file"; }
  fi
  echo "$profile 0"
  exit 0
fi

# Leaving "never": undo only a stay-awake this script switched on.
if [[ -f $ours_file ]]; then
  run omarchy-shell idle enable >/dev/null
  (( dry_run )) || rm -f "$ours_file"
fi

read -r screensaver lock sleep < <(jq -r \
  --argjson ds "$default_screensaver" --argjson dl "$default_lock" '
  def secs($v; $d): if ($v | type) == "number" and $v >= 0 then ($v | floor) else $d end;
  "\(secs(.screensaver; $ds)) \(secs(.lock; $dl)) \(secs(.sleep; 0))"
' <<<"$entry")

if [[ -f $shell_json ]]; then
  current=$(jq -r '"\(.idle.screensaver // "") \(.idle.lock // "")"' "$shell_json" 2>/dev/null)
  if [[ $current != "$screensaver $lock" ]]; then
    if (( dry_run )); then
      echo "would set shell.json idle: screensaver $screensaver, lock $lock (now: $current)" >&2
    else
      tmp=$(mktemp "$shell_json.XXXXXX") &&
        jq --argjson s "$screensaver" --argjson l "$lock" '.idle.screensaver = $s | .idle.lock = $l' "$shell_json" >"$tmp" &&
        mv "$tmp" "$shell_json" || rm -f "$tmp"
    fi
  fi
fi

[[ -f $stay_awake_file ]] && sleep=0
echo "$profile $sleep"
