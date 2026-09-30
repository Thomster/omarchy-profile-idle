import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Headless: keeps the idle timings in line with the active power profile
// (see apply.sh for the config and what gets written) and runs the one
// timer Omarchy doesn't have: automatic system suspend after a profile's
// "sleep" seconds of inactivity. Idle inhibitors (video playback, games,
// stay-awake) are respected, like Omarchy's own screensaver/lock.
Item {
  id: root

  property var shell: null

  readonly property string pluginDir: Quickshell.env("HOME") + "/.config/omarchy/plugins/profile-idle"
  property string profile: ""
  property int sleepSeconds: 0

  function logEvent(message) {
    console.log("profile-idle " + new Date().toISOString() + " " + message)
  }

  Process {
    id: applyProc
    command: ["bash", root.pluginDir + "/apply.sh"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parts = String(text || "").trim().split(/\s+/)
        if (parts.length < 2) return
        var nextSleep = parseInt(parts[1], 10) || 0
        if (parts[0] !== root.profile || nextSleep !== root.sleepSeconds)
          root.logEvent("profile=" + parts[0] + " sleep=" + nextSleep)
        root.profile = parts[0]
        root.sleepSeconds = nextSleep
      }
    }
  }

  // Profile switches come from the power panel, powerprofilesctl or
  // gamemode, none of which notify the shell, so poll. apply.sh is cheap
  // and only writes on change.
  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!applyProc.running) applyProc.running = true
  }

  IdleMonitor {
    id: sleepMonitor
    enabled: root.sleepSeconds > 0
    timeout: Math.max(1, root.sleepSeconds)
    respectInhibitors: true
    onIsIdleChanged: {
      if (!isIdle || !enabled) return
      root.logEvent("idle " + root.sleepSeconds + " s in " + root.profile + ", suspending")
      if (!suspendProc.running) suspendProc.running = true
    }
  }

  Process {
    id: suspendProc
    command: ["systemctl", "suspend"]
  }
}
