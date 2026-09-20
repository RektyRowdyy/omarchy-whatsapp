import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import "Model.js" as Model

// Owns the unread-count watcher process, the resulting sender map, and the
// window bookkeeping around it (focus-based auto-clear, click-to-focus-or-
// launch, and the windowOpen state the bar icon dims against). Panel.qml binds to
// this declaratively and re-exposes what BarWidget.qml needs — the same
// Service split android-mirror and the shell's own plugins/panels/tailscale
// use.
//
// There is no server-side WhatsApp inbox to poll: the unread count only
// exists inside the live WhatsApp Web session (a websocket to WhatsApp's
// servers), so it can only ever be observed, not fetched fresh. This taps
// desktop notifications rather than the page's title — WhatsApp Web's
// window title here never updates past the bare hostname even when
// focused, while notifications keep arriving via the page's service worker
// regardless.
Item {
  id: root

  property var settings: ({})

  readonly property string binPath: Model.stripFileUrl(Qt.resolvedUrl("bin/whatsapp-unread"))
  readonly property string appNamePattern: stringSetting("appNamePattern", "Chromium|Google Chrome|Brave|Chrome")
  readonly property string matchUrl: stringSetting("matchUrl", "web.whatsapp.com")
  readonly property string windowClassPattern: stringSetting("windowClassPattern", "whatsapp")

  // name -> latest reported count. Keyed by sender (not appended-to) because
  // WhatsApp reissues a chat's notification with its new cumulative count
  // rather than sending a delta — summing arrivals would overcount every
  // repeat notification from the same chat.
  property var senders: ({})
  readonly property int total: Model.totalUnread(senders)
  readonly property string tooltipText: Model.tooltipFor(senders, total, windowOpen)

  // Whether a real WhatsApp Web window currently exists. Kept as a plain
  // property refreshed by refreshWindowState() rather than a binding over
  // ToplevelManager.toplevels.values — the rest of the shell (see
  // AppLibrary.qml's toplevelCount()) treats that list's change notification
  // as something you must listen for explicitly via Connections, not
  // something a property binding reliably re-evaluates on its own.
  property bool windowOpen: false

  function refreshWindowState() {
    root.windowOpen = anyWhatsAppToplevelOpen()
  }

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function boolSetting(name, fallback) {
    var value = setting(name, fallback)
    return value === true || value === "true"
  }

  function stringSetting(name, fallback) {
    var value = setting(name, fallback)
    return value === "" ? fallback : String(value)
  }

  function clear() {
    root.senders = ({})
  }

  function clearSender(name) {
    if (!Object.prototype.hasOwnProperty.call(root.senders, name)) return
    var next = Model.cloneJsonLike(root.senders)
    delete next[name]
    root.senders = next
  }

  // Finds the WhatsApp window by Wayland appId only — never by title. A
  // title-based match (what the generic omarchy-launch-or-focus-webapp
  // script does, matching class OR title against a bare word like
  // "WhatsApp") is one collision away from grabbing the wrong window: an
  // editor with this very plugin's folder open reads as a title match too
  // ("whatsapp — manifest.json"), and activate() would raise *that* instead
  // of launching or focusing the real WhatsApp Web window. appId is stable
  // and never contains incidental English words.
  function findWhatsAppToplevel() {
    var list = ToplevelManager.toplevels ? ToplevelManager.toplevels.values : []
    for (var i = 0; i < list.length; i++) {
      if (Model.isWhatsAppAppId(list[i].appId, root.windowClassPattern)) return list[i]
    }
    return null
  }

  function anyWhatsAppToplevelOpen() {
    return findWhatsAppToplevel() !== null
  }

  // Wayland toplevel activate() (same call ActiveWindow.qml uses) asks the
  // compositor directly to raise and focus the window — no hyprctl dispatch
  // involved, so it's unaffected by whatever dispatch syntax a given
  // Hyprland build expects.
  //
  // If there's no WhatsApp window, launches one — this is the only place
  // that ever does; nothing launches at shell start. Returns whether it
  // actually focused an existing window, so callers only clear the unread
  // state when a look genuinely happened (a fresh launch has nothing read).
  function focusOrLaunch() {
    var toplevel = findWhatsAppToplevel()
    if (toplevel) {
      toplevel.activate()
      return true
    }
    if (launchGuard.running) return false
    launchGuard.restart()
    Quickshell.execDetached(["omarchy-launch-webapp", "https://web.whatsapp.com/"])
    return false
  }

  // A new window takes a moment to show up as a toplevel, so without this a
  // double click (or a click on each monitor's icon — the bar renders one
  // Service per monitor) would launch two windows before the first appears.
  Timer {
    id: launchGuard
    interval: 8000
  }

  // Auto-clear when WhatsApp itself gains focus — the badge tracks
  // "unread since you last looked", so looking clears it, same as any real
  // notification-tray unread count.
  Connections {
    target: ToplevelManager
    function onActiveToplevelChanged() {
      var active = ToplevelManager.activeToplevel
      if (active && Model.isWhatsAppAppId(active.appId, root.windowClassPattern)) root.clear()
      root.refreshWindowState()
    }
  }

  Connections {
    target: ToplevelManager.toplevels
    function onValuesChanged() {
      root.refreshWindowState()
    }
  }

  // An initial read that's briefly stale (toplevels not yet enumerated) just
  // shows the icon dimmed for a moment, corrected the instant the real list
  // arrives, so it's fine to read eagerly here.
  Component.onCompleted: root.refreshWindowState()

  Process {
    id: watcherProcess
    command: [root.binPath, root.appNamePattern, root.matchUrl]
    running: true
    stdout: SplitParser {
      onRead: function(line) {
        var parsed = Model.parseWatcherLine(line)
        if (!parsed) return
        var next = Model.cloneJsonLike(root.senders)
        next[parsed.sender] = parsed.count
        root.senders = next
      }
    }
    // dbus-monitor should run for the lifetime of the shell; if it dies
    // (session bus hiccup, dbus-monitor missing) restart it after a beat
    // rather than leaving the widget silently stuck with a stale count.
    onExited: restartDelay.restart()
  }

  Timer {
    id: restartDelay
    interval: 5000
    onTriggered: if (!watcherProcess.running) watcherProcess.running = true
  }
}
